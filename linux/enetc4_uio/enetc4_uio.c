// SPDX-License-Identifier: (GPL-2.0+ OR BSD-3-Clause)
/* Copyright 2025 NXP */
#include <linux/module.h>
#include <linux/of_mdio.h>
#include <linux/of_net.h>
#include <linux/of_platform.h>
#include <linux/clk.h>
#include <linux/fsl/enetc_mdio.h>
#include <linux/pinctrl/consumer.h>
#include <linux/regulator/consumer.h>
#include <linux/unaligned.h>
#include <linux/fsl/netc_global.h>
#include <linux/uio_driver.h>
#include <linux/gpio.h>
#include <linux/of_gpio.h>
#include "enetc4_uio.h"
#include <linux/pci.h>
#include <linux/module.h>
#include <linux/phy/phy.h>
#include <linux/pcs/pcs-xpcs.h>
#include <linux/pcs-lynx.h>

#define DRIVER_NAME "enetc4_uio"
#define DRIVER_VERSION "1.0"

struct enetc4_uio_priv {
	struct pci_dev *pdev;
	struct uio_info uio;
	struct regulator *reg_phy;
	int phy_reset_gpio;
};

u32 enetc_port_mac_rd(struct enetc_si *si, u32 reg)
{
        if (si->hw_features & ENETC_SI_F_PPM)
                return 0;

        return enetc_port_rd(&si->hw, reg);
}

void enetc_port_mac_wr(struct enetc_si *si, u32 reg, u32 val)
{
        if (si->hw_features & ENETC_SI_F_PPM)
                return;

        enetc_port_wr(&si->hw, reg, val);
        if (si->hw_features & ENETC_SI_F_QBU)
                enetc_port_wr(&si->hw, reg + si->pmac_offset, val);
}

int enetc_pf_send_msg(struct enetc_pf *pf, u32 msg_code, u16 ms_mask)
{
        struct enetc_si *si = pf->si;
        u32 psimsgsr;
        int err;

        psimsgsr = PSIMSGSR_SET_MC(msg_code);
        psimsgsr |= ms_mask;

        guard(mutex)(&si->msg_lock);
        enetc_wr(&si->hw, ENETC_PSIMSGSR, psimsgsr);
        err = read_poll_timeout(enetc_rd, psimsgsr,
                                !(psimsgsr & ms_mask),
                                100, 100000, false, &si->hw, ENETC_PSIMSGSR);

        return err;
}

static inline u32 enetc_cycles_to_usecs(u32 cycles, u64 clk_freq)
{
        return (u32)div_u64(cycles * 1000000ULL, clk_freq);
}

static inline u32 enetc_usecs_to_cycles(u32 usecs, u64 clk_freq)
{
        return (u32)div_u64(usecs * clk_freq, 1000000ULL);
}

static int enetc_us_to_tx_cycle(struct net_device *dev, u32 *us)
{
        struct enetc_ndev_priv *priv = netdev_priv(dev);
        u32 cycle, max_us;

        max_us = enetc_cycles_to_usecs(PM_EEE_TIMER, priv->si->clk_freq);
        if (*us > max_us) {
                netdev_info(dev, "ENETC supports maximum tx_lpi_timer: %uus, using %uus instead.\n",
                            max_us, max_us);
                *us = max_us;
        }
        cycle = enetc_usecs_to_cycles(*us, priv->si->clk_freq);

        return cycle;
}

void enetc_eee_mode_set(struct net_device *dev, bool enable)
{
        struct enetc_ndev_priv *priv = netdev_priv(dev);
        unsigned int sleep_cycle = 0, wake_cycle = 0;
        struct ethtool_keee *eee = &priv->eee;
        struct enetc_si *si = priv->si;

        if (eee->eee_active) {
                if (enable) {
                        sleep_cycle = enetc_us_to_tx_cycle(dev, &eee->tx_lpi_timer);
                        wake_cycle = sleep_cycle;
                } else {
                        eee->tx_lpi_timer = 0;
                }
                eee->eee_enabled = enable;
        }
        eee->tx_lpi_enabled = eee->eee_active;

        enetc_port_mac_wr(si, ENETC4_PM_SLEEP_TIMER(0), sleep_cycle);
        enetc_port_mac_wr(si, ENETC4_PM_LPWAKE_TIMER(0), wake_cycle);
}

void enetc_get_ip_revision(struct enetc_si *si)
{
        struct enetc_hw *hw = &si->hw;
        u32 val;

        val = enetc_global_rd(hw, ENETC_G_EIPBRR0);
        si->revision = val & EIPBRR0_REVISION;
}

static inline bool is_enetc_rev4(struct enetc_si *si)
{
        return si->pdev->revision == ENETC_REV4;
}

