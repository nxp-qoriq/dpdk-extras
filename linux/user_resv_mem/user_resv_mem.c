/* SPDX-License-Identifier: GPL-2.0
 *
 *   Copyright 2025 NXP
 *
 */

#include <linux/module.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/of_platform.h>
#include <linux/of.h>
#include <linux/of_address.h>
#include <linux/of_reserved_mem.h>
#include <linux/mod_devicetable.h>
#include <linux/io.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/string.h>
#include <linux/slab.h>
#include <linux/uaccess.h>
#include <linux/mm.h>
#include <linux/sched/mm.h>
#include <linux/bitmap.h>
#include <linux/mutex.h>
#include <asm/pgtable.h>
#include <linux/list.h>

/* ioctls */
enum nxp_mem_cp {
	NXP_CP_DEFAULT = 0,
	NXP_CP_WC,
	NXP_CP_WB,
	NXP_CP_WT
};

#define IOCTL_ALLOC_CHUNKS _IOWR('N', 1, struct nxp_usmem_reserve)
#define IOCTL_GET_MEM_INFO _IOR('N', 2, struct nxp_usmem_info)
#define IOCTL_RELEASE_CHUNKS _IOWR('N', 3, struct nxp_usmem_reserve)

struct nxp_usmem_reserve {
	int chunks;
	unsigned long offset;
	enum nxp_mem_cp mem_cp;
};

struct nxp_usmem_info {
	unsigned long phys_base;
	unsigned long chunk_size;
	unsigned long total_size;
	unsigned long free_chunks;
};
/* ioctls end */

static char *cache_policy = "wc";
enum nxp_mem_cp df_mem_cp;
static unsigned long chunk_size;

static DEFINE_MUTEX(mem_lock);

struct nxp_usmem_alloc_info {
	unsigned long offset;
	int chunks;
	enum nxp_mem_cp mem_cp;
	struct list_head node;
};

struct nxp_us_mem {
	struct cdev cdev;
	struct class *cls;
	dev_t devt;
	void __iomem *mem_virt_base;
	phys_addr_t mem_phys_base;
	size_t mem_size;
	char name[64];
	struct device *dev;
	unsigned long *chunk_bitmap;
	int total_chunks;
};

struct nxp_usmem_priv {
	struct nxp_us_mem *usmem;
	struct list_head alloc_usmem_list;
};

static long nxp_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
	struct nxp_usmem_priv *priv = file->private_data;
	struct nxp_us_mem *udev = priv->usmem;

	if (cmd == IOCTL_ALLOC_CHUNKS) {
		struct nxp_usmem_reserve req;
		struct nxp_usmem_alloc_info *alloc_info;

		if (copy_from_user(&req, (void __user *)arg, sizeof(req)))
			return -EFAULT;

		mutex_lock(&mem_lock);
		int start = bitmap_find_next_zero_area(udev->chunk_bitmap, udev->total_chunks, 0,
				req.chunks, 0);
		if (start >= udev->total_chunks) {
			mutex_unlock(&mem_lock);
			return -ENOMEM;
		}

		alloc_info = kzalloc(sizeof(*alloc_info), GFP_KERNEL);
		if (!alloc_info) {
			mutex_unlock(&mem_lock);
			return -ENOMEM;
		}

		alloc_info->offset = start * chunk_size;
		alloc_info->chunks = req.chunks;
		alloc_info->mem_cp = req.mem_cp;
		list_add_tail(&alloc_info->node, &priv->alloc_usmem_list);
		bitmap_set(udev->chunk_bitmap, start, req.chunks);

		mutex_unlock(&mem_lock);

		req.offset = start * chunk_size;
		if (copy_to_user((void __user *)arg, &req, sizeof(req))) {
			bitmap_clear(udev->chunk_bitmap, start, req.chunks);
			list_del(&alloc_info->node);
			kfree(alloc_info);
			return -EFAULT;
		}
		return 0;
	} else if (cmd == IOCTL_GET_MEM_INFO) {
		mutex_lock(&mem_lock);
		int allocated = bitmap_weight(udev->chunk_bitmap, udev->total_chunks);
		mutex_unlock(&mem_lock);
		struct nxp_usmem_info info = {
			.phys_base = (unsigned long)udev->mem_phys_base,
			.chunk_size = (unsigned long)chunk_size,
			.total_size = (unsigned long)udev->mem_size,
			.free_chunks = (unsigned long)udev->total_chunks - allocated
		};
		if (copy_to_user((void __user *)arg, &info, sizeof(info)))
			return -EFAULT;
		return 0;
	} else if (cmd == IOCTL_RELEASE_CHUNKS) {
		struct nxp_usmem_reserve req;
		struct nxp_usmem_alloc_info *info, *tmp;

		if (copy_from_user(&req, (void __user *)arg, sizeof(req)))
			return -EFAULT;

		int start = req.offset / chunk_size;
		if (start + req.chunks > udev->total_chunks)
			return -EINVAL;

		mutex_lock(&mem_lock);
		/* lets check if entry is present */
		list_for_each_entry_safe(info, tmp, &priv->alloc_usmem_list, node) {
			if (req.offset != info->offset)
				continue;
			int start = info->offset / chunk_size;
			if (req.chunks != info->chunks)
				pr_debug("free all chunks for this allocation.\n");
			bitmap_clear(udev->chunk_bitmap, start, info->chunks);
			list_del(&info->node);
			kfree(info);
			break;
		}
		mutex_unlock(&mem_lock);
		return 0;
	}

	return -EINVAL;
}

