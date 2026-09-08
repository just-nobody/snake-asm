; ==============================================================================
;  SNAKE NEW - x86 Flat Assembler (FASM) Windows
;  Difficulty is picked right inside the playfield; the field grows as you score
;  Based on snake.asm
; ==============================================================================

format PE GUI 4.0
entry start

include 'win32ax.inc'

; ------------------------------------------------------------------------------
;  Constants
; ------------------------------------------------------------------------------
CELL_SIZE           equ 20
START_GRID          equ 10          ; starting field is 10x10
GROW_STEP           equ 2           ; field grows by one cell on every side
LIMIT_GRID          equ 50          ; field never grows past this
MAX_SNAKE           equ 10000

TIMER_ID            equ 1
TIMER_INTERVAL      equ 125
DIR_QUEUE_SIZE      equ 8

STATE_MENU          equ 0
STATE_RUNNING       equ 1
STATE_PAUSED        equ 2
STATE_GAMEOVER      equ 3
STATE_INPUT_NAME    equ 4

DIR_UP              equ 0
DIR_RIGHT           equ 1
DIR_DOWN            equ 2
DIR_LEFT            equ 3

MENU_COUNT          equ 4
MAX_TOP             equ 10
NAME_LEN            equ 16
FILE_BUF_SIZE       equ 4096

; Win32 constants
CS_HREDRAW          equ 0002h
CS_VREDRAW          equ 0001h
IDC_ARROW           equ 32512

WS_POPUP            equ 80000000h
WS_VISIBLE          equ 10000000h
WS_EX_APPWINDOW     equ 00040000h
WINDOW_STYLE        equ WS_POPUP or WS_VISIBLE

WM_CREATE           equ 0001h
WM_DESTROY          equ 0002h
WM_PAINT            equ 000Fh
WM_ERASEBKGND       equ 0014h
WM_KEYDOWN          equ 0100h
WM_SYSKEYDOWN       equ 0104h
WM_CHAR             equ 0102h
WM_TIMER            equ 0113h
WM_SETICON          equ 0080h
WM_LBUTTONDOWN      equ 0201h
WM_NCLBUTTONDOWN    equ 00A1h
HTCAPTION           equ 2

VK_BACK             equ 08h
VK_RETURN           equ 0Dh
VK_ESCAPE           equ 1Bh
VK_SPACE            equ 20h
VK_LEFT             equ 25h
VK_UP               equ 26h
VK_RIGHT            equ 27h
VK_DOWN             equ 28h

SRCCOPY             equ 00CC0020h
TRANSPARENT         equ 1
PS_SOLID            equ 0
NULL_PEN            equ 8

DT_CENTER           equ 00000001h
DT_VCENTER          equ 00000004h
DT_SINGLELINE       equ 00000020h
DT_LEFT             equ 00000000h

SM_CXSCREEN         equ 0
SM_CYSCREEN         equ 1

section '.data' data readable writeable
; ------------------------------------------------------------------------------
;  Initialised data (goes into the .exe file)
; ------------------------------------------------------------------------------
szClassName         db 'SnakeNewWndClass', 0
szTitle             db 'Snake New', 0
szTitleMenu         db 'Snake New', 0
szTitleGameFmt      db 'Snake New - %dx%d', 0
szFontFaceArial     db 'Arial', 0
szFontFaceConsolas  db 'Consolas', 0

szTopFileName       db 'snakenew.top', 0
szTopRowFileFmt     db '%d %s', 13, 10, 0

szNumFmt            db '%d', 0
szScoreFmt          db 'Score: %d', 0
szFieldFmt          db 'Field: %dx%d', 0
szTopLineFmt        db '%2d. %-12s %6d', 0
szTopTitle          db 'TOP 10', 0
szNoRecords         db '- empty -', 0

; ------------------------------------------------------------------------------
;  DIFFICULTY TABLE - everything is tuned here and nowhere else
;
;  diff_start_len - starting snake length. Every level starts with just the head.
;  diff_grow      - tail segments gained per apple:
;                   EASY +1, NORMAL +2, HARD +3, ULTRA +4.
;                   Score follows the same number: 10 points per new segment,
;                   i.e. +10 / +20 / +30 / +40 per apple.
;
;  Field growth rule, the same for every level:
;                   on an NxN field you must eat N apples, then the field grows
;                   by one cell on every side and becomes (N+2)x(N+2).
;                   So 10x10 -> 10 apples, 12x12 -> 12, 14x14 -> 14 and so on.
; ------------------------------------------------------------------------------
menu_item_0         db 'EASY', 0
menu_item_1         db 'NORMAL', 0
menu_item_2         db 'HARD', 0
menu_item_3         db 'ULTRA', 0
menu_table          dd menu_item_0, menu_item_1, menu_item_2, menu_item_3
diff_start_len      dd 1,  1,  1,  1
diff_grow           dd 1,  2,  3,  4

szGameOverTitle     db 'GAME OVER!', 0

szPauseTitle        db 'PAUSED', 0
szPauseHint         db '[Space] resume', 0

szInputTitle        db 'NEW RECORD!', 0
szInputBoxFmt       db '%s%s', 0
szCursorChar        db '_', 0
szEmptyChar         db 0

hInstance           dd 0
hWnd                dd 0

winX                dd 0
winY                dd 0
window_width        dd 200
window_height       dd 200

; Game state
snake_len           dd 1
curr_dir            dd DIR_RIGHT
next_dir            dd DIR_RIGHT
score               dd 0
game_state          dd STATE_MENU
rand_seed           dd 0
grid_size           dd START_GRID
max_grid_size       dd LIMIT_GRID
board_pixels        dd 200
food_x              dd 3
food_y              dd 3
temp_food_x         dd 0
temp_food_y         dd 0
dir_queue_count     dd 0
sound_enabled       dd 1
menu_sel            dd 1            ; NORMAL is selected by default
final_grid          dd START_GRID
apples_level        dd 0            ; apples eaten on the current field size

; Name entry
input_len           dd 0
cursor_tick         dd 0
highlight_rank      dd -1

top_count           dd 0
dwBytesRead         dd 0
dwBytesWritten      dd 0
hTopFile            dd 0

; GDI objects
hBrushBack          dd 0
hBrushBoard         dd 0
hBrushBorder        dd 0
hBrushSnakeHead     dd 0
hBrushSnakeBody     dd 0
hBrushSnakeInner    dd 0
hPenSnakeBorder     dd 0
hBrushApple         dd 0
hPenApple           dd 0
hBrushAppleShine    dd 0
hBrushLeaf          dd 0
hBrushEye           dd 0
hBrushPupil         dd 0
hBrushPanel         dd 0
hBrushSelected      dd 0
hBrushOverlayBox    dd 0
hBrushPauseBox      dd 0
hBrushInputBox      dd 0
hPenGrid            dd 0
hPenDivider         dd 0
hNullPen            dd 0

hFontWatermark      dd 0
hFontTitle          dd 0
hFontMenu           dd 0
hFontTable          dd 0
hFontSub            dd 0
hFontInput          dd 0

; ------------------------------------------------------------------------------
;  Reserved buffers (not written into the .exe file)
; ------------------------------------------------------------------------------
szTitleBuf          rb 64
szTopFilePath       rb MAX_PATH
szTextBuf           rb 128
szTextBuf2          rb 128

snake_x             rd MAX_SNAKE
snake_y             rd MAX_SNAKE

input_name          rb NAME_LEN
top_scores          rd MAX_TOP
top_names           rb MAX_TOP * NAME_LEN
dir_queue           rd DIR_QUEUE_SIZE

szFileReadBuf       rb FILE_BUF_SIZE

wc                  WNDCLASSEX
msg                 MSG
ps                  PAINTSTRUCT
rcWin               RECT
rcBoard             RECT
rcBanner            RECT
rcText              RECT
rcInputBox          RECT

