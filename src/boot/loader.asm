;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 打开保护模式
; 加载内核
; 启动分页
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
  ; gs 保存显存段地址
  mov ax, 0xb800
  mov gs, ax

  ; 打印字符串
  mov byte [gs:0x00], '2'
  ; 绿色背景闪烁，红色前景
  mov byte [gs:0x01], 0xA4

  mov byte [gs:0x02], ' '
  mov byte [gs:0x03], 0xA4

  mov byte [gs:0x04], 'L'
  mov byte [gs:0x05], 0xA4

  mov byte [gs:0x06], 'O'
  mov byte [gs:0x07], 0xA4
  
  mov byte [gs:0x08], 'A'
  mov byte [gs:0x09], 0xA4

  mov byte [gs:0x0a], 'D'
  mov byte [gs:0x0b], 0xA4

  mov byte [gs:0x0c], 'E'
  mov byte [gs:0x0d], 0xA4

  mov byte [gs:0x0e], 'R'
  mov byte [gs:0x0f], 0xA4

  jmp $
