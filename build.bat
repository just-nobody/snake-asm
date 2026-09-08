@echo off
setlocal
cd /d "%~dp0"
set "INCLUDE=%~dp0fasm\INCLUDE"
"%~dp0fasm\FASM.EXE" snake.asm snake.exe
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [Error] Compile finished with error!
    exit /b %ERRORLEVEL%
)
echo.
echo [Done] snake.exe succseful compiled!
endlocal