section '.code' code readable executable
; ==============================================================================
;  Entry point
; ==============================================================================
start:
    invoke GetModuleHandle, 0
    mov [hInstance], eax

    call init_top_path
    call init_grid_limits
    call load_top10

    mov [game_state], STATE_MENU
    mov [grid_size], START_GRID
    mov eax, [grid_size]
    imul eax, CELL_SIZE
    mov [board_pixels], eax
    mov [window_width], eax
    mov [window_height], eax

    mov [wc.cbSize], sizeof.WNDCLASSEX
    mov [wc.style], CS_HREDRAW or CS_VREDRAW
    mov [wc.lpfnWndProc], WndProc
    mov [wc.cbClsExtra], 0
    mov [wc.cbWndExtra], 0
    mov eax, [hInstance]
    mov [wc.hInstance], eax
    invoke LoadIcon, [hInstance], 1
    mov [wc.hIcon], eax
    mov [wc.hIconSm], eax
    invoke LoadCursor, 0, IDC_ARROW
    mov [wc.hCursor], eax
    mov [wc.hbrBackground], 0
    mov [wc.lpszMenuName], 0
    mov [wc.lpszClassName], szClassName

    invoke RegisterClassEx, wc
    test eax, eax
    jz .exit_app

    call calc_window_pos
    invoke CreateWindowEx, WS_EX_APPWINDOW, szClassName, szTitle, WINDOW_STYLE, [winX], [winY], [window_width], [window_height], 0, 0, [hInstance], 0
    mov [hWnd], eax
    test eax, eax
    jz .exit_app

    invoke LoadIcon, [hInstance], 1
    invoke SendMessage, [hWnd], WM_SETICON, 1, eax
    invoke SendMessage, [hWnd], WM_SETICON, 0, eax

    invoke ShowWindow, [hWnd], SW_SHOWNORMAL
    invoke UpdateWindow, [hWnd]
    invoke SetForegroundWindow, [hWnd]
    invoke SetActiveWindow, [hWnd]

.msg_loop:
    invoke GetMessage, msg, 0, 0, 0
    cmp eax, 0
    jle .exit_app
    invoke TranslateMessage, msg
    invoke DispatchMessage, msg
    jmp .msg_loop

.exit_app:
    invoke ExitProcess, [msg.wParam]

; ==============================================================================
;  Path to snakenew.top next to the .exe
; ==============================================================================
init_top_path:
    invoke GetModuleFileName, 0, szTopFilePath, MAX_PATH
    invoke lstrlen, szTopFilePath
    mov ecx, eax
.find_slash:
    cmp ecx, 0
    jle .append_name
    mov al, [szTopFilePath + ecx - 1]
    cmp al, '\'
    je .found_slash
    cmp al, '/'
    je .found_slash
    dec ecx
    jmp .find_slash
.found_slash:
    mov byte [szTopFilePath + ecx], 0
.append_name:
    invoke lstrcat, szTopFilePath, szTopFileName
    ret

; Largest field that still fits on screen (but never more than LIMIT_GRID)
init_grid_limits:
    invoke GetSystemMetrics, SM_CYSCREEN
    sub eax, 40
    xor edx, edx
    mov ecx, CELL_SIZE
    div ecx
    and eax, not 1              ; size steps by 2, so keep it even
    cmp eax, LIMIT_GRID
    jle .store
    mov eax, LIMIT_GRID
.store:
    cmp eax, START_GRID
    jge .ok
    mov eax, START_GRID
.ok:
    mov [max_grid_size], eax
    ret

; ==============================================================================
;  Window size and position
; ==============================================================================
calc_window_pos:
    invoke GetSystemMetrics, SM_CXSCREEN
    sub eax, [window_width]
    sar eax, 1
    jns .x_ok
    xor eax, eax
.x_ok:
    mov [winX], eax
    invoke GetSystemMetrics, SM_CYSCREEN
    sub eax, [window_height]
    sar eax, 1
    jns .y_ok
    xor eax, eax
.y_ok:
    mov [winY], eax
    ret

; The window is the playfield itself; centre it on screen
size_board_window:
    mov eax, [grid_size]
    imul eax, CELL_SIZE
    mov [board_pixels], eax
    mov [window_width], eax
    mov [window_height], eax
    call update_watermark_font
    call calc_window_pos
    mov eax, [window_width]
    invoke MoveWindow, [hWnd], [winX], [winY], eax, eax, TRUE
    ret

; The field grows by one cell on all four sides (size +2).
; Every object shifts by one cell while the window grows by CELL_SIZE on each
; side, so the snake and the apple stay exactly where they were on screen.
grow_board:
    add [grid_size], GROW_STEP

    xor ecx, ecx
.shift_loop:
    cmp ecx, [snake_len]
    jge .shift_done
    inc dword [snake_x + ecx*4]
    inc dword [snake_y + ecx*4]
    inc ecx
    jmp .shift_loop
.shift_done:
    inc [food_x]
    inc [food_y]

    ; new window size, keeping the field in the same spot on screen
    invoke GetWindowRect, [hWnd], rcWin
    mov eax, [rcWin.left]
    sub eax, CELL_SIZE
    jns .x_ok
    xor eax, eax
.x_ok:
    mov [winX], eax
    mov eax, [rcWin.top]
    sub eax, CELL_SIZE
    jns .y_ok
    xor eax, eax
.y_ok:
    mov [winY], eax

    mov eax, [grid_size]
    imul eax, CELL_SIZE
    mov [board_pixels], eax
    mov [window_width], eax
    mov [window_height], eax
    call update_watermark_font
    mov eax, [window_width]
    invoke MoveWindow, [hWnd], [winX], [winY], eax, eax, TRUE
    call update_game_title
    ret

update_watermark_font:
    cmp [hFontWatermark], 0
    je .create
    invoke DeleteObject, [hFontWatermark]
.create:
    mov eax, [board_pixels]
    shr eax, 1
    invoke CreateFont, eax, 0, 0, 0, 900, 0, 0, 0, 0, 0, 0, 0, 0, szFontFaceArial
    mov [hFontWatermark], eax
    ret

update_game_title:
    cinvoke wsprintf, szTitleBuf, szTitleGameFmt, [grid_size], [grid_size]
    invoke SetWindowText, [hWnd], szTitleBuf
    ret

; ==============================================================================
;  TOP 10 - one shared list stored in snakenew.top
; ==============================================================================
init_empty_top10:
    push edi
    xor eax, eax
    mov [top_count], eax
    mov ecx, MAX_TOP
.clear_scores:
    mov [top_scores + ecx*4 - 4], eax
    loop .clear_scores
    lea edi, [top_names]
    mov ecx, MAX_TOP * NAME_LEN
    rep stosb
    pop edi
    ret

load_top10:
    push ebx
    push esi
    push edi

    call init_empty_top10

    invoke CreateFile, szTopFilePath, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
    cmp eax, -1
    je .load_done
    mov [hTopFile], eax
    mov [dwBytesRead], 0
    invoke ReadFile, [hTopFile], szFileReadBuf, FILE_BUF_SIZE - 8, dwBytesRead, 0
    invoke CloseHandle, [hTopFile]

    mov ecx, [dwBytesRead]
    mov byte [szFileReadBuf + ecx], 0

    lea esi, [szFileReadBuf]
    xor ebx, ebx

.line_start:
    cmp ebx, MAX_TOP
    jge .load_done
.skip_ws:
    mov al, [esi]
    test al, al
    jz .load_done
    cmp al, ' '
    je .inc_ws
    cmp al, 9
    je .inc_ws
    cmp al, 13
    je .inc_ws
    cmp al, 10
    je .inc_ws
    jmp .parse_score
.inc_ws:
    inc esi
    jmp .skip_ws

.parse_score:
    xor edx, edx
    xor edi, edi                ; did we see any digits?
.score_loop:
    mov al, [esi]
    cmp al, '0'
    jl .score_done
    cmp al, '9'
    jg .score_done
    sub al, '0'
    movzx eax, al
    imul edx, 10
    add edx, eax
    mov edi, 1
    inc esi
    jmp .score_loop
.score_done:
    test edi, edi
    jnz .have_score

    ; line without a number - skip it
