;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 打开保护模式
; 加载内核
; 启动分页
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR

; 构建 GDT
GDT_BASE dd 0x0
  dd 0x0
; 代码段描述符，使用平坦模式，使用整个4GB空间
; 段基址为 0x00000000
; 段界限为 0xfffff        4GB / 4KB - 1 = 2的20次方-1
; 0xf<<16 是段界限的16-19位设为1
CODE_DESC dd 0x0000ffff
  dd GDT_G_4KB | GDT_D_B_32 | GDT_L_0 | GDT_AVL_0 | (0xf << 16) | GDT_P_1 | GDT_DPL_0 | GDT_S_1 | GDT_TYPE_X_CODE | GDT_TYPE_CODE_C_0 | GDT_TYPE_CODE_R_0 | GDT_TYPE_CODE_A_0

; 数据段和栈段描述符，使用平坦模式，使用整个4GB空间
; 段基址为 0x00000000
; 段界限为 0xfffff        4GB / 4KB - 1 = 2的20次方-1
; 0xf<<16 是段界限的16-19位设为1
DATA_STACK_DESC dd 0x0000ffff
  dd GDT_G_4KB | GDT_D_B_32 | GDT_L_0 | GDT_AVL_0 | (0xf << 16) | GDT_P_1 | GDT_DPL_0 | GDT_S_1 | GDT_TYPE_X_DATA | GDT_TYPE_DATA_E_0 | GDT_TYPE_DATA_W_1 | GDT_TYPE_DATA_A_0

; 显存段描述符，0xb8000-0xbffff
; 段基址为 0xb8000
; 段界限为 0x7        (0xbffff + 1 - 0xb8000) / 4KB - 1 = 7
VIDEO_DESC dd 0x80000007
  dd GDT_G_4KB | GDT_D_B_32 | GDT_L_0 | GDT_AVL_0 | GDT_P_1 | GDT_DPL_0 | GDT_S_1 | GDT_TYPE_X_DATA | GDT_TYPE_DATA_E_0 | GDT_TYPE_DATA_W_1 | GDT_TYPE_DATA_A_0 | 0xb

GDT_SIZE equ $ - GDT_BASE
GDT_LIMIT equ GDT_SIZE - 1
; 预留60个描述符的空位
times 60 dq 0

SELECTOR_CODE equ (0x1 << 3) + SELECTOR_TI_GDT + SELECTOR_RPL_0
SELECTOR_DATA equ (0x2 << 3) + SELECTOR_TI_GDT + SELECTOR_RPL_0
SELECTOR_STACK equ (0x2 << 3) + SELECTOR_TI_GDT + SELECTOR_RPL_0
SELECTOR_VIDEO equ (0x3 << 3) + SELECTOR_TI_GDT + SELECTOR_RPL_0

; total_memory_bytes 保持内存容量，以字节为单位
; 当前偏移 loader.bin 文件头 (4 + 60) * 8 = 0x200 字节
; loader.bin 的加载地址是 0x900
; 故 total_memory_bytes 内存中的地址是 0xb00
total_memory_bytes dd 0

gdt_ptr dw GDT_LIMIT
  dd GDT_BASE

; 人工对齐
; total_memory_bytes 4 + gdt_ptr 6 + ards_buf 244 ards_cnt 2 共 256 字节
ards_buf times 244 db 0
ards_cnt dw 0

; 到此处偏移大小是 0x300
loader_start:
  mov sp, LOADER_STACK_TOP

  mov eax, total_memory_bytes
  push eax
  call detect_memory

  ; 进入保护模式
  ; 1 打开 A20 
  in al, 0x92
  or al, 0000_0010B
  out 0x92, al

  ; 2 加载 gdt
  lgdt [gdt_ptr]

  ; 3 将 cr0 的 pe 位设为 1
  mov eax, cr0
  or eax, 0x1
  mov cr0, eax

  ; 刷新流水线
  jmp dword SELECTOR_CODE:protect_mode_start

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 检测物理内存容量
; int detect_memory(uint32_t& total_memory_bytes)
; 成功，返回1
; 失败，返回0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
detect_memory:
  push bp
  mov bp, sp

  mov eax, [bp+4]
  push eax
  call detect_memory_e820
  cmp ax, 1
  je .detect_memory_end

  call detect_memory_e801
  cmp ax, 1
  je .detect_memory_end

  call detect_memory_e88

