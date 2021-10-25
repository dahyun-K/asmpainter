.386
.model flat,stdcall
option casemap:none

include windows.inc
include user32.inc
include kernel32.inc
include comctl32.inc
include gdi32.inc
include comdlg32.inc
include msvcrt.inc
include shell32.inc
include shlwapi.inc

includelib user32.lib
includelib msvcrt.lib
includelib kernel32.lib
includelib comctl32.lib
includelib gdi32.lib
includelib comdlg32.lib
includelib msvcrt.lib ;for debug
;---------------EQU等值定义-----------------
ID_NEW               EQU            40001
ID_OPEN              EQU            40002
ID_SAVE              EQU            40003
ID_SAVE_AS           EQU            40004
ID_QUIT              EQU            40005
ID_UNDO              EQU            40006
ID_CLEAR             EQU            40007
ID_TOOL              EQU            40008
ID_PEN               EQU            40009
ID_ERASER            EQU            40010
ID_FOR_COLOR         EQU            40012
ID_BACK_COLOR        EQU            40014
ID_ONE_PIXEL         EQU            40016
ID_TWO_PIXEL         EQU            40018
ID_FOUR_PIXEL        EQU            40019
ID_ERA_TWO_PIXEL     EQU            40025
ID_ERA_FOUR_PIXEL    EQU            40026
ID_ERA_EIGHT_PIXEL   EQU            40027
ID_ERA_SIXTEEN_PIXEL EQU            40028
ID_CANVAS_SIZE       EQU            40029

ID_STATUSBAR         EQU            100
IDR_MENU1            EQU            101
IDI_ICON1            EQU            102
IDB_CONTROLS         EQU            103
IDC_PEN              EQU            111
IDC_ERASER2          EQU            113
IDC_ERASER4          EQU            114
IDC_ERASER8          EQU            115
IDC_ERASER16         EQU            116
;-----------------函数原型声明-------------------
WinMain PROTO                                     ;主窗口
ProcWinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD     ;窗口运行中的消息处理程序
ProcWinCanvas PROTO :DWORD,:DWORD,:DWORD,:DWORD   ;画布窗口运行中的消息处理程序
CreateCanvasWin PROTO
UpdateCanvasPos PROTO
printf PROTO C :PTR BYTE, :VARARG
sprintf PROTO C :PTR BYTE, :PTR BYTE, :VARARG

mBitmap STRUCT
  bitmap HBITMAP ?
  nWidth DWORD ?
  nHeight DWORD ?
mBitmap ENDS

.data
  hInstance         dd ?                   ;本模块的句柄
  hWinMain          dd ?                   ;窗口句柄
  hCanvas           dd ?                   ;画布句柄
  hMenu             dd ?                   ;菜单句柄
  hWinToolBar       dd ?                   ;工具栏
  hWinStatusBar     dd ?                   ;状态栏
  hImageListControl dd ?
  hCurPen           dd ?                   ;鼠标光标
  hCurEraser_2      dd ?                   ;橡皮光标 2像素
  hCurEraser_4      dd ?
  hCurEraser_8      dd ?
  hCurEraser_16     dd ?

  CursorPosition	POINT <0,0>			    	;光标逻辑位置
  CoordinateFormat	byte  "%d,%d",0			;显示坐标格式
  TextBuffer		byte  24 DUP(0)	     		;输出缓冲
  
  foregroundColor       dd 0                    ;前景色
  backgroundColor       dd 0ffffffh             ;背景色
  customColorBuffer     dd 16 dup(?)            ;颜色缓冲区，用于自定义颜色

  ; 画布所使用的变量
  ; 以下是实际像素
  canvasMargin            equ 5
  ; 以下的大小均为逻辑像素，而非屏幕上实际显示的单个像素
  defaultCanvasWidth      equ 800
  defaultCanvasHeight     equ 600
  nowCanvasWidth          dd ?
  nowCanvasHeight         dd ? 
  nowCanvasOffsetX        dd 0
  nowCanvasOffsetY        dd 0
  nowCanvasZoomLevel      dd 1 ; 一个逻辑像素在屏幕上占据几个实际像素的宽度
  hBackgroundBrush       HBRUSH ?
  
  historyNums          equ 50                             ;存储 50 条历史记录
  historyBitmap        mBitmap historyNums DUP(<>)  ;历史记录的位图
  historyBitmapIndex   dd  0       ;当前历史记录位图中即将拷贝进缓存区的位图索引
  ; baseDCBuf          HDC ?       ; 某次绘制位图的基础画板
  drawDCBuf            HDC ?       ; 绘制了当前绘制的画板
  undoMaxLimit         dd  0       ; 
  
  stToolBar  equ   this byte  ;定义工具栏按钮
    TBBUTTON <0,ID_NEW,TBSTATE_ENABLED,TBSTYLE_BUTTON,0,0,NULL>;新建
    TBBUTTON <1,ID_OPEN,TBSTATE_ENABLED,TBSTYLE_BUTTON,0,0,NULL>;打开
    TBBUTTON <2,ID_SAVE,TBSTATE_ENABLED,TBSTYLE_BUTTON,0,0,NULL>;保存 
    TBBUTTON <7,ID_UNDO,TBSTATE_ENABLED,TBSTYLE_BUTTON,0,0,NULL>;撤回
    TBBUTTON <4,ID_PEN,TBSTATE_ENABLED, TBSTYLE_CHECKGROUP, 0, 0, NULL>;画笔
    TBBUTTON <5,ID_ERASER,TBSTATE_ENABLED,TBSTYLE_CHECKGROUP, 0, 0, NULL>;橡皮
    TBBUTTON <10,ID_FOR_COLOR,TBSTATE_ENABLED,TBSTYLE_BUTTON,0,0,NULL>;前景色
    TBBUTTON <11,ID_BACK_COLOR,TBSTATE_ENABLED,TBSTYLE_BUTTON,0,0,NULL>;背景色
  ControlButtonNum=($-stToolBar)/sizeof TBBUTTON

