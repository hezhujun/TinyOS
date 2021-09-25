;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; mbr.asm
; 主引导程序，位于硬盘的 0 扇区
; 主板会自动加载该主引导程序
; 加载地址是 0x7c00
; 该文件的主要作用是加载存放在2扇区的 loader 程序
; loader 程序最长占4个扇区空间
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

  jmp $

  message db "1 MBR"
  times 510-($-$$) db 0
  db 0x55, 0xaa