static int nxp_open(struct inode *inode, struct file *file)
{
	struct nxp_usmem_priv *priv;

	priv = kzalloc(sizeof(*priv), GFP_KERNEL);
	if (!priv)
		return -ENOMEM;

	priv->usmem = container_of(inode->i_cdev, struct nxp_us_mem, cdev);

	INIT_LIST_HEAD(&priv->alloc_usmem_list);
	file->private_data = priv;

	return 0;
}

static int nxp_mmap(struct file *file, struct vm_area_struct *vma)
{
	struct nxp_usmem_priv *priv = file->private_data;
	struct nxp_us_mem *dev = priv->usmem;
	unsigned long offset = vma->vm_pgoff << PAGE_SHIFT;
	unsigned long physical = dev->mem_phys_base + offset;
	unsigned long size = vma->vm_end - vma->vm_start;
	struct nxp_usmem_alloc_info *info, *tmp;
	enum nxp_mem_cp mem_cp = NXP_CP_DEFAULT;
	int found = 0;

	if (offset >= dev->mem_size || (offset + size) > dev->mem_size)
		return -EINVAL;

	mutex_lock(&mem_lock);
	/* lets check if entry is present */
	list_for_each_entry_safe(info, tmp, &priv->alloc_usmem_list, node) {
		if (offset >= info->offset &&
				offset < (info->offset + (info->chunks * chunk_size))) {
			if (size <= (info->offset + (info->chunks * chunk_size)) - offset) {
				mem_cp = info->mem_cp;
				found = 1;
				break;
			}
		}
	}
	mutex_unlock(&mem_lock);

	if (found == 0) {
		pr_err("Wrong mmap offset 0x%lx or size 0x%lx\n", offset, size);
		return -EINVAL;
	}

	if (mem_cp < NXP_CP_DEFAULT || mem_cp > NXP_CP_WT)
		mem_cp = NXP_CP_DEFAULT;

	if (mem_cp == NXP_CP_DEFAULT)
		mem_cp = df_mem_cp;

	switch (mem_cp) {
	case NXP_CP_WB:
		vma->vm_page_prot = pgprot_cached(vma->vm_page_prot);
		break;
	case NXP_CP_WT:
		vma->vm_page_prot = pgprot_writethrough(vma->vm_page_prot);
		break;
	case NXP_CP_WC:
	default:
		vma->vm_page_prot = pgprot_writecombine(vma->vm_page_prot);
	};

	pr_info("offset %lx Memory map in mode %d (1:WC, 2:WB, 3:WT, 0:%s)\n",
			offset, mem_cp, cache_policy);
	return io_remap_pfn_range(vma, vma->vm_start, physical >> PAGE_SHIFT, size,
			vma->vm_page_prot);
}

static int nxp_release(struct inode *inode, struct file *file)
{
	struct nxp_usmem_priv *priv = file->private_data;
	struct nxp_us_mem *dev = priv->usmem;
	struct nxp_usmem_alloc_info *info, *tmp;

	if (!dev)
		return 0;

	mutex_lock(&mem_lock);
	list_for_each_entry_safe(info, tmp, &priv->alloc_usmem_list, node) {
		int start = info->offset / chunk_size;
		bitmap_clear(dev->chunk_bitmap, start, info->chunks);
		list_del(&info->node);
		kfree(info);
	}
	mutex_unlock(&mem_lock);

	return 0;
}

static const struct file_operations nxp_fops = {
	.owner = THIS_MODULE,
	.open = nxp_open,
	.release = nxp_release,
	.unlocked_ioctl = nxp_ioctl,
	.mmap = nxp_mmap,
};


/* Sysfs show function */
static ssize_t phyaddr_show(struct device *dev,
			    struct device_attribute *attr, char *buf)
{
	struct nxp_us_mem *udev = dev_get_drvdata(dev);
	return sprintf(buf, "0x%llx\n", (unsigned long long)udev->mem_phys_base);
}
static DEVICE_ATTR_RO(phyaddr);

static ssize_t size_show(struct device *dev,
			 struct device_attribute *attr, char *buf)
{
	struct nxp_us_mem *udev = dev_get_drvdata(dev);
	return sprintf(buf, "0x%llx\n", (unsigned long long)udev->mem_size);
}
static DEVICE_ATTR_RO(size);

