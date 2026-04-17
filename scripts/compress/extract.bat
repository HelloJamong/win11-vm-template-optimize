@echo off
setlocal

if "%~1"=="" (
    echo 사용법: %~nx0 ^<복원할 .pck 파일 경로^>
    echo 예시: %~nx0 ^<VM_IMAGE_PATH^>\win11-template.pck
    echo 설명: .pck 파일을 현재 폴더 또는 압축 파일 경로 기준으로 해제합니다.
    echo 조건: 7z.exe와 7z.dll이 이 배치 파일과 같은 폴더에 있어야 합니다.
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
set "INPUT=%~1"
set "OUTPUT_DIR=%~dp1"

if not exist "%INPUT%" (
    echo 입력 파일을 찾을 수 없습니다: %INPUT%
    exit /b 1
)

if /I not "%~x1"==".pck" (
    echo 경고: 입력 파일 확장자가 .pck가 아닙니다: %~x1
)

if not exist "%SCRIPT_DIR%7z.exe" (
    echo 7z.exe를 찾을 수 없습니다: %SCRIPT_DIR%7z.exe
    exit /b 1
)

if not exist "%SCRIPT_DIR%7z.dll" (
    echo 7z.dll을 찾을 수 없습니다: %SCRIPT_DIR%7z.dll
    exit /b 1
)

"%SCRIPT_DIR%7z.exe" x "%INPUT%" -o"%OUTPUT_DIR%" -y

if errorlevel 1 (
    echo 압축 해제에 실패했습니다.
    exit /b 1
)

echo 압축 해제 완료: %OUTPUT_DIR%
endlocal
