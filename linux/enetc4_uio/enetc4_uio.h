/* SPDX-License-Identifier: (GPL-2.0+ OR BSD-3-Clause) */
/* Copyright 2025 NXP */
#ifndef _ENETC4_UIO_H_
#define _ENETC4_UIO_H_

#include <linux/timer.h>
#include <linux/pci.h>
#include <linux/netdevice.h>
#include <linux/etherdevice.h>
#include <linux/dma-mapping.h>
#include <linux/skbuff.h>
#include <linux/ethtool.h>
#include <linux/if_vlan.h>
#include <linux/phylink.h>
#include <linux/fsl/netc_lib.h>
#include <linux/dim.h>
#include <net/xdp.h>
#include <net/tsn.h>
#include <linux/crc-itu-t.h>
#include <linux/bitops.h>
#include <net/devlink.h>
#include <linux/phylink.h>
#include <linux/ethtool_netlink.h>

/* This means the ENETC PF is owned by M core, but its VFs are
 * owned by A core.
 */
#define ENETC_PF_VIRTUAL_DEVID  0x080b

#define ENETC_BAR_REGS       0

#define ENETC_MAX_SKB_FRAGS     13
#define ENETC4_MAX_SKB_FRAGS    61

#define ENETC_MAX_VF_NUM        15
#define ENETC_MAX_SI_NUM        (ENETC_MAX_VF_NUM + 1)

#define ENETC_MAX_NUM_VFS       8
#define ENETC_SIPMAR0   0x80
#define ENETC_SIPMAR1   0x84

#define  PSIMSGSR_MS(n)         BIT((n) + 1) /* m = VF index */

#define ENETC_SICAPR0   0x900
#define ENETC_SICAPR1   0x904

#define ENETC_PSIIER    0xa00
#define  PSIIER_MR(n)   BIT((n) + 1) /* n = VSI index */

#define ENETC_PSIMSGSR          0x208

#define  PSIMSGSR_MS(n)         BIT((n) + 1) /* m = VF index */
#define  PSIMSGSR_SET_MC(val)   ((val) << 16)

#define ENETC_G_EIPBRR0         0x0bf8
#define  EIPBRR0_REVISION       GENMASK(15, 0)

#define ENETC_PORT_BASE         0x10000
#define ENETC_GLOBAL_BASE       0x20000

/* PCI device info */
struct enetc_hw {
	/* SI registers, used by all PCI functions */
	void __iomem *reg;
	/* Port registers, PF only */
	void __iomem *port;
	/* IP global registers, PF only */
	void __iomem *global;
};
/* ENETC register accessors */

/* MDIO issue workaround (on LS1028A) -
 * Due to a hardware issue, an access to MDIO registers
 * that is concurrent with other ENETC register accesses
 * may lead to the MDIO access being dropped or corrupted.
 * To protect the MDIO accesses a readers-writers locking
 * scheme is used, where the MDIO register accesses are
 * protected by write locks to insure exclusivity, while
 * the remaining ENETC registers are accessed under read
 * locks since they only compete with MDIO accesses.
 */
extern rwlock_t enetc_mdio_lock;
DECLARE_STATIC_KEY_FALSE(enetc_has_err050089);
/* use this locking primitive only on the fast datapath to
 * group together multiple non-MDIO register accesses to
 * minimize the overhead of the lock
 */
static inline void enetc_lock_mdio(void)
{
	if (static_branch_unlikely(&enetc_has_err050089))
		read_lock(&enetc_mdio_lock);
}

static inline void enetc_unlock_mdio(void)
{
	if (static_branch_unlikely(&enetc_has_err050089))
		read_unlock(&enetc_mdio_lock);
}

/* internal helpers for the MDIO w/a */
static inline u32 _enetc_rd_reg_wa(void __iomem *reg)
{
	u32 val;

	enetc_lock_mdio();
	val = ioread32(reg);
	enetc_unlock_mdio();

	return val;
}