.const
  szMainWindowTitle            db "画图",0         ;主窗口标题
  szWindowClassName            db "MainWindow",0      ;菜单类名称
  szToolBarClassName           db "ToolbarWindow32",0         
  szStatusBarClassName         db "msctls_statusbar32",0       
  szCanvasClassName            db "画布", 0
  lptbab                       TBADDBITMAP  <NULL,?>
;--------for debug---------
  szMouseMoveCanvas   db  "MouseMove in Canvas",0dh,0ah,0
  szLButtonDown       db  "LButtonDown in Canvas",0dh,0ah,0
  szLButtonUp         db  "LButtonUp in Canvas",0dh,0ah,0
;--------for debug---------
  debugUINT  db "%u", 0Ah, 0Dh, 0
  debugUINT2  db "%u %u", 0Ah, 0Dh, 0
  debugUINT4  db "%u %u %u %u", 0Ah, 0Dh, 0

.code

; 宏定义
m2m macro M1, M2  
  push M2
  pop M1
endm


return macro arg
  mov eax, arg
  ret
endm

CStr macro text
  local text_var
    .const                           ; Open the const section
  text_var db text,0                 ; Add the text to text_var
    .code                            ; Reopen the code section
  exitm                              ; Return the offset of test_var address
endm


CTEXT MACRO y:VARARG
  LOCAL sym
  CONST segment
  IFIDNI <y>,<>
    sym db 0
  ELSE
    sym db y,0
  ENDIF
  CONST ends
  EXITM <OFFSET sym>
ENDM

get_invoke macro dst , name, args: VARARG
  invoke name, args
  mov dst, eax
endm

; Windows 像素坐标的 offset 是
; 是 Canvas 逻辑坐标的

; 将相对于 Canvas Windows Client Area 的像素坐标转换成为 Canvas 的逻辑坐标
CoordWindowToCanvas proc coordWindow: PTR POINT
  ; invoke crt_printf, CTEXT("before transformation: ")
  mov esi, coordWindow

  sub (POINT PTR [esi]).x, canvasMargin
  sub (POINT PTR [esi]).y, canvasMargin
  mov ebx, nowCanvasZoomLevel
  ; x 坐标
  mov eax, (POINT PTR [esi]).x
  mov edx, 0
  div ebx
  add eax, nowCanvasOffsetX
  mov (POINT PTR [esi]).x, eax
  ; y 坐标
  mov eax, (POINT PTR [esi]).y
  mov edx, 0
  div ebx
  add eax, nowCanvasOffsetY
  mov (POINT PTR [esi]).y, eax
  ret 
CoordWindowToCanvas endp

; 将 Canvas 的逻辑坐标转换成为相对于 Canvas Windows Client Area 的像素坐标
CoordCanvasToWindow proc coordCanvas: PTR POINT
  ; 如果不在画布左上角的右下方会出问题
  mov esi, coordCanvas
  mov ebx, nowCanvasZoomLevel
  ; x 坐标
  mov eax, (POINT PTR [esi]).x
  sub eax, nowCanvasOffsetX
  mov edx, 0
  mul ebx
  add eax, canvasMargin
  mov (POINT PTR [esi]).x, eax
  ; y 坐标
  mov eax, (POINT PTR [esi]).y
  sub eax, nowCanvasOffsetY
  mov edx, 0
  mul ebx
  add eax, canvasMargin
  mov (POINT PTR [esi]).y, eax
  ret   
CoordCanvasToWindow endp

Quit proc
  invoke DestroyWindow,hWinMain           ;删除窗口
  invoke PostQuitMessage,NULL             ;在消息队列中插入一个WM_QUIT消息
  ret
Quit endp

; 获取鼠标逻辑坐标
GetCursorPosition proc
  local point:POINT
  local rect:RECT
  local ifout:dword		;是否超出画布域外
  mov ifout, 0
  invoke GetCursorPos, addr point
  invoke GetClientRect, hCanvas, addr rect
  mov ebx, point.x
  
  ; 判断超出区域，但其实没啥用
  .if ebx > rect.right
    mov ifout, 1
  .elseif ebx < rect.left
    mov ifout, 1
  mov ebx, point.y
  .elseif ebx < rect.top
    mov ifout, 1
  .elseif ebx > rect.bottom
    mov ifout, 1
  .endif
  
  ; 变换坐标
  invoke ScreenToClient, hCanvas, addr point
  invoke CoordWindowToCanvas, addr point
  mov ebx, point.x
  mov CursorPosition.x, ebx
  mov ebx, point.y
  mov CursorPosition.y, ebx
  .if ifout == 1
    mov CursorPosition.x, 0
    mov CursorPosition.y, 0
  .endif
  ret
