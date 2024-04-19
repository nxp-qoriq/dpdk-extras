#SPDX-License-Identifier: GPL-2.0
#Copyright 2024 NXP

KSRC ?= /lib/modules/$(shell uname -r)/build
PWD=$(shell pwd)
INSTALL_DIR ?= ${PWD}/../install
MODULE_INSTALL_DIR ?= ${INSTALL_DIR}/

all:
ifneq ($(DPDKDIR),)
	make -C $(KSRC)/ M=$(CURDIR) CC="$(CROSS_COMPILE)gcc -I$(DPDKDIR)/drivers/net/lsxinic"
endif
%:
ifneq ($(DPDKDIR),)
	make -C $(KSRC)/ M=$(CURDIR) CC="$(CROSS_COMPILE)gcc -I$(DPDKDIR)/drivers/net/lsxinic" $@
endif
clean:
	make -C $(KSRC) M=$(PWD) clean

install:
ifneq ($(DPDKDIR),"")
	install  -D lsinic_kmod.ko ${MODULE_INSTALL_DIR}/lsinic_kmod.ko
endif
