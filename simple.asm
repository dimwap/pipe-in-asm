; «««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««
      .486                      ; create 32 bit code
      .model flat, stdcall      ; 32 bit memory model
      option casemap :none      ; case sensitive

      include \masm32\include\dialogs.inc
      include simple.inc                      ; Useful Macros

      dlgproc PROTO :DWORD,:DWORD,:DWORD,:DWORD   ;Prototipe

    .code
; ««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««CodeBegin
start:
      mov hInstance, FUNC(GetModuleHandle,NULL)
      call main
      invoke ExitProcess,eax                             ;выход в ОС завершение
; «««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««««Main
main proc

    Dialog "Simple Pipe","MS Sans Serif",10, \              ; caption,font,размер шрифта
            WS_OVERLAPPED or WS_SYSMENU or DS_CENTER, \     ; style - стиль окна
            5, \                                            ; control count - количество элм диалога
            50,50,155,100, \                                ; x y координаты
            1024                                            ; memory buffer size

    DlgEdit   ES_LEFT or WS_BORDER or WS_TABSTOP,17,20,121,11,301        ;  id = 301   edit box
    DlgButton "About",WS_TABSTOP,55,6,30,11,IDOK
    DlgButton "&Server",WS_TABSTOP,58,45,40,15,IDYES
    DlgButton "&Client",WS_TABSTOP,100,45,40,15,IDNO
    DlgStatic "For exit press Alt-F4",SS_LEFT,6,80,135,11,100            ;  id = 100  status/inform line

    CallModalDialog hInstance,0,dlgproc,NULL            ;Весь диалог тут в окне CallModalDialog
                                                        ; процедура main заканчивается когда 
    ret                                                 ; произойдет выход из бесконечного цикла dlgproc 
                                                        ; по вызову EndDialog в нем.
main endp                                               ;завершение call main

;-----------------------------------------------------data_section------------
.data
   NamedPipeIn db "\\.\pipe\MyFifoPipe", 0     ;  имя канала
   sAbout db "Simple GUI with 3 buttons.",13,10,"Server, Client, About.",0
   nBytes dd 0  ;number of bytes written into pipe
   fmt    db "%d",0   ;формат для преобразования в строку

  sErrNum  db "ErrNum:"    ;обработка ошибок, строка вывода
  sErr     db  16 dup(0)   ;номер ошибки текстовым десятичным числом, цифровыми символами
  nErr     dd 0            ;номер ошибки числом в двоичном коде

  sGotMess db "I'v Got bytes:"
    sGots  db 16 dup(0)   ;количество байт - текстовыми символами
    nGots  dd 0            ;двоичное число
;-data???????????????????????????????????????????????????????????????????????????
.Data?                 ;CUSTOM .DATA?
  hFile_data dd ?      ;хэндл клиентского файла в канале
  hPipeIn    dd ?        ;хэндл канала сервера
  OpenMode   dd ? ;
  PipeMode   dd ? ;

  bufGet     db 256 dup(?)   ;буфер чтения для клиента
  bufMessage db 256 dup(?)   ;буфер для хранения из поля ввода и затем отправки в pipe-канал
    lenMes   dd ?            ;длина сообщения 
    buffer   db 64 dup(?)   ;для чтения диалогового элемента 301 (поле ввода текста)
;*****************************************************************************CODE*****
.code