static int enetc_mdio_probe(struct enetc_pf *pf, struct device_node *np)
{
        struct device *dev = &pf->si->pdev->dev;
        struct enetc_mdio_priv *mdio_priv;
        struct mii_bus *bus;
        int err;

        bus = devm_mdiobus_alloc_size(dev, sizeof(*mdio_priv));
        if (!bus)
                return -ENOMEM;

        bus->name = "Freescale ENETC MDIO Bus";
        bus->read = enetc_mdio_read_c22;
        bus->write = enetc_mdio_write_c22;
        bus->read_c45 = enetc_mdio_read_c45;
        bus->write_c45 = enetc_mdio_write_c45;
        bus->parent = dev;
        mdio_priv = bus->priv;
        mdio_priv->hw = &pf->si->hw;
        if (is_enetc_rev4(pf->si))
                mdio_priv->mdio_base = ENETC4_EMDIO_BASE;
        else
                mdio_priv->mdio_base = ENETC_EMDIO_BASE;
        snprintf(bus->id, MII_BUS_ID_SIZE, "%s", dev_name(dev));

        err = of_mdiobus_register(bus, np);
        if (err)
                return dev_err_probe(dev, err, "cannot register MDIO bus\n");

        pf->mdio = bus;

        return 0;
}

static void enetc_mdio_remove(struct enetc_pf *pf)
{
        if (pf->mdio)
                mdiobus_unregister(pf->mdio);
}

static int enetc_imdio_create(struct enetc_pf *pf)
{
        struct device *dev = &pf->si->pdev->dev;
        struct enetc_mdio_priv *mdio_priv;
        struct phylink_pcs *phylink_pcs;
        struct mii_bus *bus;
        struct phy *serdes;
        int err, xpcs_ver;
        size_t num_phys;

        serdes = devm_of_phy_optional_get(dev, dev->of_node, NULL);
        if (IS_ERR(serdes))
                return PTR_ERR(serdes);

        num_phys = serdes ? 1 : 0;

        bus = mdiobus_alloc_size(sizeof(*mdio_priv));
        if (!bus)
                return -ENOMEM;

        bus->name = "Freescale ENETC internal MDIO Bus";
        bus->read = enetc_mdio_read_c22;
        bus->write = enetc_mdio_write_c22;
        bus->read_c45 = enetc_mdio_read_c45;
        bus->write_c45 = enetc_mdio_write_c45;
        bus->parent = dev;
        bus->phy_mask = ~0;
        mdio_priv = bus->priv;
        mdio_priv->hw = &pf->si->hw;
        if (is_enetc_rev4(pf->si))
                mdio_priv->mdio_base = ENETC4_PM_IMDIO_BASE;
        else
                mdio_priv->mdio_base = ENETC_PM_IMDIO_BASE;
        snprintf(bus->id, MII_BUS_ID_SIZE, "%s-imdio", dev_name(dev));

        mdio_priv->regulator = devm_regulator_get_optional(dev, "serdes");
        if (IS_ERR(mdio_priv->regulator)) {
                err = PTR_ERR(mdio_priv->regulator);
                if (err == -EPROBE_DEFER)
                        goto free_mdio_bus;
                mdio_priv->regulator = NULL;
        }

        if (mdio_priv->regulator) {
                err = regulator_enable(mdio_priv->regulator);
                if (err) {
                        dev_err(dev, "fail to enable phy-supply\n");
                        goto free_mdio_bus;
                }
        }

        err = mdiobus_register(bus);
        if (err) {
                dev_err(dev, "cannot register internal MDIO bus (%d)\n", err);
                goto free_mdio_bus;
        }

        if (is_enetc_rev1(pf->si)) {
                phylink_pcs = lynx_pcs_create_mdiodev(bus, 0, &serdes, num_phys);
                if (IS_ERR(phylink_pcs)) {
                        err = PTR_ERR(phylink_pcs);
                        dev_err(dev, "cannot create lynx pcs (%d)\n", err);
                        goto unregister_mdiobus;
                }
        } else {
                switch (pf->si->revision) {
                case ENETC_REV_4_1:
                        xpcs_ver = DW_XPCS_VER_MX95;
                        break;
                default:
                        dev_err(dev, "unsupported xpcs version\n");
                        goto unregister_mdiobus;
                }
                phylink_pcs = xpcs_create_mdiodev_with_phy(bus, 0, 16, 0,
                                                           xpcs_ver,
                                                           pf->if_mode);
                if (IS_ERR(phylink_pcs)) {
                        err = PTR_ERR(phylink_pcs);
                        dev_err(dev, "cannot create xpcs mdiodev (%d)\n", err);
                        goto unregister_mdiobus;
                }
        }

        pf->imdio = bus;
        pf->pcs = phylink_pcs;

        return 0;

unregister_mdiobus:
        mdiobus_unregister(bus);
free_mdio_bus:
        mdiobus_free(bus);
        return err;
}

