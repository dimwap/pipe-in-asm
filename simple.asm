; �������������������������������������������������������������������������
      .486                      ; create 32 bit code
      .model flat, stdcall      ; 32 bit memory model
      option casemap :none      ; case sensitive

      include \masm32\include\dialogs.inc
      include simple.inc                      ; Useful Macros

      dlgproc PROTO :DWORD,:DWORD,:DWORD,:DWORD   ;Prototipe

    .code
; ����������������������������������������������������������������������CodeBegin
start:
      mov hInstance, FUNC(GetModuleHandle,NULL)
      call main
      invoke ExitProcess,eax                             ;����� � �� ����������
; �������������������������������������������������������������������������Main
main proc

    Dialog "Simple Pipe","MS Sans Serif",10, \              ; caption,font,������ ������
            WS_OVERLAPPED or WS_SYSMENU or DS_CENTER, \     ; style - ����� ����
            5, \                                            ; control count - ���������� ��� �������
            50,50,155,100, \                                ; x y ����������
            1024                                            ; memory buffer size

    DlgEdit   ES_LEFT or WS_BORDER or WS_TABSTOP,17,20,121,11,301        ;  id = 301   edit box
    DlgButton "About",WS_TABSTOP,55,6,30,11,IDOK
    DlgButton "&Server",WS_TABSTOP,58,45,40,15,IDYES
    DlgButton "&Client",WS_TABSTOP,100,45,40,15,IDNO
    DlgStatic "For exit press Alt-F4",SS_LEFT,6,80,135,11,100            ;  id = 100  status/inform line

    CallModalDialog hInstance,0,dlgproc,NULL            ;���� ������ ��� � ���� CallModalDialog
                                                        ; ��������� main ������������� ����� 
    ret                                                 ; ���������� ����� �� ������������ ����� dlgproc 
                                                        ; �� ������ EndDialog � ���.
main endp                                               ;���������� call main

;-----------------------------------------------------data_section------------
.data
   NamedPipeIn db "\\.\pipe\MyFifoPipe", 0     ;  ��� ������
   sAbout db "Simple GUI with 3 buttons.",13,10,"Server, Client, About.",0
   nBytes dd 0  ;number of bytes written into pipe
   fmt    db "%d",0   ;������ ��� �������������� � ������

  sErrNum  db "ErrNum:"    ;��������� ������, ������ ������
  sErr     db  16 dup(0)   ;����� ������ ��������� ���������� ������, ��������� ���������
  nErr     dd 0            ;����� ������ ������ � �������� ����

  sGotMess db "I'v Got bytes:"
    sGots  db 16 dup(0)   ;���������� ���� - ���������� ���������
    nGots  dd 0            ;�������� �����
;-data???????????????????????????????????????????????????????????????????????????
.Data?                 ;CUSTOM .DATA?
  hFile_data dd ?      ;����� ����������� ����� � ������
  hPipeIn    dd ?        ;����� ������ �������
  OpenMode   dd ? ;
  PipeMode   dd ? ;

  bufGet     db 256 dup(?)   ;����� ������ ��� �������
  bufMessage db 256 dup(?)   ;����� ��� �������� �� ���� ����� � ����� �������� � pipe-�����
    lenMes   dd ?            ;����� ��������� 
    buffer   db 64 dup(?)   ;��� ������ ����������� �������� 301 (���� ����� ������)
;*****************************************************************************CODE*****
.code

