@echo off

if exist "simple.obj" del "simple.obj"
if exist "simple.exe" del "simple.exe"


\masm32\bin\ml /c /coff "simple.asm"

\masm32\bin\Link /SUBSYSTEM:WINDOWS "simple.obj"

dir "simple.*"

:TheEnd
 
pause