static bool enetc_port_has_pcs(struct enetc_pf *pf)
{
        return (pf->if_mode == PHY_INTERFACE_MODE_SGMII ||
                pf->if_mode == PHY_INTERFACE_MODE_1000BASEX ||
                pf->if_mode == PHY_INTERFACE_MODE_2500BASEX ||
                pf->if_mode == PHY_INTERFACE_MODE_10GBASER ||
                pf->if_mode == PHY_INTERFACE_MODE_USXGMII ||
                pf->if_mode == PHY_INTERFACE_MODE_XGMII);
}

int enetc_mdiobus_create(struct enetc_pf *pf, struct device_node *node)
{
        struct device_node *mdio_np;
        int err;

        mdio_np = of_get_child_by_name(node, "mdio");
        if (mdio_np) {
                err = enetc_mdio_probe(pf, mdio_np);

                of_node_put(mdio_np);
                if (err)
                        return err;
        }

        if (enetc_port_has_pcs(pf)) {
                err = enetc_imdio_create(pf);
                if (err) {
                        enetc_mdio_remove(pf);
                        return err;
                }
        }

        return 0;
}

int enetc_phylink_create(struct enetc_ndev_priv *priv,
                         struct device_node *node,
                         const struct phylink_mac_ops *pl_mac_ops)
{
        struct enetc_pf *pf = enetc_si_priv(priv->si);
        struct enetc_si *si = priv->si;
        struct phylink *phylink;
        int err;

        pf->phylink_config.dev = &priv->ndev->dev;
        pf->phylink_config.type = PHYLINK_NETDEV;

        if (is_enetc_rev1(si))
                pf->phylink_config.mac_capabilities = MAC_ASYM_PAUSE | MAC_SYM_PAUSE |
                        MAC_10 | MAC_100 | MAC_1000 | MAC_2500FD;
        else
                pf->phylink_config.mac_capabilities = MAC_ASYM_PAUSE | MAC_SYM_PAUSE |
                        MAC_10 | MAC_100 | MAC_1000FD | MAC_2500FD | MAC_10000FD;

        __set_bit(PHY_INTERFACE_MODE_INTERNAL,
                  pf->phylink_config.supported_interfaces);
        __set_bit(PHY_INTERFACE_MODE_SGMII,
                  pf->phylink_config.supported_interfaces);
        __set_bit(PHY_INTERFACE_MODE_RMII,
                  pf->phylink_config.supported_interfaces);
        __set_bit(PHY_INTERFACE_MODE_1000BASEX,
                  pf->phylink_config.supported_interfaces);
        __set_bit(PHY_INTERFACE_MODE_2500BASEX,
                  pf->phylink_config.supported_interfaces);
        __set_bit(PHY_INTERFACE_MODE_10GBASER,
                  pf->phylink_config.supported_interfaces);
        __set_bit(PHY_INTERFACE_MODE_USXGMII,
                  pf->phylink_config.supported_interfaces);
        __set_bit(PHY_INTERFACE_MODE_XGMII,
                  pf->phylink_config.supported_interfaces);

        phy_interface_set_rgmii(pf->phylink_config.supported_interfaces);

        phylink = phylink_create(&pf->phylink_config, of_fwnode_handle(node),
                                 pf->if_mode, pl_mac_ops);
        if (IS_ERR(phylink)) {
                err = PTR_ERR(phylink);
                return err;
        }

        priv->phylink = phylink;

        return 0;
}

static void enetc_imdio_remove(struct enetc_pf *pf)
{
        struct enetc_mdio_priv *mdio_priv;

        if (pf->pcs) {
                if (is_enetc_rev1(pf->si))
                        lynx_pcs_destroy(pf->pcs);
                else
                        xpcs_pcs_destroy(pf->pcs);
        }

        if (pf->imdio) {
                mdio_priv = pf->imdio->priv;

                mdiobus_unregister(pf->imdio);
                if (mdio_priv && mdio_priv->regulator)
                        regulator_disable(mdio_priv->regulator);
                mdiobus_free(pf->imdio);
        }
}

void enetc_mdiobus_destroy(struct enetc_pf *pf)
{
        enetc_mdio_remove(pf);

        if (enetc_port_has_pcs(pf))
                enetc_imdio_remove(pf);
}

void enetc_phylink_destroy(struct enetc_ndev_priv *priv)
{
        phylink_destroy(priv->phylink);
}

static inline void enetc_load_primary_mac_addr(struct enetc_hw *hw,
                                               struct net_device *ndev)
{
        u8 addr[ETH_ALEN] __aligned(4);

        *(u32 *)addr = __raw_readl(hw->reg + ENETC_SIPMAR0);
        *(u16 *)(addr + 4) = __raw_readw(hw->reg + ENETC_SIPMAR1);
        eth_hw_addr_set(ndev, addr);
}

