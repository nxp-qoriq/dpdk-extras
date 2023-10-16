KSRC ?= /lib/modules/$(shell uname -r)/build

all:
	make -C $(KSRC)/ M=$(CURDIR)

%:
	make -C $(KSRC)/ M=$(CURDIR) $@

clean:
	make -C $(KSRC) M=$(PWD) clean