dlgproc proc hWin:DWORD,uMsg:DWORD,wParam:DWORD,lParam:DWORD
   
    .if uMsg == WM_INITDIALOG                                                ;������������� ���� �������
      invoke SendMessage,hWin,WM_SETICON,1,FUNC(LoadIcon,NULL,IDI_ASTERISK)  ;���������� ������ ���������*

    .elseif uMsg == WM_COMMAND        ;uMsg - ������� � ���� �������
      .if wParam == IDCANCEL          ; ��� ������� �� ������, id ������ � wparam
        ret                           ; ���� ������ � ������� ��� (wParam == IDCANCEL)
      .elseif wParam == IDOK          ; ������ About
         fn MessageBox,0, offset sAbout ,"About",MB_OK    ; ���� � ���������� About! � ������ sAbout
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      .elseif wParam == IDYES                             ;  ������ Server ������ �_1
;-------------------------------------------------------------------------------------------------
     ; ������������� ���������� ������
      mov OpenMode, PIPE_ACCESS_DUPLEX   
      mov eax,PIPE_TYPE_BYTE + PIPE_READMODE_BYTE + PIPE_WAIT  ;PIPE_TYPE_MESSAGE + PIPE_READMODE_MESSAGE + PIPE_WAIT
                                                               ; PIPE_WAIT - ����������� �����, � ���������
      mov PipeMode,eax                   
      invoke CreateNamedPipe, ADDR NamedPipeIn, OpenMode, PipeMode, 1 , 1024, 1024, 0, NULL      ; 1 �����
      ; ����� ������
      .IF eax != INVALID_HANDLE_VALUE   ;not(-1), �������� ������ � eax
        mov hPipeIn, eax                ; � ���������� ���
        fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, "Pipe server created (this process is a server)"  ;offset sYes
      .ELSE  ;-1 = ������� �����
        fn MessageBox,0, "Invalid handle (-1) for this pipe" ,"Error",MB_OK     
        fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, "Invalid handle of created pipe"
       ret
      .ENDIF
      ;�������� � ������� ������ ����������.
      fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, "Waiting for client"
      invoke Sleep, 250
      invoke ConnectNamedPipe, hPipeIn, NULL    ;���� ����������� �������
      ;����� ���� ������ ����� ������ ���������. ����� ����� ������ ��������� ���������)
      fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, "client is online"
      invoke Sleep, 250

      mov ebx, rv(GetDlgItemText,hWin,301,offset buffer,20)    ;������ 20 �������� �� �����
      ;���������� �������� � ebx
       .IF eax == 0    
         invoke GetLastError    ; ��������� ��������� ������, �������� ����� ������ ����� ���������� ������
         mov nErr,eax                                ;�������� �
         invoke wsprintf, addr sErr, addr fmt, eax   ;������������� � ������
         fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, offset sErrNum  ;������� ��������� � ������
         invoke Sleep, 1500
      .ENDIF

       invoke wsprintf, addr sGots, addr fmt, ebx   ;������� ����� ���� � ��������� ���
       fn SendMessage,rv(GetDlgItem,hWin,100), WM_SETTEXT,0, offset sGotMess ;������� ���� ����������
       invoke Sleep, 500
       fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, offset buffer ;�����. � ������
       invoke Sleep, 500
       invoke WriteFile,hPipeIn,offset buffer,sizeof buffer,offset nBytes,0h
       ; ��������� ����� � pipe �����
         fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, "writing message to client"
         invoke CloseHandle,hPipeIn  ;������� �����
         invoke Sleep, 500
         fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, "OK. pipe closed. Ready"
       ret

;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
      .elseif wParam == IDNO                                          ;  ������ Client #2
;--------------------------------------------------------------------------------------------!!!
; The server has to be running and waiting for the client before the client can start
;----------------------------------------------------------------------------------------!!!
;   Read from the pipe.                                

    invoke CreateFile, offset NamedPipeIn,GENERIC_READ or GENERIC_WRITE,0,NULL,OPEN_EXISTING,0,NULL

      .IF eax != INVALID_HANDLE_VALUE   ; eax != (-1)
        mov hFile_data,eax              ; ����� ��������� �������� ����� ������� CreateFile ������ � eax
      .ELSE
        fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, "Invalid handle of pipe for read"
        invoke Sleep, 1500                                   ;�� ������ ������� � ������
        ret
      .ENDIF

      invoke SetNamedPipeHandleState, hFile_data, PIPE_READMODE_BYTE, NULL,NULL  ;����� ������ ����������

      invoke ReadFile,hFile_data,offset bufGet ,125,offset nGots,0h     ;nGots - ���������� ����=125
       .IF eax != 0      ;TRUE - ��� ���������, � eax = 1/0 ��������� ������� ReadFile
         invoke lstrlen, offset bufGet ; eax - ����� ������
         invoke wsprintf, addr sGots, addr fmt, eax   ;������� ����� � ������
         fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, offset sGotMess
      .ELSE                     ;eax ==0, False -- error!!
         invoke GetLastError    ; ��������� ��������� ������, �������� ����� ������ ��������� ��������
         mov nErr,eax                                ;�������� �, �� ��� ������
         invoke wsprintf, addr sErr, addr fmt, eax   ;������������� ����� eax � ������ �� ������� fmt
         fn SendMessage,rv(GetDlgItem,hWin,100),WM_SETTEXT,0, offset sErrNum  ;������� ��������� � ������
      .ENDIF

       invoke CloseHandle,hFile_data           ; ������� ���� ������� � ������ pipe
       fn SendMessage,rv(GetDlgItem,hWin,301),WM_SETTEXT,0, offset bufGet  
       ret
      .endif

    .elseif uMsg == WM_CLOSE        ; ��� ��������� ��������� � �������� ����, ����� �� �������
      quit_dialog:
      invoke EndDialog,hWin,0

    .endif
    xor eax, eax
    ret
dlgproc endp
; ������������������������������ ��������� �� ����� ����� ��start������������������������������������
end start
;�����.