GetCursorPosition endp

; 显示鼠标的逻辑坐标
ShowCursorPosition proc
  pushad
  invoke GetCursorPosition
  popad
  invoke sprintf, addr TextBuffer, offset CoordinateFormat, CursorPosition.x, CursorPosition.y ; 格式化输出到字符串
  invoke SendMessage, hWinStatusBar, SB_SETTEXT, 0, addr TextBuffer ; 显示坐标
  ret
ShowCursorPosition endp

; 复制 HistoryBitmap 最后的一个到DrawDCBuf，同时要更新画布的宽和高
UpdateDrawBufFromHistoryBitmap proc
; 构造辅助的hTempDC
; 先将historyBitmap的最后一个绑定到临时HDC，
; 再把临时HDC复制给新HDC
  LOCAL @hTempDC:HDC
  LOCAL @hCanvasDC:HDC
  LOCAL @hTempBitmap:HBITMAP
  LOCAL @nWidth: DWORD
  LOCAL @nHeight: DWORD
  local @newDrawBufBitmap: HBITMAP
  pushad
  ; 从 history 中取来最后一个
  mov eax, historyBitmapIndex
  mov edx, 0
  mov ebx, SIZEOF mBitmap ; 这个结构体的字节数
  mul ebx
  mov esi, eax
  lea ebx, historyBitmap
  add esi, ebx
  m2m @hTempBitmap,(mBitmap PTR [esi]).bitmap
  m2m @nWidth,(mBitmap PTR [esi]).nWidth
  m2m @nHeight,(mBitmap PTR [esi]).nHeight
  invoke crt_printf, CTEXT("history map", 0Ah,0Dh)
  invoke crt_printf, addr debugUINT2, @nWidth, @nHeight

  invoke GetDC,hCanvas
  mov @hCanvasDC,eax
  invoke CreateCompatibleDC,@hCanvasDC
  mov @hTempDC,eax
  invoke SelectObject,@hTempDC,@hTempBitmap

  ; 新建一个画布
  invoke CreateCompatibleBitmap, @hCanvasDC, @nWidth, @nHeight
  mov @newDrawBufBitmap, eax ; 不删，留给三行后删
  invoke SelectObject, drawDCBuf, @newDrawBufBitmap
  invoke DeleteObject, eax ;删掉老的 Bitmap
  
  invoke ReleaseDC, hCanvas,@hCanvasDC 
  invoke BitBlt,drawDCBuf,0,0,@nWidth,@nHeight,@hTempDC,0,0,SRCCOPY
  invoke DeleteDC,@hTempDC

  m2m nowCanvasWidth, @nWidth
  m2m nowCanvasHeight, @nHeight

  popad
  ret
UpdateDrawBufFromHistoryBitmap endp

;将当前drawDCBuf转换为Bitmap并存在HistoryBitmap中
UpdateHistoryBitmapFromDrawBuffer proc, nWidth:DWORD,nHeight:DWORD
;输入参数为当前drawDCBuf的宽度和高度
;实现过程：
;       先将historyBitmapIndex+1作为新位图的索引
;       将原来该位置句柄对应的位图释放（因此初始化时一定要将创建50个空位图对应到historyBitmap?）
;       再将drawDCBuf复制到创建的新DC上，然后保存位图句柄到historyBitmap
;注：此函数中没有判断是否增加撤销上限，调用该函数时需要在后面补充
  LOCAL @hTempDC:HDC
  LOCAL @hCanvasDC:HDC
  LOCAL @hTempBitmap:HBITMAP
  LOCAL @nWidth: DWORD
  LOCAL @nHeight: DWORD
  pushad

  mov eax,historyBitmapIndex
  inc eax
  mov historyBitmapIndex,eax
  mov edx, 0
  mov ebx, SIZEOF mBitmap ; 这个结构体的字节数
  mul ebx
  mov esi, eax
  lea ebx, historyBitmap
  add esi, ebx

  invoke DeleteObject, (mBitmap PTR [esi]).bitmap

  invoke GetDC,hCanvas
  mov @hCanvasDC,eax
  invoke CreateCompatibleDC, @hCanvasDC
  mov @hTempDC, eax
  invoke CreateCompatibleBitmap, @hCanvasDC, nWidth, nHeight
  mov @hTempBitmap, eax
  invoke ReleaseDC, hCanvas,@hCanvasDC 
  invoke SelectObject,@hTempDC, @hTempBitmap
  invoke BitBlt, @hTempDC, 0, 0, nWidth, nHeight, drawDCBuf, 0, 0, SRCCOPY
  invoke DeleteDC,@hTempDC


  m2m (mBitmap PTR [esi]).bitmap,@hTempBitmap
  m2m (mBitmap PTR [esi]).nWidth,nWidth
  m2m (mBitmap PTR [esi]).nHeight,nHeight

  popad
  ret
UpdateHistoryBitmapFromDrawBuffer endp