.drop_line:
    mov al, [esi]
    test al, al
    jz .load_done
    cmp al, 13
    je .line_start
    cmp al, 10
    je .line_start
    inc esi
    jmp .drop_line

.have_score:
    mov [top_scores + ebx*4], edx

.skip_sp:
    mov al, [esi]
    cmp al, ' '
    je .inc_sp
    cmp al, 9
    je .inc_sp
    jmp .read_name
.inc_sp:
    inc esi
    jmp .skip_sp

.read_name:
    mov eax, ebx
    shl eax, 4
    lea edi, [top_names + eax]
    xor ecx, ecx
.name_loop:
    mov al, [esi]
    test al, al
    jz .name_end
    cmp al, 13
    je .name_end
    cmp al, 10
    je .name_end
    cmp ecx, NAME_LEN - 1
    jge .skip_extra
    mov [edi + ecx], al
    inc ecx
.skip_extra:
    inc esi
    jmp .name_loop
.name_end:
    mov byte [edi + ecx], 0
    inc ebx
    mov [top_count], ebx
    jmp .line_start

.load_done:
    pop edi
    pop esi
    pop ebx
    ret

save_top10:
    push ebx
    push esi

    invoke CreateFile, szTopFilePath, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
    cmp eax, -1
    je .save_err
    mov [hTopFile], eax

    xor ebx, ebx
.save_loop:
    cmp ebx, [top_count]
    jge .save_close
    cmp dword [top_scores + ebx*4], 0
    jle .save_next
    mov eax, ebx
    shl eax, 4
    lea esi, [top_names + eax]
    cinvoke wsprintf, szTextBuf, szTopRowFileFmt, [top_scores + ebx*4], esi
    invoke lstrlen, szTextBuf
    invoke WriteFile, [hTopFile], szTextBuf, eax, dwBytesWritten, 0
.save_next:
    inc ebx
    jmp .save_loop

.save_close:
    invoke CloseHandle, [hTopFile]
.save_err:
    pop esi
    pop ebx
    ret

; Does this score make the top ten?  eax = 1 yes, 0 no
is_record:
    cmp [score], 0
    jle .no
    cmp [top_count], MAX_TOP
    jl .yes
    mov eax, [score]
    cmp eax, [top_scores + (MAX_TOP - 1) * 4]
    jg .yes
.no:
    xor eax, eax
    ret
.yes:
    mov eax, 1
    ret

; ==============================================================================
;  Random numbers and food
; ==============================================================================
rand:
    mov eax, [rand_seed]
    imul eax, 1103515245
    add eax, 12345
    mov [rand_seed], eax
    shr eax, 16
    and eax, 07FFFh
    ret

spawn_food:
.retry:
    call rand
    xor edx, edx
    mov ecx, [grid_size]
    div ecx
    mov [temp_food_x], edx

    call rand
    xor edx, edx
    mov ecx, [grid_size]
    div ecx
    mov [temp_food_y], edx

    xor ecx, ecx
.check_overlap:
    cmp ecx, [snake_len]
    jge .found_pos
    mov eax, [temp_food_x]
    cmp eax, [snake_x + ecx*4]
    jne .next_seg
    mov eax, [temp_food_y]
    cmp eax, [snake_y + ecx*4]
    je .retry
.next_seg:
    inc ecx
    jmp .check_overlap
.found_pos:
    mov eax, [temp_food_x]
    mov [food_x], eax
    mov eax, [temp_food_y]
    mov [food_y], eax
    ret

; ==============================================================================
;  New game using the selected difficulty
;  The tail is laid out backwards from the head: to the left, and on reaching
;  the edge one row down and back to the right, so that even a long starting
;  snake fits on the smallest field
; ==============================================================================
reset_game:
    push ebx
    push esi

    mov [grid_size], START_GRID
    mov [final_grid], START_GRID

    mov ebx, [menu_sel]
    mov eax, [diff_start_len + ebx*4]
    mov [snake_len], eax

    ; head in the middle of the field
    mov eax, [grid_size]
    shr eax, 1
    mov [snake_x], eax
    mov [snake_y], eax

    mov edx, eax                ; edx = current x
    mov ebx, eax                ; ebx = current row
    mov esi, -1                 ; horizontal step
    mov ecx, 1
.tail_loop:
    cmp ecx, [snake_len]
    jge .tail_done
    mov eax, edx
    add eax, esi
    cmp eax, 0
    jl .tail_wrap
    cmp eax, [grid_size]
    jge .tail_wrap
    mov edx, eax
    jmp .tail_store
.tail_wrap:
    inc ebx
    cmp ebx, [grid_size]
    jge .tail_cut
    neg esi
.tail_store:
    mov [snake_x + ecx*4], edx
    mov [snake_y + ecx*4], ebx
    inc ecx
    jmp .tail_loop
.tail_cut:
    mov [snake_len], ecx        ; field too small - shorten the snake
.tail_done:

    mov [curr_dir], DIR_RIGHT
    mov [next_dir], DIR_RIGHT
    mov [dir_queue_count], 0
    mov [score], 0
    mov [apples_level], 0
    mov [highlight_rank], -1

    call spawn_food

    pop esi
    pop ebx
    ret

start_game:
    call reset_game
    mov eax, [grid_size]
    imul eax, CELL_SIZE
    mov [board_pixels], eax
    mov [window_width], eax
    mov [window_height], eax
    call update_watermark_font
    call update_game_title
    mov [game_state], STATE_RUNNING
    ret

back_to_menu:
    mov [game_state], STATE_MENU
    call reset_game
    call size_board_window
    invoke SetWindowText, [hWnd], szTitleMenu
    ret

; ==============================================================================
;  Game tick
; ==============================================================================
game_tick:
    push ebx
    push esi
    push edi

    cmp [game_state], STATE_RUNNING
    jne .tick_end

    cmp [dir_queue_count], 0
    je .use_current_dir
    mov eax, [dir_queue]
    mov ecx, [dir_queue_count]
    dec ecx
    jz .queue_one_done
.shift_dir_queue:
    mov edx, [dir_queue + ecx*4]
    mov [dir_queue + ecx*4 - 4], edx
    dec ecx
    jnz .shift_dir_queue
.queue_one_done:
    dec [dir_queue_count]
    mov [next_dir], eax
.use_current_dir:
    mov eax, [next_dir]
    mov [curr_dir], eax

    mov edx, [snake_x]
    mov ebx, [snake_y]

    mov eax, [curr_dir]
    cmp eax, DIR_UP
    jne .chk_down
    dec ebx
    jmp .got_pos
.chk_down:
    cmp eax, DIR_DOWN
    jne .chk_left
    inc ebx
    jmp .got_pos
.chk_left:
    cmp eax, DIR_LEFT
    jne .chk_right
    dec edx
    jmp .got_pos
.chk_right:
    inc edx

.got_pos:
    ; walls
    cmp edx, 0
    jl .die
    cmp edx, [grid_size]
    jge .die
    cmp ebx, 0
    jl .die
    cmp ebx, [grid_size]
    jge .die

    ; food
    xor esi, esi
    cmp edx, [food_x]
    jne .not_food
    cmp ebx, [food_y]
    jne .not_food
    mov esi, 1
.not_food:

    ; own body
    mov edi, [snake_len]
    test esi, esi
    jnz .check_body
    dec edi
.check_body:
    xor ecx, ecx
.body_loop:
    cmp ecx, edi
    jge .body_ok
    cmp edx, [snake_x + ecx*4]
    jne .seg_diff
    cmp ebx, [snake_y + ecx*4]
    je .die
.seg_diff:
    inc ecx
    jmp .body_loop

.body_ok:
    test esi, esi
    jz .normal_move

    ; --- apple eaten ---
    inc [apples_level]

    mov edi, [menu_sel]
    mov edi, [diff_grow + edi*4]        ; segments gained

    ; score follows the growth: 10 points per new tail segment
    ; (EASY +10, NORMAL +20, HARD +30, ULTRA +40 per apple)
    mov eax, edi
    imul eax, 10
    add [score], eax

    ; the tail grows by diff_grow segments (stacked onto the tail end)
