;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 打开保护模式
; 加载内核
; 启动分页
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
  jmp loader_start

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

gdt_ptr dw GDT_LIMIT
  dd GDT_BASE
loadermsg db '2 loader in real.'

loader_start:
  mov sp, LOADER_STACK_TOP

  ; INT 0x10 功能号 0x13 打印字符串
  ; 输入：
  ;   AH: 子功能好 = 0x13
  ;   BH: 页码
  ;   BL: 属性（若 AL=0x00 或  0x01）
  ;   CX: 字符串长度
  ;   (DH, DL): 坐标（行、列）
  ;   ES:BP: 字符串长度
  ;   AL: 显示输出方式
  ;     0: 字符串只含显示字符，显示属性在 BL 中，显示后，光标位置不变
  ;     1: 字符串只含显示字符，显示属性在 BL 中，显示后，光标位置改变
  ;     2: 字符串中含显示字符和显示属性。显示后，光标位置不变
  ;     3: 字符串中含显示字符和显示属性。显示后，光标位置改变
  ; 返回：
  ;   无返回值
  mov ax, 0
  mov es, ax
  mov bp, loadermsg
  mov cx, 17
  mov al, 0x01
  mov bx, 0x001f
  mov dx, 0x1800
  mov ah, 0x13
  int 0x10

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
