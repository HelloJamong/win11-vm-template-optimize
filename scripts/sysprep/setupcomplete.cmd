@echo off
::
:: setupcomplete.cmd
:: Windows Setup 완료 후 자동 실행 (최초 로그인 전, SYSTEM 권한)
:: 배치 위치: C:\Windows\Setup\Scripts\SetupComplete.cmd
::
:: 역할:
::   - 로그 디렉터리 확보
::   - Scripts 폴더 확보 (first_logon.ps1 실행 경로와 일치)
::   - PowerShell 실행 정책을 LocalMachine 범위로 허용
::     (FirstLogonCommands 는 Process 범위로 Bypass 를 전달하지만
::      LocalMachine 정책이 AllSigned 이면 차단될 수 있으므로 사전 완화)
::
:: 주의: SetupComplete.cmd 는 한 번만 실행됩니다.
::       C:\Windows\Setup\Scripts\ 폴더가 없으면 자동 실행되지 않습니다.
::

setlocal

:: 로그 / Scripts 디렉터리 확보
if not exist "C:\Windows\Logs" mkdir "C:\Windows\Logs"
if not exist "C:\Windows\Setup\Scripts" mkdir "C:\Windows\Setup\Scripts"

:: PowerShell 실행 정책 완화 (LocalMachine)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force" ^
    >nul 2>&1

echo [%DATE% %TIME%] SetupComplete.cmd 완료 >> "C:\Windows\Logs\setupcomplete.log"

endlocal