.grow_tail_loop:
    test edi, edi
    jle .shift_ate
    mov ecx, [snake_len]
    cmp ecx, MAX_SNAKE
    jge .shift_ate
    mov eax, [snake_x + ecx*4 - 4]
    mov [snake_x + ecx*4], eax
    mov eax, [snake_y + ecx*4 - 4]
    mov [snake_y + ecx*4], eax
    inc [snake_len]
    dec edi
    jmp .grow_tail_loop

.shift_ate:
    mov ecx, [snake_len]
    dec ecx
.shift_ate_loop:
    cmp ecx, 0
    jle .shift_ate_done
    mov eax, [snake_x + ecx*4 - 4]
    mov [snake_x + ecx*4], eax
    mov eax, [snake_y + ecx*4 - 4]
    mov [snake_y + ecx*4], eax
    dec ecx
    jmp .shift_ate_loop
.shift_ate_done:
    mov [snake_x], edx
    mov [snake_y], ebx

    call spawn_food
    cmp [sound_enabled], 0
    je .check_grow
    invoke Beep, 880, 20

    ; --- time to grow the field?  an NxN field needs N apples ---
    ; (10x10 -> 10, 12x12 -> 12, 14x14 -> 14 ...)
.check_grow:
    mov eax, [grid_size]
    cmp eax, [max_grid_size]
    jge .no_grow
    cmp [apples_level], eax
    jl .no_grow

    call grow_board
    mov [apples_level], 0
    mov eax, [grid_size]
    mov [final_grid], eax
    cmp [sound_enabled], 0
    je .no_grow
    invoke Beep, 523, 60
    invoke Beep, 784, 90
.no_grow:
    jmp .tick_end

.normal_move:
    mov ecx, [snake_len]
    dec ecx
.move_loop:
    cmp ecx, 0
    jle .move_done
    mov eax, [snake_x + ecx*4 - 4]
    mov [snake_x + ecx*4], eax
    mov eax, [snake_y + ecx*4 - 4]
    mov [snake_y + ecx*4], eax
    dec ecx
    jmp .move_loop
.move_done:
    mov [snake_x], edx
    mov [snake_y], ebx
    jmp .tick_end

.die:
    mov eax, [grid_size]
    mov [final_grid], eax

    call is_record
    test eax, eax
    jz .plain_over

    mov [game_state], STATE_INPUT_NAME
    mov [input_len], 0
    mov byte [input_name], 0
    cmp [sound_enabled], 0
    je .tick_end
    invoke Beep, 587, 80
    invoke Beep, 880, 150
    jmp .tick_end

.plain_over:
    mov [game_state], STATE_GAMEOVER
    cmp [sound_enabled], 0
    je .tick_end
    invoke Beep, 220, 160

.tick_end:
    pop edi
    pop esi
    pop ebx
    ret

queue_direction:
    push ebx
    push ecx
    push edx
    mov ebx, [dir_queue_count]
    cmp ebx, DIR_QUEUE_SIZE
    jge .qd_done
    mov edx, [curr_dir]
    test ebx, ebx
    jz .qd_check
    mov ecx, ebx
    dec ecx
    mov edx, [dir_queue + ecx*4]
.qd_check:
    cmp eax, edx
    je .qd_done
    ; a one-cell snake (EASY start) is allowed to turn back on itself
    cmp [snake_len], 1
    jle .qd_store
    cmp edx, DIR_UP
    jne .qd_not_up
    cmp eax, DIR_DOWN
    je .qd_done
    jmp .qd_store
.qd_not_up:
    cmp edx, DIR_DOWN
    jne .qd_not_down
    cmp eax, DIR_UP
    je .qd_done
    jmp .qd_store
.qd_not_down:
    cmp edx, DIR_LEFT
    jne .qd_not_left
    cmp eax, DIR_RIGHT
    je .qd_done
    jmp .qd_store
.qd_not_left:
    cmp edx, DIR_RIGHT
    jne .qd_store
    cmp eax, DIR_LEFT
    je .qd_done
.qd_store:
    mov [dir_queue + ebx*4], eax
    inc [dir_queue_count]
.qd_done:
    pop edx
    pop ecx
    pop ebx
    ret

; ==============================================================================
;  Filled circle helper
; ==============================================================================
proc DrawDot uses ebx, hdc, cx, cy, rad
    local l:DWORD, t:DWORD, r:DWORD, b:DWORD
    mov eax, [cx]
    sub eax, [rad]
    mov [l], eax
    mov eax, [cy]
    sub eax, [rad]
    mov [t], eax
    mov eax, [cx]
    add eax, [rad]
    mov [r], eax
    mov eax, [cy]
    add eax, [rad]
    mov [b], eax
    invoke Ellipse, [hdc], [l], [t], [r], [b]
    ret
endp

; ==============================================================================
;  Window procedure
; ==============================================================================
proc WndProc uses ebx esi edi, hwnd, uMsg, wParam, lParam
    local hdc:DWORD, memdc:DWORD, membmp:DWORD, oldbmp:DWORD
    local oldFont:DWORD, oldPen:DWORD
    local iSeg:DWORD, segX:DWORD, segY:DWORD
    local x1:DWORD, y1:DWORD, x2:DWORD, y2:DWORD

    mov eax, [uMsg]
    cmp eax, WM_TIMER
    je .wm_timer
    cmp eax, WM_KEYDOWN
    je .wm_keydown
    cmp eax, WM_SYSKEYDOWN
    je .wm_keydown
    cmp eax, WM_CHAR
    je .wm_char
    cmp eax, WM_LBUTTONDOWN
    je .wm_lbuttondown
    cmp eax, WM_PAINT
    je .wm_paint
    cmp eax, WM_ERASEBKGND
    je .wm_erasebkgnd
    cmp eax, WM_CREATE
    je .wm_create
    cmp eax, WM_DESTROY
    je .wm_destroy

    invoke DefWindowProc, [hwnd], [uMsg], [wParam], [lParam]
    ret

.wm_lbuttondown:
    invoke ReleaseCapture
    invoke SendMessage, [hwnd], WM_NCLBUTTONDOWN, HTCAPTION, 0
    xor eax, eax
    ret

; ------------------------------------------------------------------------------
;  WM_CREATE
; ------------------------------------------------------------------------------
.wm_create:
    invoke GetTickCount
    mov [rand_seed], eax

    invoke CreateSolidBrush, 0x00070A07
    mov [hBrushBack], eax
    invoke CreateSolidBrush, 0x000F140E
    mov [hBrushBoard], eax
    invoke CreateSolidBrush, 0x00264026
    mov [hBrushBorder], eax

    invoke CreateSolidBrush, 0x003DE641
    mov [hBrushSnakeHead], eax
    invoke CreateSolidBrush, 0x0028B432
    mov [hBrushSnakeBody], eax
    invoke CreateSolidBrush, 0x0045D64E
    mov [hBrushSnakeInner], eax
    invoke CreatePen, PS_SOLID, 1, 0x001B6420
    mov [hPenSnakeBorder], eax

    invoke CreateSolidBrush, 0x002828EB
    mov [hBrushApple], eax
    invoke CreatePen, PS_SOLID, 1, 0x001515B4
    mov [hPenApple], eax
    invoke CreateSolidBrush, 0x008080FF
    mov [hBrushAppleShine], eax
    invoke CreateSolidBrush, 0x0032C850
    mov [hBrushLeaf], eax

    invoke CreateSolidBrush, 0x000A0A0A
    mov [hBrushEye], eax
    invoke CreateSolidBrush, 0x00FFFFFF
    mov [hBrushPupil], eax

    invoke CreateSolidBrush, 0x000D120D
    mov [hBrushPanel], eax
    invoke CreateSolidBrush, 0x001E3320
    mov [hBrushSelected], eax
    invoke CreateSolidBrush, 0x00151224
    mov [hBrushOverlayBox], eax
    invoke CreateSolidBrush, 0x00151E28
    mov [hBrushPauseBox], eax
    invoke CreateSolidBrush, 0x000B100C
    mov [hBrushInputBox], eax

    invoke CreatePen, PS_SOLID, 1, 0x00151C15
    mov [hPenGrid], eax
    invoke CreatePen, PS_SOLID, 1, 0x00264026
    mov [hPenDivider], eax
    invoke GetStockObject, NULL_PEN
    mov [hNullPen], eax

    invoke CreateFont, 26, 0, 0, 0, 800, 0, 0, 0, 0, 0, 0, 0, 0, szFontFaceArial
    mov [hFontTitle], eax
    invoke CreateFont, 22, 0, 0, 0, 700, 0, 0, 0, 0, 0, 0, 0, 0, szFontFaceConsolas
    mov [hFontMenu], eax
    invoke CreateFont, 16, 0, 0, 0, 700, 0, 0, 0, 0, 0, 0, 0, 0, szFontFaceConsolas
    mov [hFontTable], eax
    invoke CreateFont, 14, 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 0, 0, szFontFaceArial
    mov [hFontSub], eax
    invoke CreateFont, 20, 0, 0, 0, 700, 0, 0, 0, 0, 0, 0, 0, 0, szFontFaceConsolas
    mov [hFontInput], eax

    mov eax, [grid_size]
    imul eax, CELL_SIZE
    mov [board_pixels], eax
    call update_watermark_font

    call reset_game
    mov [game_state], STATE_MENU

    invoke SetTimer, [hwnd], TIMER_ID, TIMER_INTERVAL, 0
    xor eax, eax
    ret