void enetc_pf_netdev_setup(struct enetc_si *si, struct net_device *ndev,
                           const struct net_device_ops *ndev_ops)
{
        struct enetc_ndev_priv *priv = netdev_priv(ndev);

        SET_NETDEV_DEV(ndev, &si->pdev->dev);
        priv->ndev = ndev;
        priv->si = si;
        priv->dev = &si->pdev->dev;
        si->ndev = ndev;

	/* pick up primary MAC address from SI */
        enetc_load_primary_mac_addr(&si->hw, ndev);
}

static void enetc_detect_errata(struct enetc_si *si)
{
        if (is_enetc_rev1(si))
                si->errata = ENETC_ERR_VLAN_ISOL | ENETC_ERR_UCMCSWP;
}

static void enetc_kfree_si(struct enetc_si *si)
{
        char *p = (char *)si - si->pad;

        kfree(p);
}

int enetc_pci_probe(struct pci_dev *pdev, const char *name, int sizeof_priv)
{
        struct enetc_si *si, *p;
        struct enetc_hw *hw;
        size_t alloc_size;
        int err, len;

        pcie_flr(pdev);
        err = pci_enable_device_mem(pdev);
        if (err)
                return dev_err_probe(&pdev->dev, err, "device enable failed\n");

        /* set up for high or low dma */
        err = dma_set_mask_and_coherent(&pdev->dev, DMA_BIT_MASK(64));
        if (err) {
                dev_err(&pdev->dev, "DMA configuration failed: 0x%x\n", err);
                goto err_dma;
        }

        err = pci_request_mem_regions(pdev, name);
        if (err) {
                dev_err(&pdev->dev, "pci_request_regions failed err=%d\n", err);
                goto err_pci_mem_reg;
        }

        pci_set_master(pdev);

        alloc_size = sizeof(struct enetc_si);
        if (sizeof_priv) {
                /* align priv to 32B */
                alloc_size = ALIGN(alloc_size, ENETC_SI_ALIGN);
                alloc_size += sizeof_priv;
        }
        /* force 32B alignment for enetc_si */
        alloc_size += ENETC_SI_ALIGN - 1;

        p = kzalloc(alloc_size, GFP_KERNEL);
        if (!p) {
                err = -ENOMEM;
                goto err_alloc_si;
        }

        si = PTR_ALIGN(p, ENETC_SI_ALIGN);
        si->pad = (char *)si - (char *)p;

        pci_set_drvdata(pdev, si);
        si->pdev = pdev;
        hw = &si->hw;

        len = pci_resource_len(pdev, ENETC_BAR_REGS);
        hw->reg = ioremap(pci_resource_start(pdev, ENETC_BAR_REGS), len);
        if (!hw->reg) {
                err = -ENXIO;
                dev_err(&pdev->dev, "ioremap() failed\n");
                goto err_ioremap;
        }
        if (len > ENETC_PORT_BASE)
                hw->port = hw->reg + ENETC_PORT_BASE;
        if (len > ENETC_GLOBAL_BASE)
                hw->global = hw->reg + ENETC_GLOBAL_BASE;

        enetc_detect_errata(si);

        return 0;

err_ioremap:
        enetc_kfree_si(si);
err_alloc_si:
        pci_release_mem_regions(pdev);
err_pci_mem_reg:
err_dma:
        pci_disable_device(pdev);

        return err;
}

static void enetc4_mac_config(struct enetc_pf *pf, unsigned int mode,
		phy_interface_t phy_mode)
{
	struct enetc_ndev_priv *priv = netdev_priv(pf->si->ndev);
	struct enetc_si *si = pf->si;
	u32 val;

	if (si->hw_features & ENETC_SI_F_PPM)
		return;

	val = enetc_port_mac_rd(si, ENETC4_PM_IF_MODE(0));
	val &= ~(PM_IF_MODE_IFMODE | PM_IF_MODE_ENA);

	switch (phy_mode) {
		case PHY_INTERFACE_MODE_RGMII:
		case PHY_INTERFACE_MODE_RGMII_ID:
		case PHY_INTERFACE_MODE_RGMII_RXID:
		case PHY_INTERFACE_MODE_RGMII_TXID:
			val |= IFMODE_RGMII;
			/* We need to enable auto-negotiation for the MAC
			 * if its RGMII interface support In-Band status.
			 */
			if (phylink_autoneg_inband(mode))
				val |= PM_IF_MODE_ENA;
			break;
		case PHY_INTERFACE_MODE_RMII:
			val |= IFMODE_RMII;
			break;
		case PHY_INTERFACE_MODE_SGMII:
		case PHY_INTERFACE_MODE_2500BASEX:
			val |= IFMODE_SGMII;
			break;
		case PHY_INTERFACE_MODE_10GBASER:
		case PHY_INTERFACE_MODE_XGMII:
		case PHY_INTERFACE_MODE_USXGMII:
			val |= IFMODE_XGMII;
			break;
		default:
			dev_err(priv->dev,
					"Unsupported PHY mode:%d\n", phy_mode);
			return;
	}

	enetc_port_mac_wr(si, ENETC4_PM_IF_MODE(0), val);
}

