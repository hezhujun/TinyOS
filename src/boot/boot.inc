; loader 加载后的地址
LOADER_BASE_ADDR equ 0x900
LOADER_CODE_ADDR equ 0x900 + 0x300
; 栈顶地址
LOADER_STACK_TOP equ LOADER_BASE_ADDR
; loader 起始扇区 lba 地址
LOADER_START_SECTOR equ 0x2
; loader 扇区个数
LOADER_START_COUNT equ 4

; GDT 描述符属性
; 段界限粒度
GDT_G_1B equ 0
GDT_G_4KB equ 1 << 23
; 有效地址和操作数大小 16 位或 32 位
GDT_D_B_16 equ 0
GDT_D_B_32 equ 1 << 22
; 是否是 64 位代码段
GDT_L_0 equ 0
GDT_L_1 equ 1 << 21
; AVaiLable 可用的，针对用户
GDT_AVL_0 equ 0
GDT_AVL_1 equ 1 << 20
; Present 段是否存在
GDT_P_0 equ 0
GDT_P_1 equ 1 << 15
; Descriptor Privilege Level 描述符特权级
GDT_DPL_0 equ 0
GDT_DPL_1 equ 1 << 13
GDT_DPL_2 equ 1 << 14
GDT_DPL_3 equ (1 << 13) | (1 << 14)
; 是否是系统段 是 不是
GDT_S_0 equ 0
GDT_S_1 equ 1 << 12
; 非系统段类型
GDT_TYPE_X_CODE equ 1 << 11
GDT_TYPE_X_DATA equ 0
; 一致性代码段，是否听从、依从转移前的低特权级
GDT_TYPE_CODE_C_0 equ 0
GDT_TYPE_CODE_C_1 equ 1 << 10
; 代码段是否可读
GDT_TYPE_CODE_R_0 equ 0
GDT_TYPE_CODE_R_1 equ 1 << 9
; Accessed 代码段是否被访问过，由 CPU 设置
GDT_TYPE_CODE_A_0 equ 0
GDT_TYPE_CODE_A_1 equ 1 << 8
; Extend 段的扩展方向
; 0 向上扩展，地址越来越高，通常用于代码段或数据段
; 1 向下扩展，地址越来越低，通常用于栈段
GDT_TYPE_DATA_E_0 equ 0
GDT_TYPE_DATA_E_1 equ 1 << 10
; Writable 是否可写
GDT_TYPE_DATA_W_0 equ 0
GDT_TYPE_DATA_W_1 equ 1 << 9
; Accessed 代码段是否被访问过，由 CPU 设置
GDT_TYPE_DATA_A_0 equ 0
GDT_TYPE_DATA_A_1 equ 1 << 8

; 选择子属性
; 请求特权级
SELECTOR_RPL_0 equ 00b
SELECTOR_RPL_1 equ 01b
SELECTOR_RPL_2 equ 10b
SELECTOR_RPL_3 equ 11b
; Table Indicator 描述符表索引
SELECTOR_TI_GDT equ 000b
SELECTOR_TI_LDT equ 000b

; 页目录表位置和页项属性
PAGE_DIR_TABLE_POS equ 0x100000
PG_P_0 equ 0
PG_P_1 equ 1
PG_RW_R equ 00b
PG_RW_W equ 10b
PG_US_S equ 000b
PG_US_U equ 100b

; kernel.bin所在扇区号
KERNEL_START_SECTOR equ 9
; 从磁盘读出后写入的地址
KERNEL_BIN_BASE_ADDR equ 0x70000
; 读取的扇区数
KERNEL_SECTOR_COUNT equ 200
; 内核运行起始地址
KERNEL_ENTRY_POINT equ 0xc0001500
; program header type 忽略类型
PT_NULL equ 0