dlgproc proc hWin:DWORD,uMsg:DWORD,wParam:DWORD,lParam:DWORD
   
    .if uMsg == WM_INITDIALOG                                                ;инициализация окна диалога
      invoke SendMessage,hWin,WM_SETICON,1,FUNC(LoadIcon,NULL,IDI_ASTERISK)  ;установить иконку звездочку*

    .elseif uMsg == WM_COMMAND        ;uMsg - событие в окне диалога
      .if wParam == IDCANCEL          ; при нажатии на кнопку, id кнопки в wparam
        ret                           ; этой кнопки в диалоге нет (wParam == IDCANCEL)
      .elseif wParam == IDOK          ; кнопка About
         fn MessageBox,0, offset sAbout ,"About",MB_OK    ; окно с сообщением About! в строке sAbout
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      .elseif wParam == IDYES                             ;  кнопка Server кнопка №_1
;-------------------------------------------------------------------------------------------------
     ; инициализация параметров канала
      mov OpenMode, PIPE_ACCESS_DUPLEX   
      mov eax,PIPE_TYPE_BYTE + PIPE_READMODE_BYTE + PIPE_WAIT  ;PIPE_TYPE_MESSAGE + PIPE_READMODE_MESSAGE + PIPE_WAIT
                                                               ; PIPE_WAIT - Блокирующий режим, с ожиданием
      mov PipeMode,eax                   
      invoke CreateNamedPipe, ADDR NamedPipeIn, OpenMode, PipeMode, 1 , 1024, 1024, 0, NULL      ; 1 штука
      ; канал создан
      .IF eax != INVALID_HANDLE_VALUE   ;not(-1), проверка хэндла в eax
        mov hPipeIn, eax                ; и сохранение его
        fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, "Pipe server created (this process is a server)"  ;offset sYes
      .ELSE  ;-1 = инвалид хэндл
        fn MessageBox,0, "Invalid handle (-1) for this pipe" ,"Error",MB_OK     
        fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, "Invalid handle of created pipe"
       ret
      .ENDIF
      ;ситуации с хэндлом канала обработаны.
      fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, "Waiting for client"
      invoke Sleep, 250
      invoke ConnectNamedPipe, hPipeIn, NULL    ;ждем подключения клиента
      ;далее идет только когда клиент подключен. паузы чтобы успеть прочитать сообщения)
      fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, "client is online"
      invoke Sleep, 250

      mov ebx, rv(GetDlgItemText,hWin,301,offset buffer,20)    ;читаем 20 символов из ввода
      ;количество символов в ebx
       .IF eax == 0    
         invoke GetLastError    ; обработка возможных ошибок, получить номер ошибки после неудачного чтения
         mov nErr,eax                                ;записать её
         invoke wsprintf, addr sErr, addr fmt, eax   ;преобразовать в строку
         fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, offset sErrNum  ;вывести сообщение в статус
         invoke Sleep, 1500
      .ENDIF

       invoke wsprintf, addr sGots, addr fmt, ebx   ;перевод числа байт в текстовый вид
       fn SendMessage,rv(GetDlgItem,hWin,100), WM_SETTEXT,0, offset sGotMess ;сколько байт отправлено
       invoke Sleep, 500
       fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, offset buffer ;сообщ. в статус
       invoke Sleep, 500
       invoke WriteFile,hPipeIn,offset buffer,sizeof buffer,offset nBytes,0h
       ; отправить буфер в pipe канал
         fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, "writing message to client"
         invoke CloseHandle,hPipeIn  ;закрыть канал
         invoke Sleep, 500
         fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, "OK. pipe closed. Ready"
       ret

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      .elseif wParam == IDNO                                          ;  кнопка Client #2
;--------------------------------------------------------------------------------------------!!!
; The server has to be running and waiting for the client before the client can start
;----------------------------------------------------------------------------------------!!!
;   Read from the pipe.                                

    invoke CreateFile, offset NamedPipeIn,GENERIC_READ or GENERIC_WRITE,0,NULL,OPEN_EXISTING,0,NULL

      .IF eax != INVALID_HANDLE_VALUE   ; eax != (-1)
        mov hFile_data,eax              ; хэндл открытого клиентом файла функция CreateFile отдает в eax
      .ELSE
        fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, "Invalid handle of pipe for read"
        invoke Sleep, 1500                                   ;об ошибке сообщим в статус
        ret
      .ENDIF

      invoke SetNamedPipeHandleState, hFile_data, PIPE_READMODE_BYTE, NULL,NULL  ;режим канала установлен

      invoke ReadFile,hFile_data,offset bufGet ,125,offset nGots,0h     ;nGots - количество байт=125
       .IF eax != 0      ;TRUE - все нормально, в eax = 1/0 результат функции ReadFile
         invoke lstrlen, offset bufGet ; eax - длина строки
         invoke wsprintf, addr sGots, addr fmt, eax   ;перевод числа в строку
         fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, offset sGotMess
      .ELSE                     ;eax ==0, False -- error!!
         invoke GetLastError    ; обработка возможных ошибок, получить номер ошибки последней операции
         mov nErr,eax                                ;записать её, ну так просто
         invoke wsprintf, addr sErr, addr fmt, eax   ;преобразовать число eax в строку по формату fmt
         fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, offset sErrNum  ;вывести сообщение в статус
      .ENDIF

       invoke CloseHandle,hFile_data           ; закрыть файл клиента в канале pipe
       fn SendMessage,rv(GetDlgItem,hWin,301),WM_SETTEXT,0, offset bufGet  
       ret
      .endif

    .elseif uMsg == WM_CLOSE        ; при получении сообщения о закрытии окна, выйти из диалога
      quit_dialog:
      invoke EndDialog,hWin,0

    .endif
    xor eax, eax
    ret
dlgproc endp
; «««««««««««««««««««««««««««««« указатель на точку входа ««start««««««««««««««««««««««««««««««««««««
end start
;Конец.