; ------------------------------------------------------------------------------
;  WM_TIMER
; ------------------------------------------------------------------------------
.wm_timer:
    inc [cursor_tick]
    cmp [game_state], STATE_RUNNING
    je .timer_tick
    cmp [game_state], STATE_INPUT_NAME
    je .timer_redraw
    xor eax, eax
    ret
.timer_tick:
    call game_tick
.timer_redraw:
    invoke InvalidateRect, [hwnd], 0, FALSE
    xor eax, eax
    ret

; ------------------------------------------------------------------------------
;  WM_CHAR - name entry
; ------------------------------------------------------------------------------
.wm_char:
    cmp [game_state], STATE_INPUT_NAME
    jne .char_done

    mov eax, [wParam]
    cmp eax, VK_RETURN
    je .save_record_name
    cmp eax, VK_BACK
    je .char_backspace
    cmp eax, VK_ESCAPE
    je .cancel_input

    cmp eax, 32
    jl .char_done
    cmp eax, 126
    jg .char_done

    mov ecx, [input_len]
    cmp ecx, NAME_LEN - 4
    jge .char_done
    mov byte [input_name + ecx], al
    inc [input_len]
    inc ecx
    mov byte [input_name + ecx], 0
    invoke InvalidateRect, [hwnd], 0, FALSE
    jmp .char_done

.char_backspace:
    cmp [input_len], 0
    jle .char_done
    dec [input_len]
    mov ecx, [input_len]
    mov byte [input_name + ecx], 0
    invoke InvalidateRect, [hwnd], 0, FALSE
    jmp .char_done

.cancel_input:
    mov [game_state], STATE_GAMEOVER
    invoke InvalidateRect, [hwnd], 0, FALSE
    jmp .char_done

.save_record_name:
    ; the name may stay empty - then the row holds just the score
    ; find the insert position in the list
    xor ebx, ebx
.find_rank:
    cmp ebx, MAX_TOP
    jge .after_save
    mov eax, [score]
    cmp eax, [top_scores + ebx*4]
    jg .insert_rank
    inc ebx
    jmp .find_rank

.insert_rank:
    mov ecx, MAX_TOP - 2
.shift_down:
    cmp ecx, ebx
    jl .do_insert
    mov eax, [top_scores + ecx*4]
    mov [top_scores + ecx*4 + 4], eax
    push ebx
    push ecx
    mov edx, ecx
    shl edx, 4
    lea edi, [top_names + edx + 16]
    lea esi, [top_names + edx]
    invoke lstrcpy, edi, esi
    pop ecx
    pop ebx
    dec ecx
    jmp .shift_down

.do_insert:
    mov eax, [score]
    mov [top_scores + ebx*4], eax
    cmp [top_count], MAX_TOP
    jge .count_done
    inc [top_count]
.count_done:
    push ebx
    mov edx, ebx
    shl edx, 4
    lea edi, [top_names + edx]
    invoke lstrcpy, edi, input_name
    pop ebx
    mov [highlight_rank], ebx
    call save_top10

.after_save:
    mov [game_state], STATE_GAMEOVER
    invoke InvalidateRect, [hwnd], 0, FALSE

.char_done:
    xor eax, eax
    ret

; ------------------------------------------------------------------------------
;  WM_KEYDOWN
; ------------------------------------------------------------------------------
.wm_keydown:
    mov eax, [wParam]

    cmp [game_state], STATE_INPUT_NAME
    je .kd_done

    cmp eax, 'M'
    je .toggle_sound
    cmp eax, 'm'
    je .toggle_sound

    cmp [game_state], STATE_MENU
    je .menu_keys
    cmp [game_state], STATE_GAMEOVER
    je .gameover_keys
    jmp .running_keys

; --- difficulty selection ---
.menu_keys:
    cmp eax, VK_UP
    je .menu_up
    cmp eax, 'W'
    je .menu_up
    cmp eax, 'w'
    je .menu_up
    cmp eax, VK_LEFT
    je .menu_up
    cmp eax, 'A'
    je .menu_up
    cmp eax, 'a'
    je .menu_up

    cmp eax, VK_DOWN
    je .menu_down
    cmp eax, 'S'
    je .menu_down
    cmp eax, 's'
    je .menu_down
    cmp eax, VK_RIGHT
    je .menu_down
    cmp eax, 'D'
    je .menu_down
    cmp eax, 'd'
    je .menu_down

    cmp eax, VK_RETURN
    je .menu_enter
    cmp eax, VK_SPACE
    je .menu_enter
    cmp eax, '1'
    je .menu_pick_1
    cmp eax, '2'
    je .menu_pick_2
    cmp eax, '3'
    je .menu_pick_3
    cmp eax, '4'
    je .menu_pick_4
    cmp eax, VK_ESCAPE
    je .key_esc
    jmp .kd_done

.menu_up:
    cmp [menu_sel], 0
    jle .menu_redraw
    dec [menu_sel]
    jmp .menu_redraw
.menu_down:
    cmp [menu_sel], MENU_COUNT - 1
    jge .menu_redraw
    inc [menu_sel]
    jmp .menu_redraw
.menu_pick_1:
    mov [menu_sel], 0
    jmp .menu_enter
.menu_pick_2:
    mov [menu_sel], 1
    jmp .menu_enter
.menu_pick_3:
    mov [menu_sel], 2
    jmp .menu_enter
.menu_pick_4:
    mov [menu_sel], 3
    jmp .menu_enter
.menu_enter:
    call start_game
    invoke InvalidateRect, [hwnd], 0, FALSE
    jmp .kd_done
.menu_redraw:
    invoke InvalidateRect, [hwnd], 0, FALSE
    jmp .kd_done

; --- game over screen ---
.gameover_keys:
    cmp eax, VK_SPACE
    je .to_menu
    cmp eax, VK_RETURN
    je .to_menu
    cmp eax, 'R'
    je .to_menu
    cmp eax, 'r'
    je .to_menu
    cmp eax, VK_ESCAPE
    je .key_esc
    jmp .kd_done

.to_menu:
    call back_to_menu
    invoke InvalidateRect, [hwnd], 0, FALSE
    jmp .kd_done

