#requires -RunAsAdministrator
<#
.SYNOPSIS
    VM 템플릿 최초 로그인 초기화 스크립트

.DESCRIPTION
    unattend.xml FirstLogonCommands 에 의해 OOBE 후 최초 로그인 시 자동 실행됩니다.
    CopyProfile 로 복사되지 않는 설정을 보완하고,
    사용자 데이터 폴더를 D:\UserData 로 리디렉션합니다.

    수행 순서:
      1. 재실행 방지 확인
      2. D:\UserData\{사용자명} 폴더 구조 생성
      3. 쉘 폴더 리디렉션 (D 드라이브)
      4. Appx / Provisioned Appx 제거
      5. HKCU 설정 재적용
      6. Explorer 재시작
      7. 재실행 방지 플래그 설정

.NOTES
    - 프로필 경로(C:\Users\{사용자명})는 변경하지 않습니다.
    - 데이터 경로(Desktop/Documents 등)만 D:\UserData 로 리디렉션합니다.
    - D 드라이브가 없는 환경에서는 리디렉션을 건너뜁니다.
    - 로그: C:\Windows\Logs\first_logon.log
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8
$ErrorActionPreference    = 'SilentlyContinue'

# ──────────────────────────────────────────────────────────────────────
# 로그 함수
# ──────────────────────────────────────────────────────────────────────
$LogFile = 'C:\Windows\Logs\first_logon.log'

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','SUCCESS')]
        [string]$Level = 'INFO'
    )
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
    Write-Host $line
}

# ──────────────────────────────────────────────────────────────────────
# 재실행 방지: 이미 완료된 경우 즉시 종료
# ──────────────────────────────────────────────────────────────────────
$FlagRegPath = 'HKCU:\Software\VMTemplateSetup'
$FlagName    = 'FirstLogonComplete'

if ((Get-ItemProperty -Path $FlagRegPath -Name $FlagName -ErrorAction SilentlyContinue).$FlagName -eq 1) {
    Write-Log '이미 실행 완료됨. 종료합니다.' 'INFO'
    exit 0
}

Write-Log '=== VM 템플릿 최초 로그인 초기화 시작 ===' 'INFO'
Write-Log "사용자: $env:USERNAME  /  컴퓨터: $env:COMPUTERNAME" 'INFO'

# ──────────────────────────────────────────────────────────────────────
# 헬퍼: 레지스트리 값 설정
# ──────────────────────────────────────────────────────────────────────
function Set-RegValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = 'DWord'
    )
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
    } catch {
        Write-Log "레지스트리 설정 실패: $Path \ $Name — $_" 'WARN'
    }
}

# ──────────────────────────────────────────────────────────────────────
# 1. D:\UserData\{사용자명} 폴더 구조 생성
#    D 드라이브가 없으면 이 섹션과 이후 리디렉션 섹션을 건너뜁니다.
# ──────────────────────────────────────────────────────────────────────
$DataDrive  = 'D:'
$DataRoot   = "$DataDrive\UserData\$env:USERNAME"
$SubFolders = @('Desktop', 'Documents', 'Downloads', 'Pictures', 'Videos', 'Music')
$DriveReady = Test-Path $DataDrive

if ($DriveReady) {
    Write-Log "D 드라이브 확인됨. 데이터 폴더 생성: $DataRoot" 'INFO'
    foreach ($sub in $SubFolders) {
        $target = Join-Path $DataRoot $sub
        if (-not (Test-Path $target)) {
            try {
                New-Item -ItemType Directory -Path $target -Force | Out-Null
                Write-Log "생성: $target" 'INFO'
            } catch {
                Write-Log "생성 실패: $target — $_" 'WARN'
            }
        }
    }
} else {
    Write-Log 'D 드라이브 없음. 폴더 생성 및 리디렉션을 건너뜁니다.' 'WARN'
}

# ──────────────────────────────────────────────────────────────────────
# 2. 쉘 폴더 리디렉션 (D:\UserData 로)
#
#    방식: User Shell Folders 레지스트리 키 변경
#      - C:\Users\{사용자명} 프로필 위치는 그대로 유지
#      - Desktop/Documents/Downloads 등 실제 데이터 경로만 D 로 이동
#
#    Downloads 는 Known Folder GUID 키 이름을 사용해야 합니다.
#    {374DE290-123F-4565-9164-39C4925E467B} = Downloads
# ──────────────────────────────────────────────────────────────────────
if ($DriveReady) {
    Write-Log '쉘 폴더 리디렉션 적용' 'INFO'

    $UserShellKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    $ShellKey     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders'

    # (레지스트리 키 이름, 서브폴더 이름)
    $redirections = @(
        @{ Key = 'Desktop';                                 Sub = 'Desktop'   }
        @{ Key = 'Personal';                                Sub = 'Documents' }
        @{ Key = '{374DE290-123F-4565-9164-39C4925E467B}'; Sub = 'Downloads' }
        @{ Key = 'My Pictures';                             Sub = 'Pictures'  }
        @{ Key = 'My Video';                                Sub = 'Videos'    }
        @{ Key = 'My Music';                                Sub = 'Music'     }
    )

    foreach ($r in $redirections) {
        $newPath = Join-Path $DataRoot $r.Sub
        try {
            # ExpandString(REG_EXPAND_SZ): 환경변수 포함 경로에 권장
            Set-ItemProperty -Path $UserShellKey -Name $r.Key -Value $newPath -Type ExpandString -Force
            # String(REG_SZ): 확장 완료된 절대 경로
            Set-ItemProperty -Path $ShellKey     -Name $r.Key -Value $newPath -Type String       -Force
            Write-Log "리디렉션: $($r.Key) → $newPath" 'INFO'
        } catch {
            Write-Log "리디렉션 실패: $($r.Key) — $_" 'WARN'
        }
    }
}

