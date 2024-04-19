#SPDX-License-Identifier: GPL-2.0
#Copyright 2024 NXP

KSRC ?= /lib/modules/$(shell uname -r)/build
PWD=$(shell pwd)
INSTALL_DIR ?= ${PWD}/../install
MODULE_INSTALL_DIR ?= ${INSTALL_DIR}/

all:
	make -C $(KSRC)/ M=$(CURDIR)

%:
	make -C $(KSRC)/ M=$(CURDIR) $@

clean:
	make -C $(KSRC) M=$(PWD) clean
	rm -rf *.mod Module.symvers

install:
	install  -D  igb_uio.ko ${MODULE_INSTALL_DIR}/igb_uio.ko