; 重置整个历史，并且把参数的 bitmap 放到第一个位置上
InitHistory proc bitmap: HBITMAP, nWidth: DWORD, nHeight:DWORD

  lea esi, historyBitmap
  m2m (mBitmap PTR [esi]).bitmap ,bitmap
  m2m (mBitmap PTR [esi]).nWidth ,nWidth
  m2m (mBitmap PTR [esi]).nHeight,nHeight

  mov historyBitmapIndex,0
  mov undoMaxLimit,0
  ret
InitHistory endp

; 处理画布创建
; 理论上最开始的时候调用一次
HandleCanvasCreate proc
  local hCanvasDC : HDC
  local hTempDC   : HDC
  local initBitmap: HBITMAP
  local hTempBrush: HBRUSH
  local tempRect  : RECT
  
  invoke UpdateCanvasPos ; 更新位置

  ; 新建一个默认的画布
  invoke GetDC, hCanvas
  mov hCanvasDC, eax
  invoke CreateCompatibleDC, hCanvasDC
  mov drawDCBuf, eax
  invoke CreateCompatibleBitmap, hCanvasDC, defaultCanvasWidth, defaultCanvasHeight  
  mov initBitmap, eax ;不能删这个，交给 historyBitmap 数组去管理
  invoke CreateCompatibleDC, hCanvasDC
  mov hTempDC, eax
  invoke ReleaseDC, hCanvas, hCanvasDC

  ; 涂上全部背景色
  invoke SelectObject, hTempDC, initBitmap
  invoke CreateSolidBrush, backgroundColor
  mov hTempBrush, eax
  mov tempRect.top, 0
  mov tempRect.left, 0
  mov tempRect.right, defaultCanvasWidth
  mov tempRect.bottom, defaultCanvasHeight
  invoke FillRect, hTempDC, addr tempRect, hTempBrush
  ; 初始化到 historyBitmap 里面
  invoke InitHistory, initBitmap, defaultCanvasWidth, defaultCanvasHeight  
  invoke DeleteObject, hTempBrush
  invoke DeleteDC, hTempDC
  
  invoke UpdateDrawBufFromHistoryBitmap       ; 将 historyBitmap 牵引到 DrawBuf 里面去
  invoke InvalidateRect, hCanvas, NULL, FALSE ; invalidaterect 掉整个画布，让 WM_PAINT 去更新
  ret
HandleCanvasCreate endp

; 从文件加载
LoadBitmapFromFile proc

LoadBitmapFromFile endp

;保存到文件
SaveBitmapToFile proc

SaveBitmapToFile endp

; 处理左键按下，也就是开始画图
HandleLButtonDown proc wParam:DWORD, lParam:DWORD
  ;TODO
  ; 标记左键按下
  ; 复制 HistoryBitmap 到 Buffer 中
  ; 需要记录最开始的点
  xor eax, eax
  ret
HandleLButtonDown endp

; 处理左键抬起，也就是结束画图
HandleLButtonUp proc wParam:DWORD, lParam:DWORD
  ; 标记左键抬起
  ; 把 DrawBuf 的 Bitmap 放置到 HistoryBitmap 中 
  ; Repaint 
  xor eax, eax
  ret
HandleLButtonUp endp

; 处理鼠标移动，也就是正在画图
HandleMouseMove proc wParam:DWORD, lParam:DWORD
  pushad
  invoke ShowCursorPosition ; 显示当前坐标
  popad
  ; 判断一下当前是什么移动（需要用一个全局变量维护一下状态栏里面的选取）
  ; 如果不是笔和橡皮这种连续的，就重新复制 HistoryBitmap 到 Buffer 中
  ; 获取当前的鼠标位置（窗口的逻辑坐标），需要利用坐标系变换转换到画布的逻辑坐标
  ; 然后利用这个去画矩形。圆角矩形之类的
  ; 对于笔和橡皮，需要更新“最新的鼠标的位置”
  ; 对于笔和橡皮，可以认为两个 MouseMove 之间的时间很短，因此直接连直线
  xor eax, eax
  ret
HandleMouseMove endp

; 处理鼠标移动开画板，目前没想到没什么要做的？
HandleMouseLeave proc wParam:DWORD, lParam:DWORD
  mov TextBuffer, 0
  invoke SendMessage, hWinStatusBar, SB_SETTEXT, 0, addr TextBuffer ; 消除坐标，但没法用？
  
  xor eax,eax
  ret
HandleMouseLeave endp

;处理鼠标滚轮
; 按下 Ctrl 时候，对应缩放操作
; 没有 Ctrl 的时候，对应上下移动操作
HandleMouseWheel proc wParam:DWORD, lParam:DWORD
  xor eax, eax
  ret
HandleMouseWheel endp