; --- in-game keys ---
.running_keys:
    cmp eax, VK_UP
    je .key_up
    cmp eax, 'W'
    je .key_up
    cmp eax, 'w'
    je .key_up
    cmp eax, VK_DOWN
    je .key_down
    cmp eax, 'S'
    je .key_down
    cmp eax, 's'
    je .key_down
    cmp eax, VK_LEFT
    je .key_left
    cmp eax, 'A'
    je .key_left
    cmp eax, 'a'
    je .key_left
    cmp eax, VK_RIGHT
    je .key_right
    cmp eax, 'D'
    je .key_right
    cmp eax, 'd'
    je .key_right
    cmp eax, 'P'
    je .key_pause
    cmp eax, 'p'
    je .key_pause
    cmp eax, VK_SPACE
    je .key_pause
    cmp eax, 'R'
    je .to_menu
    cmp eax, 'r'
    je .to_menu
    cmp eax, VK_ESCAPE
    je .key_esc
    jmp .kd_done

.key_up:
    mov eax, DIR_UP
    call queue_direction
    jmp .kd_done
.key_down:
    mov eax, DIR_DOWN
    call queue_direction
    jmp .kd_done
.key_left:
    mov eax, DIR_LEFT
    call queue_direction
    jmp .kd_done
.key_right:
    mov eax, DIR_RIGHT
    call queue_direction
    jmp .kd_done

.key_pause:
    cmp [game_state], STATE_RUNNING
    je .do_pause
    cmp [game_state], STATE_PAUSED
    je .do_resume
    jmp .kd_done
.do_pause:
    mov [game_state], STATE_PAUSED
    invoke InvalidateRect, [hwnd], 0, FALSE
    jmp .kd_done
.do_resume:
    mov [game_state], STATE_RUNNING
    invoke InvalidateRect, [hwnd], 0, FALSE
    jmp .kd_done

.toggle_sound:
    xor [sound_enabled], 1
    jmp .kd_done

.key_esc:
    invoke DestroyWindow, [hwnd]

.kd_done:
    xor eax, eax
    ret

.wm_erasebkgnd:
    mov eax, 1
    ret

; ------------------------------------------------------------------------------
;  WM_PAINT - the window is always the playfield
; ------------------------------------------------------------------------------
.wm_paint:
    invoke BeginPaint, [hwnd], ps
    mov [hdc], eax
    invoke CreateCompatibleDC, [hdc]
    mov [memdc], eax
    invoke CreateCompatibleBitmap, [hdc], [window_width], [window_height]
    mov [membmp], eax
    invoke SelectObject, [memdc], [membmp]
    mov [oldbmp], eax
    invoke SetBkMode, [memdc], TRANSPARENT

    invoke SelectObject, [memdc], [hFontSub]
    mov [oldFont], eax
    invoke SelectObject, [memdc], [hPenGrid]
    mov [oldPen], eax

    ; --- field background ---
    mov [rcBoard.left], 0
    mov [rcBoard.top], 0
    mov eax, [board_pixels]
    mov [rcBoard.right], eax
    mov [rcBoard.bottom], eax
    invoke FillRect, [memdc], rcBoard, [hBrushBoard]

    ; --- score watermark (hidden in the menu) ---
    cmp [game_state], STATE_MENU
    je .skip_watermark
    invoke SelectObject, [memdc], [hFontWatermark]
    invoke SetTextColor, [memdc], 0x00284329     ; midway between 0x1B261A and 0x356038
    cinvoke wsprintf, szTextBuf, szNumFmt, [score]
    invoke DrawText, [memdc], szTextBuf, -1, rcBoard, DT_CENTER or DT_VCENTER or DT_SINGLELINE
.skip_watermark:

    ; --- grid lines ---
    invoke SelectObject, [memdc], [hPenGrid]
    mov ecx, 1
.grid_x_loop:
    cmp ecx, [grid_size]
    jge .grid_x_done
    mov eax, ecx
    imul eax, CELL_SIZE
    mov [x1], eax
    push ecx
    invoke MoveToEx, [memdc], [x1], 0, 0
    invoke LineTo, [memdc], [x1], [board_pixels]
    pop ecx
    inc ecx
    jmp .grid_x_loop
.grid_x_done:
    mov ecx, 1
.grid_y_loop:
    cmp ecx, [grid_size]
    jge .grid_y_done
    mov eax, ecx
    imul eax, CELL_SIZE
    mov [y1], eax
    push ecx
    invoke MoveToEx, [memdc], 0, [y1], 0
    invoke LineTo, [memdc], [board_pixels], [y1]
    pop ecx
    inc ecx
    jmp .grid_y_loop
.grid_y_done:

    ; in the menu neither the apple nor the snake is drawn
    cmp [game_state], STATE_MENU
    je .board_done

    ; --- apple ---
    mov eax, [food_x]
    imul eax, CELL_SIZE
    mov [x1], eax
    mov eax, [food_y]
    imul eax, CELL_SIZE
    mov [y1], eax

    invoke SelectObject, [memdc], [hBrushApple]
    invoke SelectObject, [memdc], [hPenApple]
    mov eax, [x1]
    add eax, 10
    mov edx, [y1]
    add edx, 11
    stdcall DrawDot, [memdc], eax, edx, 7

    invoke SelectObject, [memdc], [hBrushLeaf]
    invoke SelectObject, [memdc], [hNullPen]
    mov eax, [x1]
    add eax, 9
    mov edx, [y1]
    add edx, 2
    mov ecx, [x1]
    add ecx, 12
    mov ebx, [y1]
    add ebx, 6
    invoke Rectangle, [memdc], eax, edx, ecx, ebx

    invoke SelectObject, [memdc], [hBrushAppleShine]
    mov eax, [x1]
    add eax, 8
    mov edx, [y1]
    add edx, 8
    stdcall DrawDot, [memdc], eax, edx, 2

    ; --- snake body ---
    mov eax, [snake_len]
    dec eax
    mov [iSeg], eax
.body_draw_loop:
    cmp [iSeg], 0
    jle .body_draw_done
    mov edx, [iSeg]
    mov eax, [snake_x + edx*4]
    imul eax, CELL_SIZE
    mov [segX], eax
    mov eax, [snake_y + edx*4]
    imul eax, CELL_SIZE
    mov [segY], eax

    invoke SelectObject, [memdc], [hBrushSnakeBody]
    invoke SelectObject, [memdc], [hPenSnakeBorder]
    mov eax, [segX]
    inc eax
    mov [x1], eax
    add eax, CELL_SIZE - 2
    mov [x2], eax
    mov edx, [segY]
    inc edx
    mov [y1], edx
    add edx, CELL_SIZE - 2
    mov [y2], edx
    invoke RoundRect, [memdc], [x1], [y1], [x2], [y2], 6, 6

    invoke SelectObject, [memdc], [hBrushSnakeInner]
    invoke SelectObject, [memdc], [hNullPen]
    mov eax, [segX]
    add eax, 5
    mov [x1], eax
    add eax, CELL_SIZE - 10
    mov [x2], eax
    mov edx, [segY]
    add edx, 5
    mov [y1], edx
    add edx, CELL_SIZE - 10
    mov [y2], edx
    invoke RoundRect, [memdc], [x1], [y1], [x2], [y2], 3, 3

    dec [iSeg]
    jmp .body_draw_loop
.body_draw_done:

    ; --- head ---
    mov eax, [snake_x]
    imul eax, CELL_SIZE
    mov [segX], eax
    mov eax, [snake_y]
    imul eax, CELL_SIZE
    mov [segY], eax

    invoke SelectObject, [memdc], [hBrushSnakeHead]
    invoke SelectObject, [memdc], [hPenSnakeBorder]
    mov eax, [segX]
    inc eax
    mov [x1], eax
    add eax, CELL_SIZE - 2
    mov [x2], eax
    mov edx, [segY]
    inc edx
    mov [y1], edx
    add edx, CELL_SIZE - 2
    mov [y2], edx
    invoke RoundRect, [memdc], [x1], [y1], [x2], [y2], 8, 8

    invoke SelectObject, [memdc], [hBrushEye]
    invoke SelectObject, [memdc], [hNullPen]
    mov eax, [curr_dir]
    cmp eax, DIR_UP
    je .eyes_up
    cmp eax, DIR_DOWN
    je .eyes_down
    cmp eax, DIR_LEFT
    je .eyes_left

    mov eax, [segX]
    add eax, 14
    mov edx, [segY]
    add edx, 6
    stdcall DrawDot, [memdc], eax, edx, 3
    mov eax, [segX]
    add eax, 14
    mov edx, [segY]
    add edx, 14
    stdcall DrawDot, [memdc], eax, edx, 3
    invoke SelectObject, [memdc], [hBrushPupil]
    mov eax, [segX]
    add eax, 15
    mov edx, [segY]
    add edx, 6
    stdcall DrawDot, [memdc], eax, edx, 1
    mov eax, [segX]
    add eax, 15
    mov edx, [segY]
    add edx, 14
    stdcall DrawDot, [memdc], eax, edx, 1
    jmp .eyes_done

