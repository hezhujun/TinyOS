;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; mbr.asm
; 主引导程序，位于硬盘的 0 扇区
; 主板会自动加载该主引导程序
; 加载地址是 0x7c00
; 该文件的主要作用是加载存放在2扇区的 loader 程序
; loader 程序最长占4个扇区空间
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%include "boot.inc"
; mbr loader 默认加载地址是 0x7c00
section mbr vstart=0x7c00
  ; 初始化段寄存器
  mov ax, cs
  mov ds, ax
  mov es, ax
  mov ss, ax
  mov fs, ax
  ; 设置栈顶
  mov sp, 0x7c00
  ; gs 保存显存段地址
  mov ax, 0xb800
  mov gs, ax

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 利用0x10中断的0x06子功能清空屏幕
; 参考 https://zh.wikipedia.org/wiki/INT_10H
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  mov ah, 0x06
  mov al, 0
  ; 左上角字符的行号
  mov ch, 0
  ; 左上角字符的列号
  mov cl, 0
  ; 右下角字符的行号
  mov dh, 24
  ; 右下角字符的列号
  mov dl, 79
  int 0x10

  ; 输出字符串
  mov byte [gs:0x00], '1'
  ; 绿色背景闪烁，红色前景
  mov byte [gs:0x01], 0xA4

  mov byte [gs:0x02], ' '
  mov byte [gs:0x03], 0xA4

  mov byte [gs:0x04], 'M'
  mov byte [gs:0x05], 0xA4

  mov byte [gs:0x06], 'B'
  mov byte [gs:0x07], 0xA4
  
  mov byte [gs:0x08], 'R'
  mov byte [gs:0x09], 0xA4

  ; 加在 loader
  ; loader 加载后的地址
  mov ax, LOADER_BASE_ADDR
  push ax
  ; 待读取的扇区数
  mov ax, LOADER_START_COUNT
  push ax
  ; 起始扇区 lba 地址
  mov eax, LOADER_START_SECTOR
  push eax
  call load_disk_16

  jmp LOADER_BASE_ADDR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 加载硬盘数据
; 把从 sector_index 开始的 count 个扇区的内容加载到address
; void load_disk(uint32_t sector_index, uint8_t count, void* address)
; 使用 LBA28 地址，sector_index 28位，扇区从 0 开始编号
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
load_disk_16:
  push bp
  mov bp, sp
  push ebx

  ; 当前栈的内容 
  ; 
  ; 内容          大小
  ; address       2
  ; count         2
  ; sector_index  4
  ; 返回地址      2
  ; 原bp          2     <-bp
  ; eax           4
  ; ebx           4
  ; ecx           4
  ; edx           4     <-sp

  ; 设置 count register
  mov dx, 0x1f2
  mov ax, [bp+8]
  out dx, al

  ; 设置扇区起始地址
  mov eax, [bp+4]
  ; LBA 地址 7-0 位写入端口 0x1f3
  mov dx, 0x1f3
  out dx, al
  ; LBA 地址 15-8 位写入端口 0x1f4
  mov dx, 0x1f4
  shr eax, 8
  out dx, al
  ; LBA 地址 23-16 位写入端口 0x1f5
  mov dx, 0x1f5
  shr eax, 8
  out dx, al
  ; LBA 地址 31-24
  shr eax, 8
  ; LBA 地址 24-27 位写入端口 0x1f6
  mov dx, 0x1f6
  and al, 0x0f
  ; 7-4 位设为 1110，表示 lba 模式
  or al, 0xe0
  out dx, al

  ; 设置 command register，设置读命令
  mov dx, 0x1f7
  mov al, 0x20
  out dx, al

.wait:
  ; 不操作，等待一个指令执行时间
  nop
  ; 从 Status 寄存器读取硬盘状态
  in al, dx
  ; 读取第 3 位和第 7 位
  and al, 0x88
  ; 判断第 3 位 DRQ 是否设为 1，第 7 位 1 表示磁盘正忙
  cmp al, 0x08
  ; 设备未就绪，循环等待
  jnz .wait

  ; 计算待读取数据的大小
  ; 扇区个数
  mov ax, [bp+8]
  ; 扇区大小
  mov cx, 512
  ; [dx:ax] 表示数据总大小
  mul cx
  shl edx, 16
  mov dx, ax
  mov ecx, edx
  ; 读取数据次数 读取扇区数*512/2(一次读2个字节)
  shr ecx, 1

  mov dx, 0x1f0
  mov bx, [bp+10]
  ; 循环读取
.read_loop:
  in ax, dx
  mov [bx], ax
  add bx, 2
  loop .read_loop

  pop ebx

  mov sp, bp
  pop bp

  ret

  times 510-($-$$) db 0
  db 0x55, 0xaa