static inline void _enetc_wr_reg_wa(void __iomem *reg, u32 val)
{
	enetc_lock_mdio();
	iowrite32(val, reg);
	enetc_unlock_mdio();
}
/* general register accessors*/
#define enetc_rd_reg(reg)               _enetc_rd_reg_wa((reg))
#define enetc_wr_reg(reg, val)          _enetc_wr_reg_wa((reg), (val))
#define enetc_rd(hw, off)               enetc_rd_reg((hw)->reg + (off))
#define enetc_wr(hw, off, val)          enetc_wr_reg((hw)->reg + (off), val)
#define enetc_rd64(hw, off)             _enetc_rd_reg64_wa((hw)->reg + (off))
/* port register accessors - PF only */
#define enetc_port_rd(hw, off)          enetc_rd_reg((hw)->port + (off))
#define enetc_port_rd64(hw, off)        _enetc_rd_reg64_wa((hw)->port + (off))
#define enetc_port_wr(hw, off, val)     enetc_wr_reg((hw)->port + (off), val)
/* global register accessors - PF only */
#define enetc_global_rd(hw, off)        enetc_rd_reg((hw)->global + (off))
#define enetc_global_wr(hw, off, val)   enetc_wr_reg((hw)->global + (off), val)

/* Port configuration register */
#define ENETC4_PCR              0x4010
#define  PCR_PSPEED             GENMASK(29, 16)
#define  PCR_PSPEED_VAL(speed)  (((speed) / 10 - 1) << 16)

/* Port operational register */
#define ENETC4_POR              0x4100
#define  POR_TXDIS              BIT(0)
#define  POR_RXDIS              BIT(1)

/* Port status register */
#define ENETC4_PM_CMD_CFG(mac)          (0x5008 + (mac) * 0x400)
#define  PM_CMD_CFG_TX_EN               BIT(0)
#define  PM_CMD_CFG_RX_EN               BIT(1)

#define ENETC4_PM_LPWAKE_TIMER(mac)     (0x50B8 + (mac) * 0x400)
#define ENETC4_PM_SLEEP_TIMER(mac)      (0x50BC + (mac) * 0x400)
#define  PM_EEE_TIMER                   GENMASK(23, 0)

/* Port MAC 0 Interface Mode Control Register */
#define ENETC4_PM_IF_MODE(mac)          (0x5300 + (mac) * 0x400)
#define  PM_IF_MODE_IFMODE              GENMASK(2, 0)
#define   IFMODE_XGMII                  0
#define   IFMODE_RMII                   3
#define   IFMODE_RGMII                  4
#define   IFMODE_SGMII                  5
#define  PM_IF_MODE_REVMII              BIT(3)
#define  PM_IF_MODE_M10                 BIT(4)
#define  PM_IF_MODE_HD                  BIT(6)
#define  PM_IF_MODE_SSP                 GENMASK(14, 13)
#define   SSP_100M                      0
#define   SSP_10M                       1
#define   SSP_1G                        2
#define  PM_IF_MODE_ENA                 BIT(15)

#define ENETC_EMDIO_BASE        0x1c00

/* Port external MDIO Base address, use to access off-chip PHY */
#define ENETC4_EMDIO_BASE               0x5c00

#define ENETC_PM_IMDIO_BASE     0x8030

/* Port internal MDIO base address, use to access PCS */
#define ENETC4_PM_IMDIO_BASE            0x5030

/* Common Class ID for PSI-TO-VSI and VSI-TO-PSI messages */
#define ENETC_MSG_CLASS_ID_LINK_STATUS          0x80

/* Class-specific notification codes for link status */
#define ENETC_PF_NC_LINK_STATUS_UP                      0x0
#define ENETC_PF_NC_LINK_STATUS_DOWN                    0x1

/* The format of PSI-TO-VSI message, only a 16-bits code */
union enetc_pf_msg {
	struct {
		union {
			struct {
				u8 cookie:4;
				u8 class_code:4;
			};
			/* some messages class_code is 8-bit without cookie */
			u8 class_code_u8;
		};
		u8 class_id;
	};
	u16 code;
};

#define ENETC_MAC_MAXFRM_SIZE	9600
#define ENETC_MAX_MTU		(ENETC_MAC_MAXFRM_SIZE - \
		(ETH_FCS_LEN + ETH_HLEN + VLAN_HLEN))
#define ENETC_REV4     0x4
#define ENETC_REV1      0x1
#define  ENETC_REV_4_1              0x0401

enum enetc_errata {
	ENETC_ERR_VLAN_ISOL     = BIT(0),
	ENETC_ERR_UCMCSWP       = BIT(1),
};

#define ENETC_SI_F_QBU  BIT(2)
#define ENETC_SI_F_PPM	BIT(5) /* Pseduo MAC */

enum enetc_active_offloads {
	/* 8 bits reserved for TX timestamp types (hwtstamp_tx_types) */
	ENETC_F_TX_TSTAMP               = BIT(0),
	ENETC_F_TX_ONESTEP_SYNC_TSTAMP  = BIT(1),