.detect_memory_end:
  mov sp, bp
  pop bp
  ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 利用 BIOS 中断 0x15 子功能 0xE820 检测物理内存容量
; int detect_memory_e820(uint32_t& total_memory_bytes)
; 成功，返回1
; 失败，返回0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
detect_memory_e820:
  push bp
  mov bp, sp

  push ebx
  push ecx
  push edx
  push es
  push di

  xor ebx, ebx
  mov di, ards_buf
  mov ecx, 20
  mov edx, 0x534d4150

.e820_loop:
  mov eax, 0xe820
  int 0x15
  jc .e820_error
  inc word [ards_cnt]
  cmp ebx, 0
  jz .e820_end
  add di, cx
  jmp .e820_loop

.e820_end:
  ; 找最大可用内存
  xor ecx, ecx
  ; ards 个数
  mov cx, [ards_cnt]
  ; 用于存放最大内存大小值
  xor edx, edx
  mov di, ards_buf
.find_max_memory:
  mov eax, [es:di]
  add eax, [es:di+8]
  cmp edx, eax
  jge .next_ards
  mov edx, eax
.next_ards:
  add di, 20
  loop .find_max_memory

  mov eax, [bp+4]
  mov [eax], edx

  mov eax, 1
  jmp .e820_return

.e820_error:
  mov eax, 0
  jmp .e820_return

.e820_return:
  pop di
  pop es
  pop edx
  pop ecx
  pop ebx

  mov sp, bp
  pop bp
  ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 利用 BIOS 中断 0x15 子功能 0xE801 检测物理内存容量
; int detect_memory_e801(uint32_t& total_memory_bytes)
; 成功，返回1
; 失败，返回0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
detect_memory_e801:
  push bp
  mov bp, sp

  push ebx
  push ecx
  push edx

  mov ax, 0xe801
  int 0x15
  jc .e801_error

  xor edx, edx
  ; 15MB 以下的内存容量，单位为1KB
  mov cx, 1024
  mul cx
  shl edx, 16
  and eax, 0x0000ffff
  or edx, eax
  ; 加上 1MB
  add edx, 0x100000

  push edx
  xor eax, eax
  ; 16MB-4GB的内存容量，单位是64KB
  mov ax, bx
  mov ecx, 1024*64
  mul ecx
  ; 16MB-4GB范围内的内存大小存放在eax，因为此方法只能测出4GB以内的内存，所以32位eax足够了
  pop edx
  add edx, eax
  
  mov eax, [bp+4]
  mov [eax], edx
  mov eax, 1
  jmp .e801_return

.e801_error:
  mov eax, 0

.e801_return:
  pop edx
  pop ecx
  pop ebx

  mov sp, bp
  pop bp
  ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 利用 BIOS 中断 0x15 子功能 0x88 检测物理内存容量
; int detect_memory_e88(uint32_t& total_memory_bytes)
; 成功，返回1
; 失败，返回0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
detect_memory_e88:
  push bp
  mov bp, sp

  push ecx
  push edx

  or eax, eax
  mov ah, 0x88
  int 0x15
  jc .88_error
  or edx, edx
  ; ax 记录内存容量，1KB 为单位大小，内存空间 1MB 之上的连续单位数量
  mov cx, 1024
  mul cx
  shl edx, 16
  or edx, eax
  add edx, 0x100000

  mov eax, [bp+4]
  mov [eax], edx

  mov eax, 1
  jmp .88_return

.88_error:
  mov eax, 0

.88_return:
  pop edx
  pop ecx

  mov sp, bp
  pop bp
  ret