.eyes_up:
    mov eax, [segX]
    add eax, 6
    mov edx, [segY]
    add edx, 6
    stdcall DrawDot, [memdc], eax, edx, 3
    mov eax, [segX]
    add eax, 14
    mov edx, [segY]
    add edx, 6
    stdcall DrawDot, [memdc], eax, edx, 3
    invoke SelectObject, [memdc], [hBrushPupil]
    mov eax, [segX]
    add eax, 6
    mov edx, [segY]
    add edx, 5
    stdcall DrawDot, [memdc], eax, edx, 1
    mov eax, [segX]
    add eax, 14
    mov edx, [segY]
    add edx, 5
    stdcall DrawDot, [memdc], eax, edx, 1
    jmp .eyes_done

.eyes_down:
    mov eax, [segX]
    add eax, 6
    mov edx, [segY]
    add edx, 14
    stdcall DrawDot, [memdc], eax, edx, 3
    mov eax, [segX]
    add eax, 14
    mov edx, [segY]
    add edx, 14
    stdcall DrawDot, [memdc], eax, edx, 3
    invoke SelectObject, [memdc], [hBrushPupil]
    mov eax, [segX]
    add eax, 6
    mov edx, [segY]
    add edx, 15
    stdcall DrawDot, [memdc], eax, edx, 1
    mov eax, [segX]
    add eax, 14
    mov edx, [segY]
    add edx, 15
    stdcall DrawDot, [memdc], eax, edx, 1
    jmp .eyes_done

.eyes_left:
    mov eax, [segX]
    add eax, 6
    mov edx, [segY]
    add edx, 6
    stdcall DrawDot, [memdc], eax, edx, 3
    mov eax, [segX]
    add eax, 6
    mov edx, [segY]
    add edx, 14
    stdcall DrawDot, [memdc], eax, edx, 3
    invoke SelectObject, [memdc], [hBrushPupil]
    mov eax, [segX]
    add eax, 5
    mov edx, [segY]
    add edx, 6
    stdcall DrawDot, [memdc], eax, edx, 1
    mov eax, [segX]
    add eax, 5
    mov edx, [segY]
    add edx, 14
    stdcall DrawDot, [memdc], eax, edx, 1
.eyes_done:

.board_done:
    invoke FrameRect, [memdc], rcBoard, [hBrushBorder]

    cmp [game_state], STATE_MENU
    je .draw_menu
    cmp [game_state], STATE_PAUSED
    je .draw_pause
    cmp [game_state], STATE_GAMEOVER
    je .draw_gameover
    cmp [game_state], STATE_INPUT_NAME
    je .draw_input
    jmp .blit_screen

; ------------------------------------------------------------------------------
;  Difficulty selection, drawn right inside the playfield
; ------------------------------------------------------------------------------
.draw_menu:
    mov eax, 150
    mov edx, 160
    call center_box
    invoke FillRect, [memdc], rcBanner, [hBrushPanel]
    invoke FrameRect, [memdc], rcBanner, [hBrushBorder]

    invoke SelectObject, [memdc], [hFontMenu]
    xor ebx, ebx
.menu_loop:
    cmp ebx, MENU_COUNT
    jge .menu_loop_done

    mov eax, [rcBanner.left]
    add eax, 6
    mov [rcText.left], eax
    mov eax, [rcBanner.right]
    sub eax, 6
    mov [rcText.right], eax
    mov eax, ebx
    imul eax, 36
    add eax, [rcBanner.top]
    add eax, 8
    mov [rcText.top], eax
    add eax, 32
    mov [rcText.bottom], eax

    cmp ebx, [menu_sel]
    jne .menu_plain
    invoke FillRect, [memdc], rcText, [hBrushSelected]
    invoke SetTextColor, [memdc], 0x0060F070
    jmp .menu_draw
.menu_plain:
    invoke SetTextColor, [memdc], 0x00566056
.menu_draw:
    mov esi, [menu_table + ebx*4]
    invoke DrawText, [memdc], esi, -1, rcText, DT_CENTER or DT_VCENTER or DT_SINGLELINE

    inc ebx
    jmp .menu_loop
.menu_loop_done:
    jmp .blit_screen

; ------------------------------------------------------------------------------
;  Pause
; ------------------------------------------------------------------------------
.draw_pause:
    mov eax, 260
    mov edx, 104
    call center_box
    invoke FillRect, [memdc], rcBanner, [hBrushPauseBox]
    invoke FrameRect, [memdc], rcBanner, [hBrushSnakeHead]

    invoke SelectObject, [memdc], [hFontTitle]
    invoke SetTextColor, [memdc], 0x0020E0FF
    mov eax, 16
    mov edx, 32
    call banner_text_rect
    invoke DrawText, [memdc], szPauseTitle, -1, rcText, DT_CENTER or DT_SINGLELINE

    invoke SelectObject, [memdc], [hFontSub]
    invoke SetTextColor, [memdc], 0x00D0D0D0
    mov eax, 60
    mov edx, 24
    call banner_text_rect
    invoke DrawText, [memdc], szPauseHint, -1, rcText, DT_CENTER or DT_SINGLELINE
    jmp .blit_screen

; ------------------------------------------------------------------------------
;  Game over. The TOP 10 list is shown only when it fits in the window
; ------------------------------------------------------------------------------
.draw_gameover:
    xor edi, edi                ; edi = 1 when the whole TOP 10 table fits
    mov eax, [window_height]
    cmp eax, 440
    jl .go_small
    mov eax, [window_width]
    cmp eax, 320
    jl .go_small
    mov edi, 1
    mov eax, 312
    mov edx, 404
    jmp .go_box
.go_small:
    mov eax, 300
    mov edx, 108
.go_box:
    call center_box
    invoke FillRect, [memdc], rcBanner, [hBrushOverlayBox]
    invoke FrameRect, [memdc], rcBanner, [hBrushApple]

    invoke SelectObject, [memdc], [hFontTitle]
    invoke SetTextColor, [memdc], 0x003535F5
    mov eax, 10
    mov edx, 32
    call banner_text_rect
    invoke DrawText, [memdc], szGameOverTitle, -1, rcText, DT_CENTER or DT_SINGLELINE

    invoke SelectObject, [memdc], [hFontTable]
    invoke SetTextColor, [memdc], 0x00E0E0E0
    cinvoke wsprintf, szTextBuf, szScoreFmt, [score]
    mov eax, 48
    mov edx, 24
    call banner_text_rect
    invoke DrawText, [memdc], szTextBuf, -1, rcText, DT_CENTER or DT_SINGLELINE

    invoke SetTextColor, [memdc], 0x0090A090
    cinvoke wsprintf, szTextBuf, szFieldFmt, [final_grid], [final_grid]
    mov eax, 72
    mov edx, 24
    call banner_text_rect
    invoke DrawText, [memdc], szTextBuf, -1, rcText, DT_CENTER or DT_SINGLELINE

    test edi, edi
    jz .blit_screen

    invoke SelectObject, [memdc], [hFontTable]
    invoke SetTextColor, [memdc], 0x0040F050
    mov eax, 104
    mov edx, 24
    call banner_text_rect
    invoke DrawText, [memdc], szTopTitle, -1, rcText, DT_CENTER or DT_SINGLELINE

    mov eax, [rcBanner.top]
    add eax, 136
    stdcall DrawTopList, [memdc], eax
    jmp .blit_screen

