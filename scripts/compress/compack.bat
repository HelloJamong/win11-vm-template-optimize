@echo off
setlocal

if "%~1"=="" (
    echo 사용법: %~nx0 ^<압축할 파일 경로^>
    echo 예시: %~nx0 ^<VM_IMAGE_PATH^>\win11-template.vhdx
    echo 설명: 입력 파일을 같은 폴더에 .pck 확장자로 압축합니다.
    echo 조건: 7z.exe와 7z.dll이 이 배치 파일과 같은 폴더에 있어야 합니다.
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
set "INPUT=%~1"
set "OUTPUT=%~dpn1.pck"

if not exist "%INPUT%" (
    echo 입력 파일을 찾을 수 없습니다: %INPUT%
    exit /b 1
)

if not exist "%SCRIPT_DIR%7z.exe" (
    echo 7z.exe를 찾을 수 없습니다: %SCRIPT_DIR%7z.exe
    exit /b 1
)

if not exist "%SCRIPT_DIR%7z.dll" (
    echo 7z.dll을 찾을 수 없습니다: %SCRIPT_DIR%7z.dll
    exit /b 1
)

"%SCRIPT_DIR%7z.exe" a "%OUTPUT%" "%INPUT%" -t7z -m0=lzma2 -mx=9 -mmt=on -md=128m -ms=on

if errorlevel 1 (
    echo 압축에 실패했습니다.
    exit /b 1
)

echo 압축 완료: %OUTPUT%
endlocal