[bits 32]
protect_mode_start:
  mov ax, SELECTOR_DATA
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax
  mov ss, ax

  mov eax, 0
  mov ebx, eax
  mov ecx, eax
  mov edx, eax
  mov esi, eax
  mov edi, eax
  mov ebp, eax
  
  mov esp, LOADER_STACK_TOP
  mov ax, SELECTOR_VIDEO
  mov gs, ax
  mov byte [gs:160], 'P'
  mov byte [gs:161], 0x0f

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 加载内核
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  push KERNEL_BIN_BASE_ADDR
  push KERNEL_SECTOR_COUNT
  push KERNEL_START_SECTOR
  call load_disk_32

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 启动内存分页机制
; 1 准备好页目录表和页表
; 2 将页表地址写入控制寄存器 CR3
; 3 寄存器 CR0 的 PG 位置 1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; 初始化页目录表和页表
  call setup_page

  ; 保存全局描述符
  sgdt [gdt_ptr]

  ; 修改全局描述符表里面的地址
  ; 将 gdt 描述符中显存段描述符中的段基址 + 0xc0000000
  mov ebx, [gdt_ptr + 2]
  ; 显存段是第 3 个描述符，3*8=24，段描述符的高 4 字节的最高位是段基址的第 31-24 位
  or dword [ebx + 24 + 4], 0xc0000000

  ; 将 gdt 基址加上 0xc0000000 使其成为内核所在的高地址
  add dword [gdt_ptr + 2], 0xc0000000

  ; 将栈指针同样映射到内核地址
  add esp, 0xc0000000

  ; 把页目录地址赋给cr3
  mov eax, PAGE_DIR_TABLE_POS
  mov cr3, eax
  
  ; 打开cr0的pg位
  mov eax, cr0
  or eax, 1<<31
  mov cr0, eax
  
  ; 开启分页后，用gdt新的地址重新加载
  lgdt [gdt_ptr]

  mov byte [gs:160], 'V'
  jmp SELECTOR_CODE:enter_kernel

enter_kernel:
  call kernel_init

  ; 寄存器重新初始化
  mov ax, SELECTOR_DATA
  mov ds, ax
  mov ss, ax
  mov es, ax
  mov fs, ax
  mov gs, ax

  mov eax, 0
  mov ebx, eax
  mov ecx, eax
  mov edx, eax
  mov esi, eax
  mov edi, eax
  mov ebp, eax

  ; 栈地址在物理地址1MB的顶部
  ; 内核代码不会很多，不会和栈空间冲突
  mov esp, 0xc009f000
  jmp KERNEL_ENTRY_POINT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 创建页目录和页表
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
setup_page:
  push ebp
  mov ebp, esp

  push ebx
  push ecx
  push edi

  ; 页目录表内容清0
  push 4096
  push 0
  push PAGE_DIR_TABLE_POS
  call memset
  add esp, 12

  ; 设置页目录表0项，768项，1023项
  ; 0项保证启动分页后，当前的代码可以继续执行
  ; 768项把当前的低物理地址映射到高位的虚拟地址
  ; 内核在高位地址上运行
  ; 1023项使得内核可以访问修改页目录页和页表页
.create_pde:
  mov eax, PAGE_DIR_TABLE_POS + 0x1000
  mov ebx, eax
  or eax, PG_P_1 | PG_RW_W | PG_US_U
  mov [PAGE_DIR_TABLE_POS + 0x0], eax
  mov [PAGE_DIR_TABLE_POS + 4 * 768], eax
  sub eax, 0x1000
  mov [PAGE_DIR_TABLE_POS + 0x1000 - 4], eax

  ; 设置第一个页表
  ; 映射物理内存的前1MB内存，共256项
  mov ecx, 256
  mov eax, 0
  mov edi, 0
  or eax, PG_P_1 | PG_RW_W | PG_US_U
.create_pte:
  mov [ebx+edi], eax
  add edi, 4
  add eax, 0x1000
  loop .create_pte
  ; 剩余的页表项清0
  push (1024 - 256) * 4
  push 0
  add ebx, edi
  push ebx
  call memset
  add esp, 12

  ; 设置页目录表 769-1022项
  ; 这些页目录表项映射高地址空间
  ; 所有进程共享这些高地址空间
  mov eax, PAGE_DIR_TABLE_POS
  add eax, 0x2000
  or eax, PG_US_U | PG_RW_W | PG_P_1
  mov ebx, PAGE_DIR_TABLE_POS
  mov ecx, 254
  mov edi, 769
.create_kernel_pde:
  mov [ebx+edi*4], eax
  inc edi
  add eax, 0x1000
  loop .create_kernel_pde

  ; 清理页目录表 769-1022项所指向的页表
  mov eax, PAGE_DIR_TABLE_POS
  add eax, 0x2000
  push 4096 * 254
  push 0
  push eax
  call memset

  pop edi
  pop ecx
  pop ebx

  mov esp, ebp
  pop ebp
  ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void *memset(void *str, uint8_t c, uint32_t n)