static struct phylink_pcs *
enetc4_pl_mac_select_pcs(struct phylink_config *config, phy_interface_t iface)
{
	struct enetc_pf *pf = phylink_to_enetc_pf(config);

	return pf->pcs;
}

static void enetc4_pl_mac_config(struct phylink_config *config,
		unsigned int mode,
		const struct phylink_link_state *state)
{
	struct enetc_pf *pf = phylink_to_enetc_pf(config);

	enetc4_mac_config(pf, mode, state->interface);
}

static void enetc4_set_port_speed(struct enetc_ndev_priv *priv, int speed)
{
	u32 old_speed = priv->speed;
	u32 val;

	if (speed == old_speed)
		return;

	val = enetc_port_rd(&priv->si->hw, ENETC4_PCR);
	val &= ~PCR_PSPEED;

	switch (speed) {
		case SPEED_10:
		case SPEED_100:
		case SPEED_1000:
		case SPEED_2500:
		case SPEED_10000:
			val |= (PCR_PSPEED & PCR_PSPEED_VAL(speed));
			break;
		default:
			val |= (PCR_PSPEED & PCR_PSPEED_VAL(SPEED_10));
	}

	priv->speed = speed;
	enetc_port_wr(&priv->si->hw, ENETC4_PCR, val);
}

static void enetc4_set_rgmii_mac(struct enetc_pf *pf, int speed, int duplex)
{
	struct enetc_si *si = pf->si;
	u32 old_val, val;

	old_val = enetc_port_mac_rd(si, ENETC4_PM_IF_MODE(0));
	val = old_val & ~(PM_IF_MODE_ENA | PM_IF_MODE_M10 | PM_IF_MODE_REVMII);

	switch (speed) {
		case SPEED_1000:
			val = u32_replace_bits(val, SSP_1G, PM_IF_MODE_SSP);
			break;
		case SPEED_100:
			val = u32_replace_bits(val, SSP_100M, PM_IF_MODE_SSP);
			break;
		case SPEED_10:
			val = u32_replace_bits(val, SSP_10M, PM_IF_MODE_SSP);
	}

	val = u32_replace_bits(val, duplex == DUPLEX_FULL ? 0 : 1,
			PM_IF_MODE_HD);

	if (val == old_val)
		return;

	enetc_port_mac_wr(si, ENETC4_PM_IF_MODE(0), val);
}

static void enetc4_set_rmii_mac(struct enetc_pf *pf, int speed, int duplex)
{
	struct enetc_si *si = pf->si;
	u32 old_val, val;

	old_val = enetc_port_mac_rd(si, ENETC4_PM_IF_MODE(0));
	val = old_val & ~(PM_IF_MODE_ENA | PM_IF_MODE_SSP);

	switch (speed) {
		case SPEED_100:
			val &= ~PM_IF_MODE_M10;
			break;
		case SPEED_10:
			val |= PM_IF_MODE_M10;
	}

	val = u32_replace_bits(val, duplex == DUPLEX_FULL ? 0 : 1,
			PM_IF_MODE_HD);

	if (val == old_val)
		return;

	enetc_port_mac_wr(si, ENETC4_PM_IF_MODE(0), val);
}

static void enetc4_enable_mac(struct enetc_pf *pf, bool en)
{
	struct enetc_hw *hw = &pf->si->hw;
	struct enetc_si *si = pf->si;
	u32 val;

	enetc_port_wr(hw, ENETC4_POR, en ? 0 : POR_TXDIS | POR_RXDIS);

	val = enetc_port_mac_rd(si, ENETC4_PM_CMD_CFG(0));
	val &= ~(PM_CMD_CFG_TX_EN | PM_CMD_CFG_RX_EN);
	val |= en ? (PM_CMD_CFG_TX_EN | PM_CMD_CFG_RX_EN) : 0;

	enetc_port_mac_wr(si, ENETC4_PM_CMD_CFG(0), val);
}

static void enetc4_pf_send_link_status_msg(struct enetc_pf *pf, bool up)
{
	struct device *dev = &pf->si->pdev->dev;
	union enetc_pf_msg pf_msg;
	u16 ms_mask = 0;
	int i, err;

	for (i = 0; i < pf->num_vfs; i++)
		if (pf->vf_link_status_notify[i])
			ms_mask |= PSIMSGSR_MS(i);

	if (!ms_mask)
		return;

	pf_msg.class_id = ENETC_MSG_CLASS_ID_LINK_STATUS;
	pf_msg.class_code = up ? ENETC_PF_NC_LINK_STATUS_UP :
		ENETC_PF_NC_LINK_STATUS_DOWN;

	err = enetc_pf_send_msg(pf, pf_msg.code, ms_mask);
	if (err)
		dev_err(dev, "PF notifies link status failed\n");
}

