ifndef NAVISERVER
    NAVISERVER  = /usr/local/ns
endif

include  $(NAVISERVER)/include/Makefile.module

install:
	$(INSTALL_SH) nsstats.tcl $(INSTSRVPAG)/	
	$(INSTALL_SH) nsstats.adp $(INSTSRVPAG)/