; 用 c 填充 str 指向的大小为 n 的内存块
; 只使用 c 的低8位作为填充物，即把 c 当成字符
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
memset:
  push ebp
  mov ebp, esp
  push edi
  push ebx

  mov ecx, [ebp+16]
  mov edi, 0
  mov eax, [ebp+12]
  mov ebx, [ebp+8]
.memset_loop:
  mov [ebx+edi], al
  inc edi
  loop .memset_loop

  pop ebx
  pop edi
  mov esp, ebp
  pop ebp

  ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 加载硬盘数据
; 把从 sector_index 开始的 count 个扇区的内容加载到 address
; void load_disk(uint32_t sector_index, uint32_t count, void* address)
; 使用LBA28地址，sector_index 28位，扇区从0开始编号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
load_disk_32:
  push ebp
  mov ebp, esp
  push ecx
  push edx
  push edi

  ; 设置 count register
  mov eax, [ebp+12]
  mov dx, 0x1f2
  out dx, al

  ; 设置扇区起始地址
  mov eax, [ebp+8]
  mov dx, 0x1f3
  out dx, al
  mov dx, 0x1f4
  shr eax, 8
  out dx, al
  mov dx, 0x1f5
  shr eax, 8
  out dx, al
  mov dx, 0x1f6
  shr eax, 8
  or al, 0xe0
  out dx, al

  ; 设置command register，设置读命令
  mov dx, 0x1f7
  mov al, 0x20
  out dx, al

.wait:
  nop
  in al, dx
  and al, 0x88
  cmp al, 0x08
  jnz .wait

  mov eax, [ebp+12]
  mov cx, 512
  mul cx
  shl edx, 16
  mov dx, ax
  mov ecx, edx
  shr ecx, 1

  cld
  mov edi, [ebp+16]
  mov dx, 0x1f0
  rep insw

  pop edi
  pop edx
  pop ecx
  mov esp, ebp
  pop ebp

  ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 解析kernel.bin的内容
; 把代码段segment拷贝到实际运行所在的地址
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
kernel_init:
  push ebp
  mov ebp, esp
  push ebx
  push ecx
  push edx 

  xor eax, eax
  ; 记录程序头表地址
  xor ebx, ebx
  ; cx 记录程序头表的 program header 数量
  xor ecx, ecx
  ; dx 记录 program header 尺寸
  xor edx, edx

  ; 读取 e_phentsize
  mov dx, [KERNEL_BIN_BASE_ADDR + 42]
  ; 读取 e_phoff
  mov ebx, [KERNEL_BIN_BASE_ADDR + 28]
  ; 第一个 program header 的内存地址
  add ebx, KERNEL_BIN_BASE_ADDR
  ; 读取 e_phnum
  mov cx, [KERNEL_BIN_BASE_ADDR + 44]

.each_segment:
  ; 此 program header 是否未使用
  cmp byte [ebx + 0], PT_NULL
  je .PTNULL
  push ecx
  ; 读取 p_filesz, 压入 size
  push dword [ebx + 16]
  mov eax, [ebx + 4]
  add eax, KERNEL_BIN_BASE_ADDR
  ; 压入 src
  push eax
  ; 读取 p_vaddr, 压入 dst
  push dword [ebx + 8]
  call memcpy
  ; 清理栈中压入的三个参数
  add esp, 12
  pop ecx
.PTNULL:
.PTPHDR:
  ; edx 是 program header 大小，使 ebx 指向下一个 program header
  add ebx, edx
  loop .each_segment

  pop edx
  pop ecx
  pop ebx
  mov esp, ebp
  pop ebp

  ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; void memcpy(void *dest, void *src, uint32_t n)
; 内存段拷贝
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
memcpy:
  push ebp
  mov ebp, esp
  push ecx
  push edi
  push esi

  cld
  mov edi, [ebp + 8]
  mov esi, [ebp + 12]
  mov ecx, [ebp + 16]
  rep movsb

  pop esi
  pop edi
  pop ecx
  mov esp, ebp
  pop ebp

  ret
