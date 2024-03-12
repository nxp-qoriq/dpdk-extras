KSRC ?= /lib/modules/$(shell uname -r)/build

all:
	make -C $(KSRC)/ M=$(CURDIR)/igb_uio
	make -C $(KSRC)/ M=$(CURDIR)/kpage_ncache

clean:
	make -C $(KSRC) M=$(PWD)/igb_uio clean
	make -C $(KSRC) M=$(PWD)/kpage_ncache clean
