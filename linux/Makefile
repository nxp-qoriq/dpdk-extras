#SPDX-License-Identifier: GPL-2.0
#Copyright 2024 NXP

PWD=$(shell pwd)
INSTALL_DIR ?= ${PWD}/install
MODULE_INSTALL_DIR := ${INSTALL_DIR}/
KSRC ?= /lib/modules/$(shell uname -r)/build

all:
	$(MAKE) ARCH=$(ARCH) -C $(KSRC)/ M=$(CURDIR)

clean:
	$(MAKE) ARCH=$(ARCH) -C $(KSRC) M=$(PWD) clean
	rm -rf ${MODULE_INSTALL_DIR}/*.ko

install:
	install  -D  kpage_ncache/kpage_ncache.ko ${MODULE_INSTALL_DIR}/kpage_ncache.ko
	install  -D  igb_uio/igb_uio.ko ${MODULE_INSTALL_DIR}/igb_uio.ko