static void enetc4_pl_mac_link_up(struct phylink_config *config,
		struct phy_device *phy, unsigned int mode,
		phy_interface_t interface, int speed,
		int duplex, bool tx_pause, bool rx_pause)
{
	struct enetc_pf *pf = phylink_to_enetc_pf(config);
	struct enetc_si *si = pf->si;
	struct enetc_ndev_priv *priv;
	bool hd_fc = false;

	priv = netdev_priv(si->ndev);
	enetc4_set_port_speed(priv, speed);

	if (!phylink_autoneg_inband(mode) &&
			phy_interface_mode_is_rgmii(interface))
		enetc4_set_rgmii_mac(pf, speed, duplex);

	if (interface == PHY_INTERFACE_MODE_RMII)
		enetc4_set_rmii_mac(pf, speed, duplex);

	if (duplex == DUPLEX_FULL) {
		/* When preemption is enabled, generation of PAUSE frames
		 * must be disabled, as stated in the IEEE 802.3 standard.
		 */
		if (priv->active_offloads & ENETC_F_QBU)
			tx_pause = false;
	} else { /* DUPLEX_HALF */
		if (tx_pause || rx_pause)
			hd_fc = true;

		/* As per 802.3 annex 31B, PAUSE frames are only supported
		 * when the link is configured for full duplex operation.
		 */
		tx_pause = false;
		rx_pause = false;
	}

	enetc4_enable_mac(pf, true);

	priv->eee.eee_active = phylink_init_eee(priv->phylink, true) >= 0;
	enetc_eee_mode_set(si->ndev, priv->eee.eee_active);

	if (si->hw_features & ENETC_SI_F_QBU)
		enetc_mm_link_state_update(priv, true);

	enetc4_pf_send_link_status_msg(pf, true);
}

static void enetc4_pl_mac_link_down(struct phylink_config *config,
		unsigned int mode,
		phy_interface_t interface)
{
	struct enetc_pf *pf = phylink_to_enetc_pf(config);
	struct enetc_si *si = pf->si;
	struct enetc_ndev_priv *priv;

	priv = netdev_priv(si->ndev);

	priv->eee.eee_active = false;
	enetc_eee_mode_set(si->ndev, priv->eee.eee_active);

	if (si->hw_features & ENETC_SI_F_QBU)
		enetc_mm_link_state_update(priv, false);

	enetc4_pf_send_link_status_msg(pf, false);
	enetc4_enable_mac(pf, false);
}

static const struct phylink_mac_ops enetc_pl_mac_ops = {
	.mac_select_pcs = enetc4_pl_mac_select_pcs,
	.mac_config = enetc4_pl_mac_config,
	.mac_link_up = enetc4_pl_mac_link_up,
	.mac_link_down = enetc4_pl_mac_link_down,
};

static int enetc4_pf_init(struct enetc_pf *pf)
{
	struct device *dev = &pf->si->pdev->dev;

	enetc_get_ip_revision(pf->si);
	
	if (!dev->of_node) {
		dev_err(dev, "No device tree node found!\n");
		return -ENODEV;
	}

	return 0;
}

static int enetc4_link_init(struct enetc_ndev_priv *priv,
		struct device_node *node)
{
	struct enetc_pf *pf = enetc_si_priv(priv->si);
	struct device *dev = priv->dev;
	int err;

	err = of_get_phy_mode(node, &pf->if_mode);
	if (err) {
		dev_err(dev, "Failed to get PHY mode\n");
		return err;
	}

	err = enetc_mdiobus_create(pf, node);
	if (err) {
		dev_err(dev, "Failed to create MDIO bus\n");
		return err;
	}

	err = enetc_phylink_create(priv, node, &enetc_pl_mac_ops);
	if (err) {
		dev_err(dev, "Failed to create phylink\n");
		goto err_phylink_create;
	}

	return 0;

err_phylink_create:
	enetc_mdiobus_destroy(pf);

	return err;
}

static int enetc4_pf_netdev_create(struct enetc_si *si)
{
        struct device *dev = &si->pdev->dev;
        struct enetc_ndev_priv *priv;
        struct net_device *ndev;
        int err;

        ndev = alloc_etherdev_mqs(sizeof(struct enetc_ndev_priv),1,1);
        if (!ndev)
                return  -ENOMEM;

        priv = netdev_priv(ndev);
        mutex_init(&priv->mm_lock);

        if (si->pdev->rcec)
                priv->rcec = si->pdev->rcec;

        priv->ref_clk = devm_clk_get_optional_enabled(dev, "enet_ref_clk");
        if (IS_ERR(priv->ref_clk)) {
                dev_err(dev, "Get enet_ref_clk failed\n");
                err = PTR_ERR(priv->ref_clk);
                goto err_clk_get;
        }

	si->ndev = ndev;

	enetc_pf_netdev_setup(si, ndev, NULL);

	err = enetc4_link_init(priv, dev->of_node);
        if (err)
                return err;
        return 0;

err_clk_get:
        mutex_destroy(&priv->mm_lock);
        free_netdev(ndev);

        return err;
}