static int nxp_usmem_probe(struct platform_device *pdev)
{
	struct resource *r;
	struct nxp_us_mem *dev;
	const char *dev_name;
	int rc;

	dev = devm_kzalloc(&pdev->dev, sizeof(*dev), GFP_KERNEL);
	if (!dev)
		return -ENOMEM;

	rc = of_property_read_string(pdev->dev.of_node, "device-name", &dev_name);
	if (rc)
		dev_name = "nxp_usmem";

	strscpy(dev->name, dev_name, sizeof(dev->name));
	r = platform_get_resource(pdev, IORESOURCE_MEM, 0);
	if (!r)
		return -ENODEV;

	dev->mem_phys_base = r->start;
	dev->mem_size = resource_size(r);

	if (chunk_size == 0 || chunk_size > dev->mem_size)
		chunk_size = dev->mem_size;

	/* check for cache_policy */
	if (strcmp(cache_policy, "wc") == 0) {
		df_mem_cp = NXP_CP_WC;
	} else if (strcmp(cache_policy, "wb") == 0) {
		df_mem_cp = NXP_CP_WB;
	} else if (strcmp(cache_policy, "wt") == 0) {
		df_mem_cp = NXP_CP_WT;
	} else {
		pr_warn("Unknown default cache_policy = %s, Changing to WC\n",
			cache_policy);
		df_mem_cp = NXP_CP_WC;
	}
	dev->total_chunks = dev->mem_size / chunk_size;

	dev->chunk_bitmap = bitmap_zalloc(dev->total_chunks, GFP_KERNEL);
	if (!dev->chunk_bitmap)
		return -ENOMEM;

	rc = alloc_chrdev_region(&dev->devt, 0, 1, dev->name);
	if (rc)
		goto err_bitmap;

	dev->cls = class_create(dev->name);
	if (IS_ERR(dev->cls)) {
		rc = PTR_ERR(dev->cls);
		goto err_chrdev;
	}

	cdev_init(&dev->cdev, &nxp_fops);
	rc = cdev_add(&dev->cdev, dev->devt, 1);
	if (rc)
		goto err_class;

	dev->dev = device_create(dev->cls, NULL, dev->devt, dev, dev->name);
	if (IS_ERR(dev->dev)) {
		rc = PTR_ERR(dev->dev);
		goto err_cdev;
	}

	platform_set_drvdata(pdev, dev);


	/* Create sysfs attribute */
	rc = device_create_file(dev->dev, &dev_attr_phyaddr);
	if (rc)
		dev_warn(dev->dev, "Failed to create sysfs attribute phyaddr\n");

	rc = device_create_file(dev->dev, &dev_attr_size);
	if (rc)
		dev_warn(dev->dev, "Failed to create sysfs attribute size\n");

	pr_info("Created /dev/%s for reserved memory at 0x%llx, total chunks = %d,"
		" chunk size = 0x%lx, total mem_size = 0x%lx\n",
		dev->name, (u64)dev->mem_phys_base, dev->total_chunks, chunk_size, dev->mem_size);
	return 0;


err_cdev:
	cdev_del(&dev->cdev);
err_class:
	class_destroy(dev->cls);
err_chrdev:
	unregister_chrdev_region(dev->devt, 1);
err_bitmap:
	bitmap_free(dev->chunk_bitmap);

	return rc;
}

static void nxp_usmem_remove(struct platform_device *pdev)
{
	struct nxp_us_mem *dev = platform_get_drvdata(pdev);

	device_destroy(dev->cls, dev->devt);
	cdev_del(&dev->cdev);
	class_destroy(dev->cls);
	unregister_chrdev_region(dev->devt, 1);
	bitmap_free(dev->chunk_bitmap);

	pr_info("Removed /dev/%s\n", dev->name);
}

static const struct of_device_id nxp_usmem_of_match[] = {
	{ .compatible = "nxp,us-devmem" },
	{}
};
MODULE_DEVICE_TABLE(of, nxp_usmem_of_match);

static struct platform_driver nxp_usmem_driver = {
	.probe = nxp_usmem_probe,
	.remove = nxp_usmem_remove,
	.driver = {
		.name = "nxp_user_resv_mem",
		.of_match_table = nxp_usmem_of_match,
	},
};
module_platform_driver(nxp_usmem_driver);
module_param(cache_policy, charp, 0444);
module_param(chunk_size, ulong, 0444);
MODULE_PARM_DESC(cache_policy, "Cache policy: wc, wb, wt");
MODULE_PARM_DESC(chunk_size, "Chunk size in bytes (default is total reserve memory)");
MODULE_DESCRIPTION("Reserve memory allocator for user-space drivers");
MODULE_LICENSE("GPL");
MODULE_AUTHOR("NXP");
