BOCHS_SOURCE_DIR=bochs-2.6.2
BOCHS_HOME=bochs
BOCHS_DISK_FILE=hd60M.img
BOCHS_CONFIG_FILE=bochsrc

# 下载并编译 bochs
$(BOCHS_HOME):
	./bochs_init.sh

$(BOCHS_DISK_FILE):
	$(BOCHS_HOME)/bin/bximage -hd -mode="flat" -size=60 -q $@

.PHONY: run
run:
	$(BOCHS_HOME)/bin/bochs -f $(BOCHS_CONFIG_FILE)