static int enetc4_pf_struct_init(struct enetc_si *si)
{
	struct enetc_pf *pf = enetc_si_priv(si);

	pf->si = si;
	pf->total_vfs = pci_sriov_get_totalvfs(si->pdev);
	if (pf->total_vfs) {
		pf->vf_state = kcalloc(pf->total_vfs, sizeof(struct enetc_vf_state),
				GFP_KERNEL);
		if (!pf->vf_state)
			return -ENOMEM;
	}

	return 0;
}

static void enetc4_pf_struct_deinit(struct enetc_pf *pf)
{
	kfree(pf->vf_state);
}

static bool enetc_is_emdio_consumer(const struct device_node *np)
{
	struct device_node *phy_node, *mdio_node;

	/* If the node does not have phy-handle property, then the PF
	 * does not connect to a PHY, so it is not the EMDIO consumer.
	 */
	phy_node = of_parse_phandle(np, "phy-handle", 0);
	if (!phy_node)
		return false;

	of_node_put(phy_node);

	/* If the node has phy-handle property and it contains a mdio
	 * child node, then the PF is not the EMDIO consumer.
	 */
	mdio_node = of_get_child_by_name(np, "mdio");
	if (mdio_node) {
		of_node_put(mdio_node);
		return false;
	}

	return true;
}

static int enetc_add_emdio_consumer(struct pci_dev *pdev)
{
	struct device_node *node = pdev->dev.of_node;
	struct device *dev = &pdev->dev;
	struct device_node *phy_node;
	struct phy_device *phydev;
	struct device_link *link;

	if (!node || !enetc_is_emdio_consumer(node))
		return 0;

	phy_node = of_parse_phandle(node, "phy-handle", 0);
	if (!phy_node) {
		dev_err(dev, "No PHY handle found in device tree\n");
		return -ENODEV;
	}	
	phydev = of_phy_find_device(phy_node);
	of_node_put(phy_node);
	if (!phydev) {
		dev_warn(dev, "PHY device not ready, deferring probe\n");
		return -EPROBE_DEFER;
	}
	link = device_link_add(dev, phydev->mdio.bus->parent,
			DL_FLAG_PM_RUNTIME |
			DL_FLAG_AUTOREMOVE_SUPPLIER);
	put_device(&phydev->mdio.dev);
	if (!link){
		dev_err(dev, "Failed to create device link\n");
		return -EINVAL;
	}

	dev_info(dev, "Successfully linked to PHY device\n");

	return 0;
}

static int enetc_phylink_connect(struct net_device *ndev)
{
        struct enetc_ndev_priv *priv = netdev_priv(ndev);
        int err;

	if (!priv->phylink) {
		dev_err(&ndev->dev, "phylink not initialized\n");
		return -ENODEV;
	}

        err = phylink_of_phy_connect(priv->phylink, priv->dev->of_node, 0);
        if (err) {
                dev_err(&ndev->dev, "could not attach to PHY\n");
                return err;
        }

        phylink_start(priv->phylink);

	dev_info(&ndev->dev, "ENETC4 phylink connected and started\n");
        return 0;
}

static int enetc4_pf_probe(struct pci_dev *pdev)
{
	struct device *dev = &pdev->dev;
	struct enetc_si *si;
	struct enetc_pf *pf;
	char wq_name[24];
	int err;

	if (enetc_pf_is_owned_by_mcore(pdev))
		return 0;

	pinctrl_pm_select_default_state(dev);

	err = enetc_pci_probe(pdev, KBUILD_MODNAME, sizeof(*pf));
	if (err) {
		dev_err(dev, "PCIe probing failed\n");
		return err;
	}

	/* si is the private data. */
	si = pci_get_drvdata(pdev);
	if (!si->hw.port || !si->hw.global) {
		err = -ENODEV;
		dev_err(dev, "Couldn't map PF only space!\n");
		goto err_enetc_pci_probe;
	}

	err = enetc4_pf_struct_init(si);
	if (err)
		goto err_pf_struct_init;

	pf = enetc_si_priv(si);
	snprintf(wq_name, sizeof(wq_name), "enetc-%s", pci_name(pdev));
	si->workqueue = create_singlethread_workqueue(wq_name);
	if (!si->workqueue) {
		err = -ENOMEM;
		goto err_create_wq;
	}

	err = enetc4_pf_init(pf);
	if (err)
		goto err_pf_init;

	err = enetc4_pf_netdev_create(si);
	if (err)
		return err;


	return 0;

err_pf_init:
	destroy_workqueue(si->workqueue);
err_create_wq:
	enetc4_pf_struct_deinit(pf);
err_pf_struct_init:
err_enetc_pci_probe:
	enetc_pci_remove(pdev);

	return err;
}

