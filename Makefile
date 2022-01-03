BOCHS_SOURCE_DIR=bochs-2.6.2
BOCHS_HOME=bochs
BOCHS_DISK_FILE=hd60M.img
BOCHS_CONFIG_FILE=bochsrc
ENTRY_POINT = 0xc0001500

SRC_DIR = src
BUILD_DIR = build

AS = nasm
CC = gcc
LD = ld
ASFLAGS = -g -f elf
CFLAGS = -m32 -O0 -Wall -fno-pie -c
LDFLAGS = -m elf_i386 -Ttext $(ENTRY_POINT) -e main
OBJS = $(BUILD_DIR)/kernel/main.o

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

.PHONY: write_kernel
write_kernel: $(BUILD_DIR)/kernel/kernel.bin
	dd if=$(BUILD_DIR)/kernel/kernel.bin of=$(BOCHS_DISK_FILE) bs=512 count=200 seek=9 conv=notrunc

# C 代码编译
$(BUILD_DIR)/kernel/main.o: $(SRC_DIR)/kernel/main.c
	mkdir -p $(BUILD_DIR)/kernel
	$(CC) $(CFLAGS) $< -o $@
	objcopy --remove-section .note.gnu.property $@

$(BUILD_DIR)/kernel/main.s: $(SRC_DIR)/kernel/main.c
	mkdir -p $(BUILD_DIR)/kernel
	$(CC) -m32 -Wall -fno-builtin -S $< -o $@

# 链接
$(BUILD_DIR)/kernel/kernel.bin: $(OBJS)
	$(LD) $(LDFLAGS) $^ -o $@

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)

.PHONY: debug
debug: clean write_mbr write_loader $(BUILD_DIR)/kernel/kernel.bin write_kernel run