; 将 drawDCBuf 按照合适的比例和偏移复制到 hCanvas 的 DC 上面
RenderBitmap proc
  ; 计算范围
  local tarRect : RECT
  local cRBP : POINT ; (canvas Right Bottom Point)
  local wRBP : POINT ; (window RIght Bottom Point)
  local hCanvasDC : HDC
  local hTempDC : HDC
  local hTempBrush : HBRUSH
  local hTempBitmap : HBITMAP
  local paintStruct : PAINTSTRUCT ; 似乎不太需要
  
  invoke GetDC, hCanvas ; 获取 DC 
  mov hCanvasDC, eax
  invoke CreateCompatibleDC, hCanvasDC ; 和创建 Buffer
  mov hTempDC, eax

  invoke GetClientRect, hCanvas, addr tarRect ; 获取显示范围
  invoke CreateCompatibleBitmap, hCanvasDC, tarRect.right, tarRect.bottom ;创建 画布大小的 Bitmap 一定要是 hCanvasDC
  mov hTempBitmap, eax
  invoke SelectObject, hTempDC, hTempBitmap
  invoke FillRect, hTempDC, addr tarRect, hBackgroundBrush ;这个是窗口的背景
  invoke DeleteObject, hTempBrush
  invoke ReleaseDC, hCanvas, hCanvasDC

  ; 伸缩，拷贝到画布上面
  m2m cRBP.x, tarRect.right
  m2m cRBP.y, tarRect.bottom
  invoke CoordWindowToCanvas, addr cRBP ; 获得绘制范围的逻辑坐标
  ; 绘制范围不能超过画布本身的大小
  mov eax, cRBP.x
  .if eax  >= nowCanvasWidth
    m2m cRBP.x, nowCanvasWidth
  .endif
  mov eax, cRBP.y
  .if eax >= nowCanvasHeight
    m2m cRBP.y, nowCanvasHeight
  .endif
  ; 在画布上实际要画的范围，从 (nowCanvasOffsetX, nowCanvasOfffsetY) 到 cRBP(原来的
  m2m wRBP.x, cRBP.x
  m2m wRBP.y, cRBP.y
  
  invoke CoordCanvasToWindow, addr wRBP ;转换为在画布窗口上实际的逻辑坐标
  sub wRBP.x, canvasMargin
  sub wRBP.y, canvasMargin ; 刨除边缘成为宽高

  mov ecx, cRBP.x
  mov edx, cRBP.y
  sub ecx, nowCanvasOffsetX 
  sub edx, nowCanvasOffsetY ; 刨除边缘变成宽高

  ; 按照缩放比例伸缩
  invoke StretchBlt,  hTempDC,     canvasMargin,     canvasMargin, wRBP.x, wRBP.y,\
                    drawDCBuf, nowCanvasOffsetX, nowCanvasOffsetY,    ecx,    edx,\
                     SRCCOPY
  ; 拷贝
  invoke BeginPaint, hCanvas, addr paintStruct
  mov hCanvasDC, eax
  invoke BitBlt, hCanvasDC, 0, 0, tarRect.right, tarRect.bottom,\
                 hTempDC, 0, 0, \
                 SRCCOPY 
  invoke EndPaint, hCanvas, addr paintStruct
  ; 释放 / 删除创建的 DC 和 hDC 
  invoke DeleteDC, hTempDC
  invoke DeleteObject, hTempBitmap
  xor eax,eax
  ret 
RenderBitmap endp

; 画布的 proc
ProcWinCanvas proc hWnd, uMsg, wParam, lParam
  ;invoke DefWindowProc,hWnd,uMsg,wParam,lParam  ;窗口过程中不予处理的消息，传递给此函数
  ; ret
  mov eax, uMsg
  .if eax == WM_CREATE
    invoke crt_printf, CTEXT("create.")
    m2m hCanvas, hWnd
    invoke HandleCanvasCreate
  .elseif eax == WM_LBUTTONDOWN
    invoke HandleLButtonDown, wParam, lParam
;    invoke crt_printf,addr szLButtonDown
  .elseif eax == WM_LBUTTONUP
    invoke HandleLButtonUp, wParam, lParam
;    invoke crt_printf,addr szLButtonUp
  .elseif eax == WM_MOUSEMOVE
    invoke HandleMouseMove, wParam, lParam
;    invoke crt_printf,addr szMouseMoveCanvas
  .elseif eax == WM_MOUSELEAVE
    invoke HandleMouseLeave, wParam, lParam
  .elseif eax == WM_MOUSEWHEEL
    invoke HandleMouseWheel, wParam, lParam
  .elseif eax == WM_SIZE
    invoke UpdateCanvasPos
  .elseif eax == WM_PAINT
    invoke RenderBitmap
  .elseif eax == WM_ERASEBKGND
    
  .else 
    invoke DefWindowProc,hWnd,uMsg,wParam,lParam  ;窗口过程中不予处理的消息，传递给此函数
    ret ; 这个地方必须要 ret ，因为要返回 DefWindowProc 的返回值
  .endif
  xor eax,eax
  ret
ProcWinCanvas endp


; 创建画布窗口
CreateCanvasWin proc
  ;invoke MessageBox, hWinMain,addr szClassName,NULL,MB_OK
  ;创建画布窗口
  invoke CreateWindowEx,
    0,
    addr szCanvasClassName,
    NULL,
    WS_HSCROLL or WS_VSCROLL or WS_CHILD,
    0,0,400,300,
    hWinMain,
    NULL,
    hInstance,
    NULL
  mov hCanvas, eax
  invoke ShowWindow, hCanvas, SW_SHOW
  ret
CreateCanvasWin endp

DrawTextonCanvas proc 
  local hdc: HDC
  local rect: RECT
  local ps : PAINTSTRUCT
  invoke BeginPaint, hCanvas, addr ps
  mov hdc, eax
  invoke GetClientRect, hCanvas, addr rect
  invoke DrawText, hdc, CTEXT("test"), -1, addr rect , DT_SINGLELINE or DT_CENTER or DT_VCENTER
 
  invoke EndPaint, hCanvas, addr ps
  ret
DrawTextonCanvas endp

; 更新画布的位置
UpdateCanvasPos proc uses ecx edx ebx
  local mWinRect:RECT
  local StatusBarRect:RECT
  local ToolBarRect:RECT
  ; 因为 Menu 不在 ClientRect 之中，只需要考虑 Status 和 ToolBar
  
  invoke GetClientRect,hWinMain,addr mWinRect ; 相对坐标
  invoke GetWindowRect,hWinStatusBar,addr StatusBarRect ;绝对坐标
  invoke GetWindowRect,hWinToolBar ,addr ToolBarRect    ;绝对坐标
  ; 计算横向长度
  mov ecx, mWinRect.right
  sub ecx, mWinRect.left
  ; 计算纵向长度
  mov edx, StatusBarRect.top
  sub edx, ToolBarRect.bottom
  ; 排除掉工具栏
  mov ebx, ToolBarRect.bottom
  sub ebx, ToolBarRect.top

  invoke SetWindowPos,hCanvas,HWND_TOP,mWinRect.left,ebx,ecx,edx,SWP_NOREDRAW
  invoke InvalidateRect, hCanvas, NULL, FALSE ; invalidaterect 掉整个画布，让 WM_PAINT 去更新

  ret  
UpdateCanvasPos endp

SetColorInTool proc index:DWORD, color:DWORD
    ;TODO:该函数根据index(前/背景色)和color颜色
    ;     绘制工具栏上的按钮位图
    LOCAL @rect:RECT
    LOCAL @hdcW:HDC
    LOCAL @hdc:HDC
    LOCAL @hbmp:HBITMAP
    LOCAL @hbmpM:HBITMAP
    LOCAL @hbrush:HBRUSH
    LOCAL @hgraybrush:HBRUSH
 
    mov @rect.left,0
    mov @rect.right,32
    mov @rect.top,0
    mov @rect.bottom,32
    
    mov ebx,color
    .if index==0
       mov foregroundColor,ebx
    .else
       mov backgroundColor,ebx
    .endif

    invoke GetDC,hWinMain
    mov @hdcW,eax
    invoke CreateCompatibleDC,@hdcW
    mov @hdc,eax

    invoke CreateCompatibleBitmap,@hdcW,32,32
    mov @hbmp,eax
    invoke SelectObject,@hdc,@hbmp
    invoke CreateSolidBrush,color
    mov @hbrush,eax
    invoke FillRect,@hdc,addr @rect, @hbrush
    invoke DeleteObject,@hbrush
    invoke GetStockObject,GRAY_BRUSH
    mov @hgraybrush,eax
    invoke FrameRect,@hdc,addr @rect, @hgraybrush

    invoke CreateCompatibleBitmap,@hdcW,32,32
    mov @hbmpM,eax
    invoke SelectObject,@hdc,@hbmpM
    invoke GetStockObject,BLACK_BRUSH
    mov @hbrush,eax
    invoke FillRect,@hdc,addr @rect,@hbrush
   
    mov eax,index
    add eax,10
    mov index,eax

    invoke ImageList_Replace,hImageListControl,index,@hbmp,@hbmpM
    
    invoke DeleteDC,@hdc
    invoke DeleteObject,@hbmp
    invoke DeleteObject,@hbmpM
    invoke DeleteDC,@hdcW

    invoke InvalidateRect, hWinToolBar, NULL, FALSE
    ret
SetColorInTool endp

SetColor proc, index:DWORD
  ;TODO:该函数根据index设置前景色，背景色
  ;index=0,设置前景色
  ;index=1,设置背景色
  local @stcc:CHOOSECOLOR

  invoke RtlZeroMemory,addr @stcc,sizeof @stcc;用0填充stcc内存区域
  mov @stcc.lStructSize,sizeof @stcc
  push hWinMain
  pop @stcc.hwndOwner
  .if index==0
     mov eax,foregroundColor
  .elseif index==1
     mov eax,backgroundColor
  .endif
  mov @stcc.rgbResult,eax
  mov @stcc.Flags,CC_RGBINIT
  mov @stcc.lpCustColors,offset customColorBuffer
  invoke ChooseColor,addr @stcc
  invoke SetColorInTool,index,@stcc.rgbResult
  ret
SetColor endp

;主窗口 的 proc 
ProcWinMain proc uses ebx edi esi hWnd,uMsg,wParam,lParam
  local @stPos:POINT
  local @hSysMenu
  local @hBmp:HBITMAP

  mov eax,uMsg   ;消息
  .if eax==WM_CLOSE
     call Quit
  .elseif eax==WM_CREATE
     m2m hWinMain, hWnd ; 因为这个时候 WinMain 还有可能没有被移到里面去
  ;-----------------创建状态栏-------------------
     invoke  CreateStatusWindow,WS_CHILD OR WS_VISIBLE OR \
        SBS_SIZEGRIP,NULL,hWnd,ID_STATUSBAR
     mov hWinStatusBar,eax
  ;-----------------创建工具栏-------------------
     invoke CreateWindowEx, 0, addr szToolBarClassName, NULL, \
          CCS_NODIVIDER or WS_CHILD or WS_VISIBLE or WS_CLIPSIBLINGS, 0, 0, 0, 0, \
          hWnd, NULL, hInstance, NULL
     mov hWinToolBar,eax
     invoke ImageList_Create, 32, 32, ILC_COLOR32 or ILC_MASK,8, 0
     mov hImageListControl, eax
     invoke LoadBitmap,hInstance,IDB_CONTROLS
     mov @hBmp,eax
     invoke ImageList_AddMasked, hImageListControl,@hBmp, 0ffh
     invoke DeleteObject,@hBmp
     invoke SetColorInTool,0,foregroundColor        ; 黑色
     invoke SetColorInTool,1,backgroundColor        ; 白色
     invoke SendMessage, hWinToolBar, TB_SETIMAGELIST, 0, hImageListControl
     invoke SendMessage, hWinToolBar, TB_LOADIMAGES, IDB_STD_LARGE_COLOR, HINST_COMMCTRL
     invoke SendMessage, hWinToolBar, TB_BUTTONSTRUCTSIZE, sizeof TBBUTTON, 0
     invoke SendMessage, hWinToolBar, TB_ADDBUTTONS, ControlButtonNum, offset stToolBar
     invoke SendMessage, hWinToolBar, TB_AUTOSIZE, 0, 0
   ;--------------------装载光标-------------------
     invoke LoadCursor,hInstance,IDC_PEN
     mov hCurPen,eax
     invoke LoadCursor,hInstance,IDC_ERASER2
     mov hCurEraser_2,eax
     invoke LoadCursor,hInstance,IDC_ERASER4
     mov hCurEraser_4,eax
     invoke LoadCursor,hInstance,IDC_ERASER8
     mov hCurEraser_8,eax
     invoke LoadCursor,hInstance,IDC_ERASER16
     mov hCurEraser_16,eax
  ;-----------------创建画布窗口-------------------
     invoke CreateCanvasWin
	 
	 invoke ShowCursorPosition
   .elseif eax == WM_SIZE
     ;使状态栏和工具栏随缩放而缩放
     invoke SendMessage,hWinStatusBar,uMsg,wParam,lParam
     invoke SendMessage,hWinToolBar,uMsg,wParam,lParam
     ;调整画布的位置
     invoke UpdateCanvasPos
     ;invoke SendMessage,hCanvas,uMsg,wParam,lParam
  .elseif eax == WM_COMMAND
     mov eax,wParam
     movzx eax,ax
     ;菜单栏/工具栏点击铅笔/橡皮按钮，进行选中并改变光标
     .if eax >= ID_PEN && eax <= ID_ERASER
        mov ebx,eax
        push ebx
        invoke CheckMenuRadioItem,hMenu,ID_PEN,ID_ERASER,eax,MF_BYCOMMAND
        pop ebx
        mov eax,ebx
        .if eax == ID_PEN
            invoke SetClassLong,hCanvas,GCL_HCURSOR,hCurPen
         .elseif eax == ID_ERASER
            invoke GetMenuState,hMenu,ID_ERA_TWO_PIXEL,MF_BYCOMMAND
            .if eax & MF_CHECKED
               invoke SetClassLong,hCanvas,GCL_HCURSOR,hCurEraser_2
            .endif
             invoke GetMenuState,hMenu,ID_ERA_FOUR_PIXEL,MF_BYCOMMAND
            .if eax & MF_CHECKED
               invoke SetClassLong,hCanvas,GCL_HCURSOR,hCurEraser_4
            .endif
             invoke GetMenuState,hMenu,ID_ERA_EIGHT_PIXEL,MF_BYCOMMAND
            .if eax & MF_CHECKED
               invoke SetClassLong,hCanvas,GCL_HCURSOR,hCurEraser_8
            .endif
             invoke GetMenuState,hMenu,ID_ERA_SIXTEEN_PIXEL,MF_BYCOMMAND
            .if eax & MF_CHECKED
               invoke SetClassLong,hCanvas,GCL_HCURSOR,hCurEraser_16
            .endif
         .endif
     ;菜单栏改变笔/橡皮的像素大小，进行选中
     .elseif eax>=ID_ONE_PIXEL && eax<=ID_FOUR_PIXEL
         invoke CheckMenuRadioItem,hMenu,ID_ONE_PIXEL,ID_FOUR_PIXEL,eax,MF_BYCOMMAND
     .elseif eax>=ID_ERA_TWO_PIXEL && eax<=ID_ERA_SIXTEEN_PIXEL
         mov ebx,eax
         push ebx
         invoke CheckMenuRadioItem,hMenu,ID_ERA_TWO_PIXEL,ID_ERA_SIXTEEN_PIXEL,eax,MF_BYCOMMAND
         pop ebx
         mov eax,ebx
         .if eax==ID_ERA_TWO_PIXEL
            invoke SetClassLong,hCanvas,GCL_HCURSOR,hCurEraser_2
         .elseif eax==ID_ERA_FOUR_PIXEL
            invoke SetClassLong,hCanvas,GCL_HCURSOR,hCurEraser_4
         .elseif eax==ID_ERA_EIGHT_PIXEL
            invoke SetClassLong,hCanvas,GCL_HCURSOR,hCurEraser_8
         .elseif eax==ID_ERA_SIXTEEN_PIXEL
            invoke SetClassLong,hCanvas,GCL_HCURSOR,hCurEraser_16
         .endif
     ;菜单栏退出功能
     .elseif eax == ID_FOR_COLOR
         invoke SetColor,0
     .elseif eax == ID_BACK_COLOR
         invoke SetColor,1
     .elseif eax ==ID_QUIT
         call Quit
     .endif  
  .elseif eax == WM_MOUSEMOVE
    call Quit
    pushad
	 invoke ShowCursorPosition
	 popad
  .else
     invoke DefWindowProc,hWnd,uMsg,wParam,lParam  ;窗口过程中不予处理的消息，传递给此函数 
     ret
  .endif 
  xor eax,eax
  ret
ProcWinMain endp

WinMain proc 
  local @stWndClass:WNDCLASSEX
  local @canvasWndClass:WNDCLASSEX
  local @stMsg:MSG
  local @hAccelerator

  invoke GetModuleHandle,NULL                      ;获取本模块句柄
  mov hInstance,eax
  invoke LoadMenu,hInstance,IDR_MENU1              ;装载主菜单，模块句柄，欲载入菜单的ID
  mov hMenu,eax
  invoke LoadAccelerators,hInstance,IDR_MENU1      ;装载加速键
  mov @hAccelerator,eax

  ; 注册主窗口类
  invoke RtlZeroMemory,addr @stWndClass,sizeof @stWndClass ;内存清零
  invoke LoadIcon,hInstance,IDI_ICON1              ;装载图标句柄
  mov @stWndClass.hIcon,eax                       
  mov @stWndClass.hIconSm,eax                      ;小图标
  invoke LoadCursor,0,IDC_ARROW                    ;获取光标句柄
  mov @stWndClass.hCursor,eax
  push hInstance
  pop @stWndClass.hInstance                        ;当前程序的句柄
  mov @stWndClass.cbSize,sizeof WNDCLASSEX         ;结构体的大小
  mov @stWndClass.style,CS_HREDRAW or CS_VREDRAW   ;窗口风格：当移动或尺寸调整改变了客户区域的宽度/高度，则重绘整个窗口
  mov @stWndClass.lpfnWndProc,offset ProcWinMain   ;窗口过程的地址
  mov @stWndClass.hbrBackground,COLOR_WINDOW + 1   ;背景色
  mov @stWndClass.lpszClassName,offset szWindowClassName ;类名称的地址
  invoke RegisterClassEx,addr @stWndClass          ;注册窗口
  
  ; 注册画布窗口类 
  invoke RtlZeroMemory,addr @canvasWndClass,sizeof @canvasWndClass ;内存清零
  invoke LoadCursor,0,IDC_ARROW                    ;获取光标句柄
  mov @canvasWndClass.hCursor, eax
  m2m @canvasWndClass.hInstance, hInstance
  mov @canvasWndClass.cbSize, sizeof WNDCLASSEX
  mov @canvasWndClass.style, CS_HREDRAW or CS_VREDRAW
  mov @canvasWndClass.lpfnWndProc, offset ProcWinCanvas
  invoke CreateSolidBrush, 0abababh
  mov hBackgroundBrush,eax
  mov @canvasWndClass.hbrBackground, eax
  mov @canvasWndClass.lpszClassName, offset szCanvasClassName
  invoke RegisterClassEx, addr @canvasWndClass


  ;注意：不要把下面函数调用的注释缩进改到与上下一致，否则将报错：line too long
  invoke CreateWindowEx, ;建立窗口
    WS_EX_CLIENTEDGE, ;扩展窗口风格
    offset szWindowClassName,;指向类名字符串的指针
    offset szMainWindowTitle, ;指向窗口名称字符串的指针
    WS_OVERLAPPEDWINDOW,;窗口风格
    100,100,800,600,    ;x,y,窗口宽度,窗口高度
    NULL,  ;窗口所属的父窗口
    hMenu, ;窗口上将要出现的菜单的句柄
    hInstance, ;模块句柄
    NULL  ;指向一个欲传给窗口的参数的指针
  mov hWinMain,eax                                 ;返回窗口的句柄（理论上前面做过了
  invoke ShowWindow,hWinMain,SW_SHOWNORMAL         ;激活并显示窗口
  invoke UpdateWindow,hWinMain                     ;刷新窗口客户区

  invoke  InitCommonControls                       ;初始化，保证系统加载comct32.dll库文件
  .while TRUE
     invoke GetMessage,                            ;从消息队列取消息
               addr @stMsg,                        ;消息结构的地址
               NULL,                               ;取本程序所属窗口的信息
               0,                                  ;获取所有编号的信息
               0                                   ;获取所有编号的信息

     .break .if eax==0                             ;没有消息，则退出
     invoke TranslateAccelerator,                  ;实现加速键功能
               hWinMain,                           ;窗口句柄
               @hAccelerator,                      ;加速键句柄
               addr @stMsg                         ;消息结构的地址
     .if eax==0
        invoke TranslateMessage,addr @stMsg        ;传送消息
        invoke DispatchMessage,addr @stMsg         ;不同消息窗口消息分配给不同的窗口过程
     .endif
  .endw
  ret
WinMain endp

start:
  call WinMain
  invoke ExitProcess,NULL
end start