static int enetc4_uio_reset_phy(struct enetc4_uio_priv *priv)
{
	if (!gpio_is_valid(priv->phy_reset_gpio))
		return -EINVAL;

	gpio_direction_output(priv->phy_reset_gpio, 0);
	msleep(20);
	gpio_set_value(priv->phy_reset_gpio, 1);
	msleep(200);
	return 0;
}

static int enetc4_uio_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
	struct device *dev = &pdev->dev;
	struct enetc4_uio_priv *priv;
	struct enetc_si *si = pci_get_drvdata(pdev);
	struct enetc_ndev_priv *priv_ndev;
	int ret;

	if (enetc_pf_is_owned_by_mcore(pdev))
		return 0;

	ret = enetc_add_emdio_consumer(pdev);
	if (ret) {
		if (ret == -EPROBE_DEFER) {
			dev_info(dev, "PHY not ready, deferring probe\n");
		}
		return ret;
	}

	pinctrl_pm_select_default_state(dev);

	priv = devm_kzalloc(dev, sizeof(*priv), GFP_KERNEL);
	if (!priv)
		return -ENOMEM;

	priv->pdev = pdev;

	priv->reg_phy = devm_regulator_get_optional(dev, "phy");
	if (IS_ERR(priv->reg_phy)) {
		if (PTR_ERR(priv->reg_phy) == -EPROBE_DEFER) {
			dev_info(dev, "PHY regulator not ready, deferring\n");
			return -EPROBE_DEFER;
		}
		priv->reg_phy = NULL;
	} else {
		ret = regulator_enable(priv->reg_phy);
		if (ret) {
			dev_err(dev, "Failed to enable PHY regulator\n");
			return ret;
		}
	}

	priv->phy_reset_gpio = of_get_named_gpio(dev->of_node, "phy-reset-gpios", 0);
	if (gpio_is_valid(priv->phy_reset_gpio)) {
		ret = devm_gpio_request_one(dev, priv->phy_reset_gpio, 
				GPIOF_OUT_INIT_LOW, "phy-reset");
		if (ret) {
			dev_err(dev, "Failed to request PHY reset GPIO\n");
			goto err_regulator;
		}

		ret = enetc4_uio_reset_phy(priv);
		if (ret)
			dev_warn(dev, "Failed to reset PHY\n");
	}

	pci_set_drvdata(pdev, priv);

	ret = enetc4_pf_probe(pdev);
	if (ret) {
		dev_err(dev, "ENETC4 PF probe failed: %d\n", ret);
		goto err_regulator;
	}

	si = pci_get_drvdata(pdev);
	priv_ndev = netdev_priv(si->ndev);
	
	ret = clk_prepare_enable(priv_ndev->ref_clk);
        if (ret) {
                return ret;
	}

	if (si && si->ndev) {
		ret = enetc_phylink_connect(si->ndev);
		if (ret) {
			dev_warn(dev, "Failed to connect phylink: %d\n", ret);
        	}
    	}

	/* Set up UIO info */
        priv->uio.name = "enetc4_uio";
        priv->uio.version = "1.0";
        priv->uio.priv = priv;

	ret = uio_register_device(dev, &priv->uio);
	if (ret) {
		dev_err(dev, "Failed to register UIO device: %d\n", ret);
		goto err_clk;
	}

	dev_info(dev, "ENETC4 UIO driver initialized successfully\n");
	return 0;

err_clk:
	clk_disable_unprepare(priv_ndev->ref_clk);
err_regulator:
	if (priv->reg_phy)
		regulator_disable(priv->reg_phy);
	return ret;
}

static void enetc4_uio_remove(struct pci_dev *pdev)
{
	dev_info(&pdev->dev, "ENETC4 UIO driver removed\n");
}

static const struct pci_device_id enetc4_uio_pci_ids[] = {
    { PCI_DEVICE(0x1131, 0xe101) },
    { 0, }
};
MODULE_DEVICE_TABLE(pci, enetc4_uio_pci_ids);

static struct pci_driver enetc4_uio_driver = {
    .name = "enetc4_uio",
    .id_table = enetc4_uio_pci_ids,
    .probe = enetc4_uio_probe,
    .remove = enetc4_uio_remove,
};

static int __init enetc4_uio_init(void)
{
	pr_info("%s: NXP ENETC4 UIO driver v%s\n", DRIVER_NAME, DRIVER_VERSION);
	return pci_register_driver(&enetc4_uio_driver);
}

static void __exit enetc4_uio_exit(void)
{
	pci_unregister_driver(&enetc4_uio_driver);
	pr_info("%s: driver unloaded\n", DRIVER_NAME);
}

module_init(enetc4_uio_init);
module_exit(enetc4_uio_exit);

MODULE_VERSION(DRIVER_VERSION);
MODULE_LICENSE("GPL");
MODULE_AUTHOR("NXP");
MODULE_DESCRIPTION("ENETC4-UIO driver");
