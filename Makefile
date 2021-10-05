BOCHS_SOURCE_DIR=bochs-2.6.2
BOCHS_HOME=bochs
BOCHS_DISK_FILE=hd60M.img
BOCHS_CONFIG_FILE=bochsrc

SRC_DIR = src
BUILD_DIR = build

AS = nasm

# 下载并编译 bochs
$(BOCHS_HOME):
	./bochs_init.sh

$(BOCHS_DISK_FILE):
	$(BOCHS_HOME)/bin/bximage -hd -mode="flat" -size=60 -q $@

.PHONY: run
run:
	$(BOCHS_HOME)/bin/bochs -f $(BOCHS_CONFIG_FILE) -q

# boot 相关
$(BUILD_DIR)/boot/mbr.bin: $(SRC_DIR)/boot/mbr.asm $(SRC_DIR)/boot/boot.inc 
	mkdir -p $(BUILD_DIR)/boot
	$(AS) -I $(SRC_DIR)/boot/ $< -o $@

$(BUILD_DIR)/boot/loader.bin: $(SRC_DIR)/boot/loader.asm $(SRC_DIR)/boot/boot.inc 
	mkdir -p $(BUILD_DIR)/boot
	$(AS) -I $(SRC_DIR)/boot/ $< -o $@

# 写入磁盘
.PHONY: write_mbr
write_mbr: $(BOCHS_DISK_FILE) $(BUILD_DIR)/boot/mbr.bin
	dd if=$(BUILD_DIR)/boot/mbr.bin of=$(BOCHS_DISK_FILE) bs=512 count=1 seek=0 conv=notrunc

.PHONY: write_loader
write_loader: $(BUILD_DIR)/boot/loader.bin
	dd if=$(BUILD_DIR)/boot/loader.bin of=$(BOCHS_DISK_FILE) bs=512 count=4 seek=2 conv=notrunc
