#SPDX-License-Identifier: GPL-2.0
#Copyright 2024-2026 NXP

KSRC ?= /lib/modules/$(shell uname -r)/build

all:
	make -C $(KSRC)/ M=$(CURDIR)

%:
	make -C $(KSRC)/ M=$(CURDIR) $@

clean:
	make -C $(KSRC) M=$(PWD) clean
