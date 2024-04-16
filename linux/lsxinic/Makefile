KSRC ?= /lib/modules/$(shell uname -r)/build
DPDKDIR ?= /lib/dpdk

all:
	make -C $(KSRC)/ M=$(CURDIR) CC="$(CROSS_COMPILE)gcc -I$(DPDKDIR)/drivers/net/lsxinic"

%:
	make -C $(KSRC)/ M=$(CURDIR) CC="$(CROSS_COMPILE)gcc -I$(DPDKDIR)/drivers/net/lsxinic" $@
