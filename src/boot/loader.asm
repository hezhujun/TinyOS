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

  jmp $

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
  
  mov esp, LOADER_STACK_TOP
  mov ax, SELECTOR_VIDEO
  mov gs, ax
  mov byte [gs:160], 'P'
  mov byte [gs:161], 0x0f

  jmp $