# ──────────────────────────────────────────────────────────────────────
# 3. Appx 및 Provisioned Appx 제거
#    - Get-AppxPackage: 현재 사용자 / AllUsers 설치 앱
#    - Get-AppxProvisionedPackage: 신규 사용자 자동 설치 패키지 (프로비전)
#    두 계층 모두 처리해야 재배포 시에도 앱이 재설치되지 않습니다.
# ──────────────────────────────────────────────────────────────────────
Write-Log 'Appx 앱 제거 시작' 'INFO'

$AppxPatterns = @(
    '*Xbox*'
    '*GamingApp*'
    '*XboxGameOverlay*'
    '*XboxGamingOverlay*'
    '*XboxIdentityProvider*'
    '*XboxSpeechToTextOverlay*'
    '*YourPhone*'
    '*CrossDevice*'
    '*Copilot*'
    '*MicrosoftTeams*'
    '*Clipchamp*'
)

foreach ($pattern in $AppxPatterns) {
    # 현재 사용자 Appx
    Get-AppxPackage -Name $pattern -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue
            Write-Log "Appx 제거: $($_.Name)" 'INFO'
        } catch {
            Write-Log "Appx 제거 실패: $($_.Name) — $_" 'WARN'
        }
    }

    # AllUsers Appx
    Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
            Write-Log "Appx(AllUsers) 제거: $($_.Name)" 'INFO'
        } catch {
            Write-Log "Appx(AllUsers) 제거 실패: $($_.Name) — $_" 'WARN'
        }
    }

    # Provisioned Appx (신규 사용자 자동 설치 차단)
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like $pattern } |
        ForEach-Object {
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
                Write-Log "ProvisionedAppx 제거: $($_.DisplayName)" 'INFO'
            } catch {
                Write-Log "ProvisionedAppx 제거 실패: $($_.DisplayName) — $_" 'WARN'
            }
        }
}

# ──────────────────────────────────────────────────────────────────────
# 4. HKCU 설정 재적용
#
#    CopyProfile 은 Audit Mode 시점의 HKCU 를 복사하지만,
#    일부 설정은 신규 사용자 생성 시 시스템 기본값으로 덮어써집니다.
#    이 섹션에서 명시적으로 재적용해 설정을 확정합니다.
#
#    HKLM 기반 정책(AllowTelemetry 등)은 win11_master_template_optimize.ps1 에서
#    Audit Mode 중에 이미 적용되어 있으므로 여기서는 HKCU 항목만 처리합니다.
# ──────────────────────────────────────────────────────────────────────
Write-Log 'HKCU 설정 재적용' 'INFO'

# 웹 검색 / Bing / Cortana 비활성화
Set-RegValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
Set-RegValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'DisableWebSearch'  1
Set-RegValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent'    0
Set-RegValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 1
Write-Log '웹 검색 / Bing / Cortana 비활성화' 'INFO'

# Copilot 비활성화
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton'      0
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\WindowsCopilot'    'TurnOffWindowsCopilot'  1
Write-Log 'Copilot 비활성화' 'INFO'

# 작업 표시줄 위젯(날씨/뉴스) 비활성화
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0
Write-Log '작업 표시줄 위젯 비활성화' 'INFO'

# 소비자 기능(Consumer Experience) 비활성화 — HKCU 측
#   추천 앱 자동 설치, 잠금화면 팁, 시작 메뉴 광고 등
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SilentInstalledAppsEnabled'      0
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SystemPaneSuggestionsEnabled'    0
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled' 0
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338388Enabled' 0
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353698Enabled' 0
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'ContentDeliveryAllowed'          0
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'OemPreInstalledAppsEnabled'      0
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'PreInstalledAppsEnabled'         0
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'PreInstalledAppsEverEnabled'     0
Write-Log '소비자 기능(Consumer Experience) 비활성화' 'INFO'

# 텔레메트리 진단 맞춤 경험 비활성화 (HKCU 측)
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
Write-Log '텔레메트리 맞춤 경험 비활성화(HKCU)' 'INFO'

# 탐색기 최근 항목 / 자주 사용한 항목 비활성화
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_TrackProgs' 0
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_TrackDocs'  0
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'          'ShowFrequent'     0
Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'          'ShowRecent'       0
Write-Log '탐색기 최근/자주 사용 항목 비활성화' 'INFO'

# ──────────────────────────────────────────────────────────────────────
# 5. Explorer 재시작
#    쉘 폴더 리디렉션 변경 사항을 즉시 반영합니다.
# ──────────────────────────────────────────────────────────────────────
Write-Log 'Explorer 재시작' 'INFO'
try {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
    Write-Log 'Explorer 재시작 완료' 'INFO'
} catch {
    Write-Log "Explorer 재시작 실패 (무시) — $_" 'WARN'
}

# ──────────────────────────────────────────────────────────────────────
# 6. 재실행 방지 플래그 설정
#    다음 로그인부터 이 스크립트가 재실행되지 않도록 HKCU 에 플래그를 씁니다.
# ──────────────────────────────────────────────────────────────────────
try {
    if (-not (Test-Path $FlagRegPath)) { New-Item -Path $FlagRegPath -Force | Out-Null }
    Set-ItemProperty -Path $FlagRegPath -Name $FlagName -Value 1 -Type DWord -Force
    Write-Log '재실행 방지 플래그 설정 완료' 'INFO'
} catch {
    Write-Log "플래그 설정 실패 — $_" 'WARN'
}

Write-Log '=== VM 템플릿 최초 로그인 초기화 완료 ===' 'SUCCESS'