; ------------------------------------------------------------------------------
;  Name entry
; ------------------------------------------------------------------------------
.draw_input:
    mov eax, 300
    mov edx, 134
    call center_box
    invoke FillRect, [memdc], rcBanner, [hBrushOverlayBox]
    invoke FrameRect, [memdc], rcBanner, [hBrushSnakeHead]

    invoke SelectObject, [memdc], [hFontTitle]
    invoke SetTextColor, [memdc], 0x0020E0FF
    mov eax, 10
    mov edx, 32
    call banner_text_rect
    invoke DrawText, [memdc], szInputTitle, -1, rcText, DT_CENTER or DT_SINGLELINE

    invoke SelectObject, [memdc], [hFontTable]
    invoke SetTextColor, [memdc], 0x00E0E0E0
    cinvoke wsprintf, szTextBuf, szScoreFmt, [score]
    mov eax, 46
    mov edx, 24
    call banner_text_rect
    invoke DrawText, [memdc], szTextBuf, -1, rcText, DT_CENTER or DT_SINGLELINE

    mov eax, [rcBanner.left]
    add eax, 16
    mov [rcInputBox.left], eax
    mov eax, [rcBanner.right]
    sub eax, 16
    mov [rcInputBox.right], eax
    mov eax, [rcBanner.top]
    add eax, 78
    mov [rcInputBox.top], eax
    add eax, 40
    mov [rcInputBox.bottom], eax
    invoke FillRect, [memdc], rcInputBox, [hBrushInputBox]
    invoke FrameRect, [memdc], rcInputBox, [hBrushSnakeHead]

    mov edx, szEmptyChar
    test [cursor_tick], 4
    jz .no_cursor
    mov edx, szCursorChar
.no_cursor:
    cinvoke wsprintf, szTextBuf, szInputBoxFmt, addr input_name, edx
    invoke SelectObject, [memdc], [hFontInput]
    invoke SetTextColor, [memdc], 0x0040F050
    invoke DrawText, [memdc], szTextBuf, -1, rcInputBox, DT_CENTER or DT_VCENTER or DT_SINGLELINE

.blit_screen:
    invoke BitBlt, [hdc], 0, 0, [window_width], [window_height], [memdc], 0, 0, SRCCOPY
    invoke SelectObject, [memdc], [oldFont]
    invoke SelectObject, [memdc], [oldPen]
    invoke SelectObject, [memdc], [oldbmp]
    invoke DeleteObject, [membmp]
    invoke DeleteDC, [memdc]
    invoke EndPaint, [hwnd], ps
    xor eax, eax
    ret

; ------------------------------------------------------------------------------
;  WM_DESTROY
; ------------------------------------------------------------------------------
.wm_destroy:
    invoke KillTimer, [hwnd], TIMER_ID

    invoke DeleteObject, [hBrushBack]
    invoke DeleteObject, [hBrushBoard]
    invoke DeleteObject, [hBrushBorder]
    invoke DeleteObject, [hBrushSnakeHead]
    invoke DeleteObject, [hBrushSnakeBody]
    invoke DeleteObject, [hBrushSnakeInner]
    invoke DeleteObject, [hPenSnakeBorder]
    invoke DeleteObject, [hBrushApple]
    invoke DeleteObject, [hPenApple]
    invoke DeleteObject, [hBrushAppleShine]
    invoke DeleteObject, [hBrushLeaf]
    invoke DeleteObject, [hBrushEye]
    invoke DeleteObject, [hBrushPupil]
    invoke DeleteObject, [hBrushPanel]
    invoke DeleteObject, [hBrushSelected]
    invoke DeleteObject, [hBrushOverlayBox]
    invoke DeleteObject, [hBrushPauseBox]
    invoke DeleteObject, [hBrushInputBox]
    invoke DeleteObject, [hPenGrid]
    invoke DeleteObject, [hPenDivider]

    invoke DeleteObject, [hFontWatermark]
    invoke DeleteObject, [hFontTitle]
    invoke DeleteObject, [hFontMenu]
    invoke DeleteObject, [hFontTable]
    invoke DeleteObject, [hFontSub]
    invoke DeleteObject, [hFontInput]

    invoke PostQuitMessage, 0
    xor eax, eax
    ret
endp

; ==============================================================================
;  Drawing the TOP 10 list (on the game over screen, when it fits)
; ==============================================================================
proc DrawTopList uses ebx esi edi, memdc, topY
    invoke SelectObject, [memdc], [hFontTable]
    mov eax, [rcBanner.left]
    add eax, 24
    mov [rcText.left], eax
    mov eax, [rcBanner.right]
    sub eax, 24
    mov [rcText.right], eax

    cmp [top_count], 0
    jle .empty

    xor ebx, ebx
.rows:
    cmp ebx, [top_count]
    jge .done
    cmp ebx, MAX_TOP
    jge .done

    mov eax, ebx
    imul eax, 26
    add eax, [topY]
    mov [rcText.top], eax
    add eax, 24
    mov [rcText.bottom], eax

    cmp ebx, [highlight_rank]
    jne .normal
    invoke SetTextColor, [memdc], 0x0020E0FF
    jmp .row_text
.normal:
    invoke SetTextColor, [memdc], 0x00D0E8D0
.row_text:
    mov edx, ebx
    inc edx
    mov eax, ebx
    shl eax, 4
    lea esi, [top_names + eax]
    cinvoke wsprintf, szTextBuf2, szTopLineFmt, edx, esi, [top_scores + ebx*4]
    invoke DrawText, [memdc], szTextBuf2, -1, rcText, DT_LEFT or DT_SINGLELINE

    inc ebx
    jmp .rows

.empty:
    invoke SetTextColor, [memdc], 0x00708070
    mov eax, [topY]
    mov [rcText.top], eax
    add eax, 24
    mov [rcText.bottom], eax
    invoke DrawText, [memdc], szNoRecords, -1, rcText, DT_CENTER or DT_SINGLELINE
.done:
    ret
endp

; ==============================================================================
;  Helper routines
;  center_box: eax = width, edx = height -> rcBanner (centred, clipped to window)
; ==============================================================================
center_box:
    mov ecx, [window_width]
    sub ecx, 8
    cmp eax, ecx
    jle .w_ok
    mov eax, ecx
.w_ok:
    mov ecx, [window_height]
    sub ecx, 8
    cmp edx, ecx
    jle .h_ok
    mov edx, ecx
.h_ok:
    push eax
    push edx
    mov ecx, [window_width]
    sub ecx, eax
    sar ecx, 1
    mov [rcBanner.left], ecx
    add ecx, eax
    mov [rcBanner.right], ecx
    pop edx
    mov ecx, [window_height]
    sub ecx, edx
    sar ecx, 1
    mov [rcBanner.top], ecx
    add ecx, edx
    mov [rcBanner.bottom], ecx
    pop eax
    ret

; eax = offset from the top of rcBanner, edx = line height -> rcText
banner_text_rect:
    mov ecx, [rcBanner.left]
    add ecx, 6
    mov [rcText.left], ecx
    mov ecx, [rcBanner.right]
    sub ecx, 6
    mov [rcText.right], ecx
    add eax, [rcBanner.top]
    mov [rcText.top], eax
    add eax, edx
    mov [rcText.bottom], eax
    ret

; ==============================================================================
;  Resource section (snake.ico)
; ==============================================================================
section '.rsrc' resource data readable
  directory RT_ICON, icons, \
            RT_GROUP_ICON, group_icons

  resource icons, \
           1, LANG_NEUTRAL, icon_data

  resource group_icons, \
           1, LANG_NEUTRAL, main_icon

  icon main_icon, icon_data, 'snake.ico'

; ==============================================================================
;  Import table
; ==============================================================================
section '.idata' import data readable writeable

  library kernel32, 'KERNEL32.DLL', \
          user32,   'USER32.DLL', \
          gdi32,    'GDI32.DLL'

  include 'api\\kernel32.inc'
  include 'api\\user32.inc'
  include 'api\\gdi32.inc'