	ENETC_F_RX_TSTAMP               = BIT(8),
	ENETC_F_QBV                     = BIT(9),
	ENETC_F_QCI                     = BIT(10),
	ENETC_F_QBU                     = BIT(11),

	ENETC_F_CHECKSUM                = BIT(12),
	ENETC_F_LSO                     = BIT(13),
	ENETC_F_RSC                     = BIT(14),
};

/* PCI IEP device data */
struct enetc_si {
	struct pci_dev *pdev;
	struct enetc_hw hw;
	enum enetc_errata errata;
	u16 revision;

	struct net_device *ndev; /* back ref. */

	unsigned short pad;
	int hw_features;
	int pmac_offset; /* Only valid for PSI that supports 802.1Qbu */
	u64 clk_freq;

	struct workqueue_struct *workqueue;
	struct mutex msg_lock; /* mailbox message lock */
};

#define ENETC_SI_ALIGN	32

static inline bool is_enetc_rev1(struct enetc_si *si)
{
	return si->pdev->revision == ENETC_REV1;
}

static inline void *enetc_si_priv(const struct enetc_si *si)
{
	return (char *)si + ALIGN(sizeof(struct enetc_si), ENETC_SI_ALIGN);
}

#define ENETC_MAX_NUM_TXQS	8
#define ENETC_MAX_BDR_INT       6 /* fixed to max # of available cpus */

struct enetc_ndev_priv {
	struct net_device *ndev;
	struct device *dev; /* dma-mapping device */
	struct enetc_si *si;
	struct clk *ref_clk; /* RGMII/RMII reference clock */
	struct pci_dev *rcec;

	enum enetc_active_offloads active_offloads;

	u32 speed; /* store speed for compare update pspeed */

	struct ethtool_keee eee;

	struct phylink *phylink;
	unsigned long flags;

	/* Serialize access to MAC Merge state between ethtool requests
	 * and link state updates
	 */
	struct mutex mm_lock;
};

/* SI common */
u32 enetc_port_mac_rd(struct enetc_si *si, u32 reg);
void enetc_port_mac_wr(struct enetc_si *si, u32 reg, u32 val);
int enetc_pci_probe(struct pci_dev *pdev, const char *name, int sizeof_priv);
void enetc_pci_remove(struct pci_dev *pdev);

/* ethtool */
void enetc_mm_link_state_update(struct enetc_ndev_priv *priv, bool link);
void enetc_eee_mode_set(struct net_device *dev, bool enable);

struct enetc_pf;

enum enetc_vf_flags {
	ENETC_VF_FLAG_PF_SET_MAC        = BIT(0),
	ENETC_VF_FLAG_TRUSTED           = BIT(1)
};

struct enetc_vf_state {
	enum enetc_vf_flags flags;
};

struct enetc_pf {
	struct enetc_si *si;
	int num_vfs; /* number of active VFs, after sriov_init */
	int total_vfs; /* max number of VFs, set for PF at probe */
	struct enetc_vf_state *vf_state;

	bool vf_link_status_notify[ENETC_MAX_NUM_VFS];

	struct mii_bus *mdio; /* saved for cleanup */
	struct mii_bus *imdio;
	struct phylink_pcs *pcs;

	phy_interface_t if_mode;
	struct phylink_config phylink_config;
};

#define phylink_to_enetc_pf(config) \
	container_of((config), struct enetc_pf, phylink_config)

int enetc_mdiobus_create(struct enetc_pf *pf, struct device_node *node);
void enetc_mdiobus_destroy(struct enetc_pf *pf);
void enetc_phylink_destroy(struct enetc_ndev_priv *priv);
int enetc_phylink_create(struct enetc_ndev_priv *priv,
		struct device_node *node,
		const struct phylink_mac_ops *pl_mac_ops);

void enetc_pf_netdev_setup(struct enetc_si *si, struct net_device *ndev,
		const struct net_device_ops *ndev_ops);
int enetc_pf_send_msg(struct enetc_pf *pf, u32 msg_code, u16 ms_mask);
void enetc_get_ip_revision(struct enetc_si *si);

static inline bool enetc_pf_is_owned_by_mcore(struct pci_dev *pdev)
{
	if (pdev->vendor == PCI_VENDOR_ID_NXP2 &&
			pdev->device == ENETC_PF_VIRTUAL_DEVID)
		return true;

	return false;
}
#endif
