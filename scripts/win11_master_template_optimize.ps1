#requires -RunAsAdministrator
# 위 선언은 "관리자 권한으로 실행되어야 함"을 의미합니다.
# 제거하면 일반 권한 실행 시 일부 정리/정책/서비스 변경이 실패할 수 있습니다.

<#
.SYNOPSIS
    Windows 11 VM 마스터 템플릿 최적화 스크립트입니다.

.DESCRIPTION
    Audit Mode에서 Sysprep 전 실행하는 PowerShell 중심 단일 파일 최적화 스크립트입니다.
    별도 프로필 ps1 없이 이 파일 하나에서 모든 최적화를 수행합니다.
    외부 실행 도구 의존 없이 Windows 기본 명령과 PowerShell cmdlet만 사용합니다.

.USAGE
    .\win11_master_template_optimize.ps1

.NOTES
    - 각 단계마다 수행 항목을 표시하고 Y/n으로 진행 여부를 선택하는 인터랙티브 모드가 기본값입니다.
    - 이벤트 로그 삭제, Appx 제거, 서비스 비활성화는 감사/업무 영향이 있을 수 있습니다.
    - 앱/서비스/예약 작업 후보는 configs 디렉터리의 목록 파일과 스크립트 기본 후보를 함께 사용합니다.
#>

# PowerShell 5.x(Windows PowerShell)에서 한글 깨짐 방지: 콘솔 입출력 인코딩을 UTF-8로 고정합니다.
# 파일 자체도 UTF-8 with BOM으로 저장해야 Windows PowerShell 5.x에서 한글이 정상 표시됩니다.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

$Script:Interactive = $true

$ErrorActionPreference = 'SilentlyContinue'
# 일부 항목이 없거나 삭제에 실패해도 전체 중단하지 않고 계속 진행합니다.
# 엄격한 검증이 필요하면 개별 함수 내부의 로그와 Windows 이벤트/PowerShell 오류를 함께 확인하십시오.

$Script:RootDir = Split-Path -Parent $PSScriptRoot
# 배포 환경(스크립트와 configs/ 동일 레벨)과 개발 환경(scripts/ 하위) 모두 지원
$Script:ConfigDir = if (Test-Path (Join-Path $PSScriptRoot 'configs')) {
    Join-Path $PSScriptRoot 'configs'
} else {
    Join-Path $Script:RootDir 'configs'
}
$Script:LogFile = Join-Path $env:SystemDrive 'win11_template_optimize.log'

# =========================================================
# Windows 11 VM Master Template Optimization Script
# 참고 방향:
# - 수동 템플릿 정리 항목
# - VDI/가상 데스크톱 성능 최적화 개념
# - Windows 11 불필요 앱/정책 정리 개념
# - 유용한 Windows 튜닝 옵션 분류 개념
# =========================================================

# -----------------------------
# Options
# -----------------------------
# 아래 옵션은 기능별 ON/OFF 스위치입니다.
# 아래 옵션은 기능별 ON/OFF 스위치입니다. 필요 시 직접 수정하여 사용하십시오.

$EnableTempCleanup                 = $true
# 시스템/사용자 Temp, 캐시, 일부 로그를 정리합니다.
# false로 바꾸면 정리 범위가 줄어들고 최종 용량 감소 효과가 약해집니다.

$EnableInstallerResidueCleanup     = $true
# Windows Installer 패치 캐시, Package Cache, WER 등 프로그램 설치/오류 보고 잔여물을 정리합니다.
# 최종 봉인 직전 템플릿 용량과 흔적을 줄이는 목적이며, 문제 분석 또는 프로그램 복구/제거 원본 캐시가 필요하면 false로 되돌리십시오.

$EnableUpdateCacheCleanup          = $true
# Windows Update 다운로드 캐시, Delivery Optimization 캐시를 정리합니다.
# false로 바꾸면 업데이트 찌꺼기가 남아 용량 증가 요인이 됩니다.

$EnableDefenderCleanup             = $true
# Defender 검사 이력/임시 캐시 일부를 정리합니다.
# false로 바꾸면 보안 검사 흔적은 남지만 용량이 조금 더 남습니다.

$EnableEventLogClear               = $true
# 이벤트 로그를 초기화합니다.
# 공공기관 템플릿에는 유용하지만, 문제 분석용 로그가 필요하면 false 권장.

$EnableHibernationOff              = $true
# 최대 절전 모드를 끄고 hiberfil.sys를 제거합니다.
# false면 수 GB 용량이 남을 수 있습니다.

$EnableCleanMgr                    = $true
# Windows 기본 디스크 정리(cleanmgr)를 실행합니다.
# false여도 동작은 하지만 정리 폭이 줄어듭니다.

$EnableDismCleanup                 = $true
# DISM으로 WinSxS/컴포넌트 저장소를 정리합니다.
# 템플릿 용도라면 true 권장이나, /resetbase로 업데이트 롤백 여지가 줄어듭니다.

$EnableAppxRemoval                 = $true
# 현재 설치된 사용자 기준 Appx 앱 제거를 시도합니다.
# false면 Xbox, Copilot, Phone Link 등 앱 제거가 수행되지 않습니다.

$EnableProvisionedAppxRemoval      = $true
# 앞으로 생성될 새 사용자에게 기본 앱이 다시 설치되지 않도록 Provisioned Appx 제거를 수행합니다.
# false면 현재 계정에서는 없어도 새 계정 생성 시 앱이 다시 나타날 수 있습니다.

$EnableServiceOptimization         = $true
# 일부 서비스 비활성화를 수행합니다.
# false면 성능/백그라운드 I/O 최적화 효과가 줄어듭니다.

$EnableScheduledTaskOptimization   = $true
# CEIP, Telemetry 성격의 스케줄 작업 일부를 비활성화합니다.
# false면 로그/백그라운드 작업이 더 많이 남을 수 있습니다.

$EnableSearchTweaks                = $true
# Bing 검색, 웹 검색, 클라우드 검색 연계를 끕니다.
# false면 Windows 검색이 웹/클라우드와 더 강하게 연동될 수 있습니다.

$EnableConsumerTweaks              = $true
# Windows 추천/광고/Consumer Experience 성격 기능을 줄입니다.
# false면 시작 메뉴 추천/제안성 요소가 더 남을 수 있습니다.

$EnableCopilotTweaks               = $true
# Copilot 정책 비활성화를 적용합니다.
# false면 Copilot 관련 정책 차단을 하지 않습니다.

$EnableRecallTweaks                = $true
# 최신 Windows의 AI/Recall 성격 설정을 보수적으로 차단합니다.
# 빌드에 따라 무시될 수 있으나, 있어도 무방한 보수적 차단입니다.

$EnablePrivacyTweaks               = $true
# Telemetry, 광고 ID, 피드백 알림 등 프라이버시 관련 정책을 낮춥니다.
# false면 수집/광고 관련 기본 정책이 더 살아있을 수 있습니다.

$EnablePrivacyGeneralTweak         = $true
# 개인 정보 및 보안 > 일반/권장 사항 항목을 조정합니다.
# 언어 목록 웹 공유 끔, 설정 알림 끔, 장치 검색 기록 비활성화 및 초기화.

$EnableSignInOptionsTweak          = $true
# 업데이트/재시작 후 로그인 정보를 이용한 자동 설정 완료(ARSO)를 비활성화합니다.
# false면 Windows 기본 동작(업데이트 후 자동 로그인 완료)이 유지됩니다.

$EnableTaskbarEndTaskTweak         = $true
# 작업 표시줄 우클릭 메뉴에 '작업 종료' 항목을 표시합니다.
# false면 작업 표시줄에서 직접 프로세스를 종료하는 메뉴가 표시되지 않습니다.

$EnableAppRestartTweak             = $true
# 로그인 시 앱 자동 재시작을 비활성화합니다.
# false면 Windows 기본 동작(로그인 후 이전 앱 자동 재시작)이 유지됩니다.

$EnableExplorerTweaks              = $true
# Explorer 알림/동기화 알림과 일부 UI 기본값을 조정합니다.
# false면 UI 관련 기본값이 원래 상태에 가깝게 유지됩니다.

$EnablePowerPlanTweaks             = $true
# VM 템플릿에 적합하도록 고성능 전원 계획과 절전/화면 꺼짐 시간 제한을 조정합니다.
# 노트북 실사용 이미지나 절전 정책이 있는 조직에서는 false를 검토하십시오.

$EnableExplorerPrivacyCleanup      = $true
# 파일 탐색기 최근 항목, 실행 기록, 입력 경로 등 사용자 흔적성 데이터를 정리하고 재표시를 제한합니다.
# 템플릿 마감 전 흔적 최소화 목적에 적합합니다.

$EnableStartMenuTweaks             = $true
# 시작 메뉴의 최근/추천/계정 알림성 표시를 줄입니다.
# 사용자 경험 변경이 있으므로 조직 표준 UI가 있으면 검토하십시오.

$EnableStartPersonalizationTweak   = $true
# 개인설정 > 시작 항목을 조정합니다.
# 팁/바로가기 권장 사항 끔, 계정 알림 끔, 전원 버튼 옆 폴더(설정/파일 탐색기/다운로드) 활성화.

$EnableTaskbarAndNotificationTweaks = $true
# Widgets, Task View, Windows 환영/추천/팁 알림을 줄입니다.
# 공공기관/망분리 환경의 불필요한 소비자 경험 축소 목적입니다.

$EnableLockScreenContentTweaks     = $true
# 잠금화면 Spotlight, 팁, 추천 콘텐츠, 슬라이드쇼성 표시를 줄입니다.
# 조직 표준 잠금화면 정책이 별도로 있으면 GPO가 우선할 수 있습니다.

$EnableDeliveryOptimizationTweaks  = $true
# Delivery Optimization의 외부 공유 성격을 줄입니다.
# false면 업데이트 공유/캐시 관련 기본 동작이 더 남을 수 있습니다.

$EnableOneDriveRemoval             = $true
# OneDrive 제거 시도 옵션입니다.
# 조직 정책이나 특정 업무 요구가 있으면 false로 변경하십시오.

$EnableEdgeTweaks                  = $true
# VDOT 기준 Edge Chromium 정책 키를 적용합니다.
# 백그라운드 실행, 시작 부스트, 첫 실행 화면, 위젯, 텔레메트리 등을 비활성화합니다.

$EnablePagefileDisable             = $false
# pagefile 자동 관리를 끄고 pagefile 삭제를 시도합니다.
# 재부팅/추가 검증이 필요할 수 있어 기본 false로 둡니다.

$EnableOptionalFeatureDisable      = $false
# 일부 Windows Optional Feature를 비활성화합니다.
# 잘못 끄면 기능 호환성에 영향이 있을 수 있어 기본 false 권장.

$EnableDownloadsDesktopCleanup     = $false
# 사용자 Downloads/Desktop 내용까지 비웁니다.
# 설치 파일 잔여물 정리에 유용하지만, 의도적으로 둔 파일도 같이 지워질 수 있어 기본 false입니다.

$EnableCompactOS                   = $false
# CompactOS를 적용합니다.
# 용량은 줄 수 있지만 성능/관리/업데이트 측면 변수가 있어 기본 false 권장입니다.

$EnableSetupLogCleanup             = $true
# Panther, Sysprep Panther, CBS/DISM 로그 등 설치/배포 분석 로그를 정리합니다.
# 최종 봉인 직전 템플릿 흔적 최소화 목적입니다.
# Sysprep/Setup 문제 분석이 필요한 검증 단계에서는 false로 되돌리십시오.

$EnableResetBase                   = $true
# DISM /StartComponentCleanup 실행 시 /ResetBase를 함께 사용합니다.
# 용량 절감 효과가 크지만 기존 업데이트 롤백 가능성이 줄어듭니다.

$EnableDefragFreeSpace             = $false
# defrag /X 로 여유 공간을 통합합니다. VHD compact 전 압축률 향상에 유효합니다.
# 소요 시간이 길고 SSD/NVMe 기반 VM에서는 불필요하므로 기본 false입니다.

$EnableControlPanelViewTweak       = $true
# 제어판 보기 기준을 '큰 아이콘'으로 변경합니다.

$EnableBootTimeoutTweak            = $true
# 시작 및 복구: 운영 체제 목록 표시 시간을 3초로 설정합니다. (bcdedit /timeout 3)

$EnableSystemVolumeTweak           = $true
# 시스템 기본 볼륨을 50%로 설정합니다. Windows Core Audio API 사용.

$EnableComputerRename              = $true
# 컴퓨터 이름을 VDI-Win11로 변경합니다. Sysprep 전 적용 권장. (재부팅 필요)

$EnableVisualEffectsTweak          = $true
# 성능 옵션 시각 효과를 Custom 모드로 설정합니다.
# 켜는 항목: 아이콘 레이블 그림자 / 미리 보기 / 창 아래 그림자 / 글꼴 가장자리 다듬기(ClearType)

$EnableDesktopIcons                = $true
# 바탕화면에 '내 PC'와 '제어판' 시스템 아이콘을 표시합니다.
# HideDesktopIcons 레지스트리 키를 통해 설정합니다.

$EnableStartMenuPinnedCleanup      = $true
# 시작 메뉴 고정 항목을 Edge / 파일 탐색기 / 설정 3개만 남기고 모두 제거합니다.
# LayoutModification.json 을 작성해 적용합니다.


# -----------------------------
# Logging
# -----------------------------
function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')][string]$Level = 'INFO'
    )

    $time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$time] [$Level] $Message"
    Write-Host $line

    try {
        Add-Content -Path $Script:LogFile -Value $line -Encoding UTF8
    }
    catch {
        $Script:LogFile = Join-Path $env:TEMP 'win11_template_optimize.log'
        Add-Content -Path $Script:LogFile -Value $line -Encoding UTF8
    }
}
# 화면 출력 + 로그 파일 저장을 동시에 수행합니다.
# 문제 발생 시 어떤 작업까지 진행됐는지 확인하는 용도입니다.

# -----------------------------
# Interactive Confirm
# -----------------------------
function Confirm-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [string[]]$Details = @()
    )

    if (-not $Script:Interactive) { return $true }

    Write-Host ''
    Write-Host ('=' * 60) -ForegroundColor DarkCyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ('=' * 60) -ForegroundColor DarkCyan

    if ($Details.Count -gt 0) {
        foreach ($d in $Details) {
            Write-Host "  - $d" -ForegroundColor Gray
        }
    }

    Write-Host ''
    $answer = Read-Host '  진행하시겠습니까? [Y/n]'
    $proceed = ($answer -eq '' -or $answer -match '^[Yy]')

    if (-not $proceed) {
        Write-Host "  -> 건너뜁니다: $Title" -ForegroundColor Yellow
        Write-Log "사용자가 건너뜀: $Title" 'WARN'
    }

    return $proceed
}
# --interactive 모드일 때만 프롬프트를 표시합니다.
# 비대화형 실행(스크립트/자동화)에서는 항상 true를 반환합니다.
# 엔터 입력(기본값) 또는 Y/y는 진행, n/N은 건너뜁니다.

# -----------------------------
# Helpers
# -----------------------------
function Read-ListFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Log "목록 파일을 찾을 수 없습니다: $Path" 'WARN'
        return @()
    }

    Get-Content -LiteralPath $Path -Encoding UTF8 |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') }
}
# configs 디렉터리의 후보 목록을 읽습니다.
# 빈 줄과 # 주석은 무시합니다.

function ConvertTo-WildcardPattern {
    param([string[]]$Items)

    foreach ($item in $Items) {
        if ($item -match '[\*\?]') {
            $item
        }
        else {
            "*$item*"
        }
    }
}
# Appx/Provisioned Appx 탐색에 사용할 수 있도록 일반 이름을 와일드카드 패턴으로 변환합니다.
# 설정 파일에 이미 * 또는 ?가 있으면 그대로 둡니다.

function Get-UniqueList {
    param([string[]]$Items)

    $Items | Where-Object { $_ } | Sort-Object -Unique
}
# 기본 후보와 config 후보를 합칠 때 중복을 제거합니다.

function Remove-ChildrenIfExists {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Write-Log "Cleaning contents of: $Path"
        try {
            Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Remove-Item -LiteralPath $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
                }
                catch {}
            }
        }
        catch {}
    }
}
# 지정 경로 "폴더 자체"는 남기고 내부 내용만 비웁니다.
# Temp, Cache, Logs 같이 폴더 구조는 유지하고 내용만 지울 때 안전합니다.

function Remove-PathIfExists {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Write-Log "Removing path: $Path"
        try {
            Remove-Item -LiteralPath $Path -Force -Recurse -ErrorAction SilentlyContinue
        }
        catch {}
    }
}
# 지정 파일/폴더 자체를 제거합니다.
# MEMORY.DMP 같은 단일 덤프 파일 제거에 적합합니다.

function Set-RegDword {
    param(
        [string]$Path,
        [string]$Name,
        [int]$Value
    )

    try {
        if (-not (Test-Path -Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
        Write-Log "Registry set: $Path -> $Name = $Value"
    }
    catch {
        Write-Log "Registry set failed: $Path -> $Name" 'WARN'
    }
}
# 정책/설정을 레지스트리에 DWORD로 기록합니다.
# 값 수정 시 기능 비활성/활성 정책이 바뀝니다.

function Remove-RegistryKeySafe {
    param([string]$Path)

    try {
        if (Test-Path -Path $Path) {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Registry key removed: $Path"
        }
    }
    catch {
        Write-Log "Registry key removal failed: $Path" 'WARN'
    }
}
# 최근 항목, 실행 기록 등 템플릿에 남기지 않을 사용자 흔적성 레지스트리 키를 안전하게 제거합니다.

function Stop-ServiceSafe {
    param([string]$Name)
    try {
        Write-Log "Stopping service: $Name"
        Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
    }
    catch {}
}
# 정리 전 파일 잠금을 줄이기 위해 일부 서비스를 중지합니다.

function Start-ServiceSafe {
    param([string]$Name)
    try {
        Write-Log "Starting service: $Name"
        Start-Service -Name $Name -ErrorAction SilentlyContinue
    }
    catch {}
}
# 정리 후 필요 서비스 재시작용입니다.

function Disable-ServiceSafe {
    param([string]$Name)
    try {
        $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($service) {
            Write-Log "Disabling service: $Name"
            if ($service.Status -eq 'Running') {
                Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
            }
            Set-Service -Name $Name -StartupType Disabled -ErrorAction SilentlyContinue
        }
        else {
            Write-Log "서비스가 존재하지 않아 건너뜁니다: $Name" 'WARN'
        }
    }
    catch {}
}
# 서비스 시작 유형을 Disabled로 바꿉니다.
# 성능/백그라운드 I/O 억제에 도움이 되지만, 관련 기능은 제한될 수 있습니다.

function Disable-TaskByPathAndName {
    param(
        [string]$TaskPath,
        [string]$TaskName
    )
    try {
        $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($task) {
            Disable-ScheduledTask -InputObject $task | Out-Null
            Write-Log "Disabled scheduled task: $TaskPath$TaskName"
        }
        else {
            Write-Log "예약 작업이 존재하지 않아 건너뜁니다: $TaskPath$TaskName" 'WARN'
        }
    }
    catch {}
}
# 예약 작업을 비활성화합니다.
# Telemetry/Feedback성 작업을 줄이는 데 효과적입니다.

function Disable-TaskByFullPath {
    param([string]$TaskReference)

    $lastSlash = $TaskReference.LastIndexOf('\')
    if ($lastSlash -lt 0) {
        Write-Log "예약 작업 경로 형식이 올바르지 않습니다: $TaskReference" 'WARN'
        return
    }

    $taskPath = $TaskReference.Substring(0, $lastSlash + 1)
    $taskName = $TaskReference.Substring($lastSlash + 1)
    Disable-TaskByPathAndName -TaskPath $taskPath -TaskName $taskName
}
# configs/tasks-disable-list.txt의 전체 작업 경로를 TaskPath와 TaskName으로 분리합니다.


function Write-OptionSummary {
    $optionNames = Get-Variable -Scope Script -Name 'Enable*' |
        Sort-Object Name |
        ForEach-Object { "$($_.Name)=$($_.Value)" }
    Write-Log ('적용 옵션: ' + ($optionNames -join ', '))
}

Write-Log "=== Optimization Start ==="
Write-Log "로그 파일: $Script:LogFile"
Write-Log '대화형 모드: 각 단계마다 Y/n 확인 후 진행합니다.'
Write-OptionSummary

# -----------------------------
# 후보 목록 구성
# -----------------------------
$DefaultAppxPatterns = @(
    # 게임
    '*Xbox*',
    '*GamingApp*',
    # 미디어/편집
    '*Clipchamp*',
    '*ZuneMusic*',
    '*ZuneVideo*',
    '*WindowsCamera*',
    '*WindowsSoundRecorder*',
    # 커뮤니케이션/협업
    '*Teams*',
    '*SkypeApp*',
    '*YourPhone*',
    '*CrossDevice*',
    '*WindowsCommunicationsApps*',  # Mail & Calendar
    # M365 / Office 번들
    '*MicrosoftOfficeHub*',
    '*OutlookForWindows*',
    '*Todos*',
    '*PowerAutomateDesktop*',
    '*OneNote*',
    # AI / 보조
    '*Copilot*',
    '*549981C3F5F10*',              # Cortana
    # 소비자 앱
    '*BingNews*',
    '*BingWeather*',
    '*Maps*',
    '*MicrosoftSolitaireCollection*',
    '*People*',
    '*MicrosoftStickyNotes*',
    '*WindowsAlarms*',
    '*WindowsFeedbackHub*',
    '*GetHelp*',
    '*Getstarted*',
    '*DevHome*',
    '*QuickAssist*'
)

$ConfigAppxPatterns = ConvertTo-WildcardPattern -Items (Read-ListFile -Path (Join-Path $Script:ConfigDir 'appx-remove-list.txt'))
$AppxPatterns = Get-UniqueList -Items ($DefaultAppxPatterns + $ConfigAppxPatterns)

$DefaultServicesToDisable = @(
    'DiagTrack',
    'MapsBroker',
    'OneSyncSvc'
)
# DiagTrack: 진단 추적
# MapsBroker: 지도 관련
# OneSyncSvc: 일부 계정 동기화
# 과도한 서비스 중지는 장애를 부를 수 있어 기본 후보는 제한적으로 유지합니다.

$ConfigServicesToDisable = Read-ListFile -Path (Join-Path $Script:ConfigDir 'services-disable-list.txt')
$ServicesToDisable = Get-UniqueList -Items ($DefaultServicesToDisable + $ConfigServicesToDisable)

$DefaultTasksToDisable = @(
    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
    '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
    '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
    '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
    '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
    '\Microsoft\Windows\Feedback\Siuf\DmClient',
    '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
    '\Microsoft\Windows\Maps\MapsUpdateTask'
)
# 주로 진단/피드백/지도 업데이트 성격 작업입니다.

$ConfigTasksToDisable = Read-ListFile -Path (Join-Path $Script:ConfigDir 'tasks-disable-list.txt')
$TasksToDisable = Get-UniqueList -Items ($DefaultTasksToDisable + $ConfigTasksToDisable)

# -----------------------------
# Service stop (cleanup prep)
# -----------------------------
$ServicesToStopForCleanup = @(
    'wuauserv',
    'bits',
    'dosvc'
)
# 정리 전 멈출 서비스 목록입니다.
# wuauserv: Windows Update
# bits: 백그라운드 전송 서비스
# dosvc: Delivery Optimization

if ($EnableUpdateCacheCleanup -or $EnableTempCleanup) {
    $ServicesToStopForCleanup | ForEach-Object { Stop-ServiceSafe $_ }
}
# 캐시/다운로드 파일 잠금을 줄이기 위해 중지합니다.

# -----------------------------
# Temp / Cache Cleanup
# -----------------------------
$tempDetails = @(
    'Windows\Temp, Prefetch, Minidump 삭제',
    'SoftwareDistribution\Download, DeliveryOptimization 삭제',
    'System32\LogFiles, $Recycle.Bin 삭제',
    'MEMORY.DMP 삭제',
    '사용자 AppData Temp, INetCache, Explorer 캐시, D3DSCache, CrashDumps 삭제',
    'UWP 앱 패키지 TempState, LocalCache 삭제'
)
if ($EnableInstallerResidueCleanup) {
    $tempDetails += 'Windows Installer $PatchCache$, ProgramData Package Cache, WER 삭제'
    $tempDetails += '사용자 AppData Local Package Cache, WER 삭제'
}
if ($EnableSetupLogCleanup) {
    $tempDetails += 'Panther, Sysprep\Panther, Logs\DISM, Logs\CBS 삭제 (설치/배포 분석 로그)'
}
if ($EnableDownloadsDesktopCleanup) {
    $tempDetails += '사용자 Downloads, Desktop 내용 삭제'
}

if (($EnableTempCleanup -or $EnableInstallerResidueCleanup -or $EnableSetupLogCleanup -or $EnableDownloadsDesktopCleanup) -and (Confirm-Step -Title '[1/14] 임시 파일 및 캐시 정리' -Details $tempDetails)) {
    $SystemCleanupPaths = @()

    if ($EnableTempCleanup) {
        $SystemCleanupPaths += @(
            "$env:SystemRoot\Temp",
            "$env:SystemRoot\Prefetch",
            "$env:SystemRoot\Minidump",
            "$env:SystemRoot\SoftwareDistribution\Download",
            "$env:SystemRoot\SoftwareDistribution\DeliveryOptimization",
            "$env:SystemRoot\System32\LogFiles",
            "$env:SystemDrive\`$Recycle.Bin"
        )
    }

    if ($EnableInstallerResidueCleanup) {
        $SystemCleanupPaths += @(
            "$env:SystemRoot\Installer\`$PatchCache`$",
            "$env:ProgramData\Package Cache",
            "$env:ProgramData\Microsoft\Windows\WER"
        )
    }
    # 각 경로 역할:
    # Temp: 시스템 임시 파일
    # Prefetch: 실행 추적 캐시
    # Minidump: 충돌 덤프
    # SoftwareDistribution\Download: 업데이트 다운로드 잔여물
    # DeliveryOptimization: 업데이트 전달 캐시
    # LogFiles: 일부 시스템 로그
    # $Recycle.Bin: 휴지통
    # Installer\$PatchCache$: Windows Installer 패치 캐시
    # ProgramData\Package Cache: 설치 프로그램 패키지 캐시
    # ProgramData\Microsoft\Windows\WER: 시스템 오류 보고 잔여물

    if ($EnableSetupLogCleanup) {
        $SystemCleanupPaths += @(
            "$env:SystemRoot\Panther",
            "$env:SystemRoot\System32\Sysprep\Panther",
            "$env:SystemRoot\Logs\DISM",
            "$env:SystemRoot\Logs\CBS"
        )
    }
    # Panther/CBS/DISM 로그는 Sysprep 실패 분석에 필요할 수 있어 별도 옵션으로 분리했습니다.

    foreach ($path in $SystemCleanupPaths) {
        Remove-ChildrenIfExists $path
    }

    if ($EnableTempCleanup) {
        Remove-PathIfExists "$env:SystemRoot\MEMORY.DMP"
        # 대용량 메모리 덤프 제거
    }

    $userRoots = @('C:\Users') + (Get-PSDrive -PSProvider FileSystem |
        Where-Object { $_.Name -ne $env:SystemDrive.TrimEnd(':') -and (Test-Path -LiteralPath "$($_.Name):\Users") } |
        ForEach-Object { "$($_.Name):\Users" })

    foreach ($root in (Get-UniqueList -Items $userRoots)) {
        if (Test-Path -LiteralPath $root) {
            Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notin @('Default', 'Default User', 'Public', 'All Users') } |
                ForEach-Object {
                    $u = $_.FullName

                    if ($EnableTempCleanup) {
                        Remove-ChildrenIfExists "$u\AppData\Local\Temp"
                        # 사용자 임시 파일

                        Remove-ChildrenIfExists "$u\AppData\Local\Microsoft\Windows\INetCache"
                        # IE/웹 기반 캐시, 일부 시스템 웹 캐시

                        Remove-ChildrenIfExists "$u\AppData\Local\Microsoft\Windows\Explorer"
                        # Explorer 썸네일/캐시 일부

                        Remove-ChildrenIfExists "$u\AppData\Local\D3DSCache"
                        # Direct3D 캐시

                        Remove-ChildrenIfExists "$u\AppData\Local\CrashDumps"
                        # 사용자 영역 크래시 덤프
                    }

                    if ($EnableInstallerResidueCleanup) {
                        Remove-ChildrenIfExists "$u\AppData\Local\Package Cache"
                        # 사용자 영역 설치 패키지 캐시

                        Remove-ChildrenIfExists "$u\AppData\Local\Microsoft\Windows\WER"
                        # 사용자 영역 Windows Error Reporting 잔여물
                    }

                    if ($EnableTempCleanup) {
                        $packagesRoot = "$u\AppData\Local\Packages"
                        if (Test-Path -LiteralPath $packagesRoot) {
                            Get-ChildItem -LiteralPath $packagesRoot -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
                                Remove-ChildrenIfExists "$($_.FullName)\AC\Temp"
                                Remove-ChildrenIfExists "$($_.FullName)\AC\INetCache"
                                Remove-ChildrenIfExists "$($_.FullName)\TempState"
                                Remove-ChildrenIfExists "$($_.FullName)\LocalCache"
                            }
                        }
                        # UWP 앱 패키지 전체 삭제는 위험하므로 캐시/임시 데이터 성격의 하위 폴더만 선택 정리합니다.
                    }

                    if ($EnableDownloadsDesktopCleanup) {
                        Remove-ChildrenIfExists "$u\Downloads"
                        Remove-ChildrenIfExists "$u\Desktop"
                    }
                    # 사용자 다운로드/바탕화면 정리 옵션
                }
        }
    }
}

# -----------------------------
# Update Cache Cleanup
# -----------------------------
if ($EnableUpdateCacheCleanup -and (Confirm-Step -Title '[2/14] Windows Update 캐시 정리' -Details @(
    'SoftwareDistribution\Download 삭제',
    'SoftwareDistribution\DeliveryOptimization 삭제'
))) {
    Remove-ChildrenIfExists "$env:SystemRoot\SoftwareDistribution\Download"
    Remove-ChildrenIfExists "$env:SystemRoot\SoftwareDistribution\DeliveryOptimization"
}
# TempCleanup를 꺼도 UpdateCacheCleanup만 별도로 쓸 수 있게 분리했습니다.

# -----------------------------
# Defender Cleanup
# -----------------------------
if ($EnableDefenderCleanup -and (Confirm-Step -Title '[3/14] Windows Defender 검사 기록 정리' -Details @(
    'Windows Defender\Scans\History 삭제',
    'Windows Defender\Scans\Tmp 삭제'
))) {
    Remove-ChildrenIfExists 'C:\ProgramData\Microsoft\Windows Defender\Scans\History'
    Remove-ChildrenIfExists 'C:\ProgramData\Microsoft\Windows Defender\Scans\Tmp'
}
# Defender 검사 이력과 임시 파일 정리

# -----------------------------
# Event Logs Cleanup
# -----------------------------
if ($EnableEventLogClear -and (Confirm-Step -Title '[4/14] 이벤트 로그 초기화' -Details @(
    'wevtutil로 전체 이벤트 로그 채널을 순회하며 초기화',
    '경고: 장애 분석/감사 추적이 필요한 환경에서는 건너뛰십시오'
))) {
    Write-Log 'Clearing event logs' 'WARN'
    try {
        wevtutil el | ForEach-Object {
            try { wevtutil cl "$_" } catch {}
        }
    }
    catch {}
}
# 모든 이벤트 로그 채널을 순회하며 초기화합니다.
# 장애 분석/감사 흔적 유지가 필요하면 false 권장

# -----------------------------
# Hibernation Off
# -----------------------------
if ($EnableHibernationOff -and (Confirm-Step -Title '[5/14] 최대 절전 비활성화' -Details @(
    'powercfg -h off 실행',
    'hiberfil.sys 제거 (수 GB 용량 확보)'
))) {
    Write-Log 'Disabling hibernation'
    try { powercfg -h off | Out-Null } catch {}
}
# hiberfil.sys 제거

# -----------------------------
# Power Plan / Sleep Tweaks
# -----------------------------
if ($EnablePowerPlanTweaks -and (Confirm-Step -Title '[6/14] 전원 계획 및 절전 설정 조정' -Details @(
    '고성능 전원 계획(SCHEME_MIN) 활성화',
    '모니터/절전/최대 절전 타임아웃 0으로 설정 (AC/DC 모두)',
    '레지스트리: GlobalFlags=0, 잠금 화면 표시 옵션 조정'
))) {
    Write-Log 'Applying VM power plan and sleep/display timeout tweaks'

    try {
        powercfg /setactive SCHEME_MIN | Out-Null
        if ($LASTEXITCODE -ne 0) {
            powercfg /duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
            powercfg /setactive SCHEME_MIN | Out-Null
        }
    }
    catch {
        Write-Log 'High performance power plan activation failed or is not supported on this build.' 'WARN'
    }

    try {
        powercfg /change monitor-timeout-ac 0 | Out-Null
        powercfg /change monitor-timeout-dc 0 | Out-Null
        powercfg /change standby-timeout-ac 0 | Out-Null
        powercfg /change standby-timeout-dc 0 | Out-Null
        powercfg /change hibernate-timeout-ac 0 | Out-Null
        powercfg /change hibernate-timeout-dc 0 | Out-Null
    }
    catch {
        Write-Log 'Power timeout configuration failed.' 'WARN'
    }

    Set-RegDword 'HKCU:\Control Panel\PowerCfg' 'GlobalFlags' 0
    Set-RegDword 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings' 'ShowLockOption' 0
}
# VM 템플릿에서 불필요한 절전/화면 꺼짐으로 작업이 중단되지 않도록 보수적으로 전원 시간을 해제합니다.

# -----------------------------
# Optional Pagefile Disable
# -----------------------------
if ($EnablePagefileDisable -and (Confirm-Step -Title '[7/14] Pagefile 비활성화' -Details @(
    '자동 pagefile 관리 해제 (wmic AutomaticManagedPagefile=False)',
    'C:\pagefile.sys 삭제 시도',
    '경고: 재부팅 후 검증 필요. 메모리 부족 시 시스템 불안정 가능'
))) {
    Write-Log 'Disabling automatic pagefile management' 'WARN'
    try {
        wmic computersystem where name="%computername%" set AutomaticManagedPagefile=False | Out-Null
        wmic pagefileset where name="C:\\pagefile.sys" delete | Out-Null
    }
    catch {}
}
# pagefile 자동 관리 해제 + C:\pagefile.sys 삭제 시도
# 재부팅/검증이 필요할 수 있어 기본 false

# -----------------------------
# Appx Removal
# -----------------------------
if ($EnableAppxRemoval -and (Confirm-Step -Title '[8/14] Appx 앱 제거' -Details (@(
    '제거 대상 패턴: Xbox, GamingApp, Clipchamp, Teams, BingNews, BingWeather',
    '제거 대상 패턴: Maps, ZuneMusic, ZuneVideo, MicrosoftSolitaireCollection',
    '제거 대상 패턴: People, WindowsFeedbackHub, GetHelp, Getstarted',
    '제거 대상 패턴: YourPhone, CrossDevice, Copilot'
) + $(if ($ConfigAppxPatterns.Count -gt 0) { @("configs/appx-remove-list.txt 추가 항목: $($ConfigAppxPatterns.Count)개") } else { @() })))) {
    Write-Log 'Removing selected Appx packages'

    foreach ($pattern in $AppxPatterns) {
        try {
            Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue | ForEach-Object {
                Write-Log "Removing Appx package: $($_.PackageFullName)"
                Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
            }
            Write-Log "Attempted Appx removal: $pattern"
        }
        catch {}
    }
}
# 과하게 제거하면 업무상 필요한 번들 앱도 사라질 수 있으므로 config 목록과 선택 모드를 검토하십시오.

# -----------------------------
# Provisioned Appx Removal
# -----------------------------
if ($EnableProvisionedAppxRemoval -and (Confirm-Step -Title '[9/14] Provisioned Appx 제거' -Details @(
    '동일 패턴으로 Get-AppxProvisionedPackage 대상 제거',
    '새 사용자 생성 시 앱이 다시 설치되지 않도록 방지',
    'Appx 제거와 별도로 동작하므로 반드시 함께 실행 권장'
))) {
    Write-Log 'Removing selected provisioned Appx packages'

    try {
        $provisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        foreach ($pattern in $AppxPatterns) {
            $provisionedPackages | Where-Object { $_.DisplayName -like $pattern } | ForEach-Object {
                Write-Log "Removing provisioned package: $($_.DisplayName)"
                Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }
    catch {}
}
# Provisioned Appx 제거는 "새 사용자 생성 시 다시 나타나는 앱"을 막는 핵심입니다.

# -----------------------------
# OneDrive Removal (optional)
# -----------------------------
if ($EnableOneDriveRemoval -and (Confirm-Step -Title '[10/14] OneDrive 제거' -Details @(
    'OneDriveSetup.exe /uninstall 실행 (32bit/64bit 모두 시도)',
    'ProgramData\Microsoft OneDrive 폴더 삭제',
    'OneDriveTemp 폴더 삭제',
    '경고: 조직 정책/업무 요구 확인 후 결정하십시오'
))) {
    Write-Log 'Removing OneDrive' 'WARN'
    try {
        Start-Process "$env:SystemRoot\System32\OneDriveSetup.exe" '/uninstall' -Wait -NoNewWindow
    }
    catch {}
    try {
        Start-Process "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" '/uninstall' -Wait -NoNewWindow
    }
    catch {}
    Remove-PathIfExists "$env:ProgramData\Microsoft OneDrive"
    Remove-PathIfExists "$env:SystemDrive\OneDriveTemp"
}
# OneDrive 제거는 조직 정책/업무 요구 확인 후 결정합니다.

# -----------------------------
# Service Optimization
# -----------------------------
if ($EnableServiceOptimization -and (Confirm-Step -Title '[11/14] 서비스 비활성화' -Details (@(
    'DiagTrack (진단 추적 서비스) -> Disabled',
    'MapsBroker (지도 관련 서비스) -> Disabled',
    'OneSyncSvc (계정 동기화 서비스) -> Disabled'
) + $(if ($ConfigServicesToDisable.Count -gt 0) { @("configs/services-disable-list.txt 추가 항목: $($ConfigServicesToDisable.Count)개") } else { @() })))) {
    foreach ($svc in $ServicesToDisable) {
        Disable-ServiceSafe $svc
    }

    # WSearch는 환경 영향이 커서 기본 제외합니다.
    # Disable-ServiceSafe 'WSearch'
}
# 서비스 비활성화는 성능/로그/백그라운드 I/O 감소 효과가 있습니다.

# -----------------------------
# Scheduled Task Optimization
# -----------------------------
if ($EnableScheduledTaskOptimization -and (Confirm-Step -Title '[12/14] 예약 작업 비활성화' -Details (@(
    'Application Experience: Microsoft Compatibility Appraiser',
    'Application Experience: ProgramDataUpdater',
    'CEIP: Consolidator, UsbCeip',
    'DiskDiagnostic: DiskDiagnosticDataCollector',
    'Feedback\Siuf: DmClient, DmClientOnScenarioDownload',
    'Maps: MapsUpdateTask'
) + $(if ($ConfigTasksToDisable.Count -gt 0) { @("configs/tasks-disable-list.txt 추가 항목: $($ConfigTasksToDisable.Count)개") } else { @() })))) {
    Write-Log 'Disabling selected scheduled tasks'
    foreach ($taskRef in $TasksToDisable) {
        Disable-TaskByFullPath -TaskReference $taskRef
    }
}

# -----------------------------
# Search / Bing / Cloud Search Tweaks
# -----------------------------
if ($EnableSearchTweaks -and (Confirm-Step -Title '[13/14] 검색/Bing/클라우드 연계 차단 (레지스트리)' -Details @(
    'AllowCortana = 0',
    'DisableWebSearch = 1',
    'ConnectedSearchUseWeb = 0',
    'ConnectedSearchUseWebOverMeteredConnections = 0',
    'AllowCloudSearch = 0',
    'DisableSearchBoxSuggestions = 1'
))) {
    Write-Log 'Applying search tweaks'

    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' 0
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch' 1
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'ConnectedSearchUseWeb' 0
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'ConnectedSearchUseWebOverMeteredConnections' 0
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCloudSearch' 0
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
}
# Windows 검색의 웹/Bing/클라우드 연계를 줄입니다.

# -----------------------------
# Copilot Tweaks
# -----------------------------
if ($EnableCopilotTweaks -and (Confirm-Step -Title '[14/14] Copilot 비활성화 (레지스트리)' -Details @(
    'HKLM: TurnOffWindowsCopilot = 1',
    'HKCU: TurnOffWindowsCopilot = 1'
))) {
    Write-Log 'Applying Copilot tweaks'

    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
    Set-RegDword 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
}
# Copilot 정책 비활성화

# -----------------------------
# Recall Tweaks
# -----------------------------
if ($EnableRecallTweaks -and (Confirm-Step -Title '[+] AI/Recall 기능 차단 (레지스트리)' -Details @(
    'DisableAIDataAnalysis = 1',
    'TurnOffSavingSnapshots = 1',
    'AllowRecallEnablement = 0',
    '빌드에 따라 무시될 수 있으나 보수적 차단으로 무방'
))) {
    Write-Log 'Applying Recall-related privacy tweaks'

    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'TurnOffSavingSnapshots' 1
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement' 0
}
# AI/Recall 성격 기능 차단용 보수적 정책

# -----------------------------
# Consumer / Ads / Suggestions Tweaks
# -----------------------------
if ($EnableConsumerTweaks -and (Confirm-Step -Title '[+] 소비자 경험/광고/추천 앱 비활성화 (레지스트리)' -Details @(
    'DisableWindowsConsumerFeatures = 1',
    'DisableConsumerAccountStateContent = 1',
    'DisableCloudOptimizedContent = 1',
    'DisableTailoredExperiencesWithDiagnosticData = 1',
    'DisableThirdPartySuggestions = 1',
    'ContentDeliveryManager 구독 콘텐츠 항목 비활성화',
    'SoftLandingEnabled = 0'
))) {
    Write-Log 'Applying consumer experience and suggestions tweaks'

    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableConsumerAccountStateContent' 1
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableCloudOptimizedContent' 1
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' 1
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableThirdPartySuggestions' 1

    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338388Enabled' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353694Enabled' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353696Enabled' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SoftLandingEnabled' 0
}
# 추천 앱, 광고성 제안, 소비자 경험성 콘텐츠를 줄입니다.

# -----------------------------
# Privacy Tweaks
# -----------------------------
if ($EnablePrivacyTweaks -and (Confirm-Step -Title '[+] 개인정보/텔레메트리 정책 적용 (레지스트리)' -Details @(
    'AllowTelemetry = 0 (텔레메트리 최소화)',
    'DoNotShowFeedbackNotifications = 1',
    'AdvertisingInfo DisabledByGroupPolicy = 1 (광고 ID 비활성화)',
    'EnableActivityFeed = 0',
    'PublishUserActivities = 0',
    'UploadUserActivities = 0'
))) {
    Write-Log 'Applying privacy tweaks'

    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' 1
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' 0
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' 0
}
# Telemetry 수준 최소화, 피드백 알림 차단, 광고 ID 비활성화

# -----------------------------
# Privacy General Tweaks
# -----------------------------
if ($EnablePrivacyGeneralTweak -and (Confirm-Step -Title '[+] 개인 정보 및 보안 > 일반/권장 사항 조정 (레지스트리)' -Details @(
    'HttpAcceptLanguageOptOut = 1 (웹 사이트의 언어 목록 접근 차단)',
    'EnableAccountNotifications = 0 (설정에 알림 표시 끔)',
    'IsDeviceSearchHistoryEnabled = 0 (장치 검색 기록 비활성화)',
    '장치 검색 기록 초기화 (Search\RecentApps 삭제)'
))) {
    Write-Log 'Applying privacy general tweaks'

    Set-RegDword 'HKCU:\Control Panel\International\User Profile' 'HttpAcceptLanguageOptOut' 1
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications' 'EnableAccountNotifications' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsDeviceSearchHistoryEnabled' 0
    Remove-RegistryKeySafe 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\RecentApps'
}
# 언어 목록 웹 공유, 설정 알림, 장치 검색 기록을 차단하고 기존 기록을 초기화합니다.

# -----------------------------
# Sign-in Options Tweaks
# -----------------------------
if ($EnableSignInOptionsTweak -and (Confirm-Step -Title '[+] 로그인 옵션 조정 (레지스트리)' -Details @(
    'DisableAutomaticRestartSignOn = 1 (업데이트/재시작 후 자동 로그인 완료 비활성화)',
    '설정 경로: 계정 > 로그인 옵션 > 업데이트 후 로그인 정보를 사용하여 자동으로 설정을 완료합니다'
))) {
    Write-Log 'Applying sign-in options tweaks'

    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'DisableAutomaticRestartSignOn' 1
}
# 업데이트 후 자동 재로그인(ARSO) 차단 — VM 템플릿에서 첫 사용자 로그인을 강제합니다.

# -----------------------------
# Taskbar End Task Tweak
# -----------------------------
if ($EnableTaskbarEndTaskTweak -and (Confirm-Step -Title '[+] 작업 표시줄 작업 종료 버튼 활성화 (레지스트리)' -Details @(
    'TaskbarEndTask = 1 (작업 표시줄 우클릭 메뉴에 작업 종료 항목 표시)',
    '설정 경로: 시스템 > 개발자용 > 작업 표시줄에서 작업 종료'
))) {
    Write-Log 'Applying Taskbar End Task tweak'

    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask' 1
}
# 작업 표시줄 우클릭으로 프로세스를 직접 종료할 수 있어 VM 관리에 유용합니다.

# -----------------------------
# App Restart Tweak
# -----------------------------
if ($EnableAppRestartTweak -and (Confirm-Step -Title '[+] 앱 자동 재시작 비활성화 (레지스트리)' -Details @(
    'RestartApps = 0 (로그인 시 앱 자동 재시작 끔)',
    '설정 경로: 앱 > 다시 시작'
))) {
    Write-Log 'Applying App Restart tweak'

    Set-RegDword 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon' 'RestartApps' 0
}
# 로그인 후 이전 앱 자동 재시작을 차단해 템플릿 배포 시 클린한 초기 상태를 유지합니다.

# -----------------------------
# Delivery Optimization Tweaks
# -----------------------------
if ($EnableDeliveryOptimizationTweaks -and (Confirm-Step -Title '[+] Delivery Optimization 외부 공유 차단 (레지스트리)' -Details @(
    'DODownloadMode = 0 (PC 간 업데이트 공유 차단)',
    'HKLM Config 및 Policies 두 경로 모두 적용'
))) {
    Write-Log 'Applying Delivery Optimization tweaks'

    Set-RegDword 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' 'DODownloadMode' 0
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0
}
# Delivery Optimization 공유를 줄여 불필요한 캐시/네트워크 공유 동작을 억제합니다.

# -----------------------------
# Explorer / UI Tweaks
# -----------------------------
if ($EnableExplorerTweaks -and (Confirm-Step -Title '[+] 파일 탐색기 UI 조정 (레지스트리)' -Details @(
    'ShowSyncProviderNotifications = 0 (OneDrive 등 동기화 알림 제거)',
    'LaunchTo = 1 (탐색기 기본 시작 위치를 내 PC로 변경)'
))) {
    Write-Log 'Applying Explorer/UI tweaks'

    Set-RegDword 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'LaunchTo' 1
}
# 동기화 공급자 알림 줄이기, Explorer 기본 시작 위치 조정

# -----------------------------
# Explorer Privacy Cleanup
# -----------------------------
if ($EnableExplorerPrivacyCleanup -and (Confirm-Step -Title '[+] 파일 탐색기 사용 흔적 정리 (레지스트리 + 파일)' -Details @(
    'ShowRecent = 0, ShowFrequent = 0, ShowCloudFilesInQuickAccess = 0',
    'Start_TrackDocs = 0 (최근 문서 추적 중지)',
    'RecentDocs, RunMRU, TypedPaths, WordWheelQuery 레지스트리 키 삭제',
    'AppData\Roaming\Microsoft\Windows\Recent 내용 삭제',
    'AutomaticDestinations, CustomDestinations 삭제'
))) {
    Write-Log 'Applying Explorer privacy cleanup'

    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' 'ShowRecent' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' 'ShowFrequent' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' 'ShowCloudFilesInQuickAccess' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_TrackDocs' 0

    Remove-RegistryKeySafe 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs'
    Remove-RegistryKeySafe 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU'
    Remove-RegistryKeySafe 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths'
    Remove-RegistryKeySafe 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\WordWheelQuery'

    Remove-ChildrenIfExists (Join-Path $env:APPDATA 'Microsoft\Windows\Recent')
    Remove-ChildrenIfExists (Join-Path $env:APPDATA 'Microsoft\Windows\Recent\AutomaticDestinations')
    Remove-ChildrenIfExists (Join-Path $env:APPDATA 'Microsoft\Windows\Recent\CustomDestinations')
}
# 파일 탐색기 최근 파일/폴더, 실행 기록, 주소 입력 기록, 검색어 기록을 줄여 템플릿 흔적을 최소화합니다.

# -----------------------------
# Start Menu Tweaks
# -----------------------------
if ($EnableStartMenuTweaks -and (Confirm-Step -Title '[+] 시작 메뉴 추천/최근 항목 표시 제한 (레지스트리)' -Details @(
    'ShowRecentList = 0, ShowFrequentList = 0, ShowRecommendations = 0',
    'Start_TrackDocs = 0, Start_TrackProgs = 0',
    'ContentDeliveryManager 구독 콘텐츠 338388, 338389 비활성화'
))) {
    Write-Log 'Applying Start menu recommendation tweaks'

    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start' 'ShowRecentList' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start' 'ShowFrequentList' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start' 'ShowRecommendations' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_TrackDocs' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_TrackProgs' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338388Enabled' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled' 0
}
# 시작 메뉴 최근/추천/계정 알림성 표시를 제한합니다.

# -----------------------------
# Start Personalization Tweaks
# -----------------------------
if ($EnableStartPersonalizationTweak -and (Confirm-Step -Title '[+] 개인설정 > 시작 조정 (레지스트리)' -Details @(
    'Start_IrisRecommendations = 0 (팁/바로가기/새 앱 권장 사항 끔)',
    'Start_AccountNotifications = 0 (계정 관련 알림 끔)',
    '전원 버튼 옆 폴더: 설정/파일 탐색기/다운로드 표시, 나머지 끔'
))) {
    Write-Log 'Applying Start personalization tweaks'

    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_IrisRecommendations' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_AccountNotifications' 0

    $startPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'
    Set-RegDword $startPath 'ShowSettings'      1
    Set-RegDword $startPath 'ShowFileExplorer'  1
    Set-RegDword $startPath 'ShowDownloads'     1
    Set-RegDword $startPath 'ShowPersonalFolder' 0
    Set-RegDword $startPath 'ShowDocuments'     0
    Set-RegDword $startPath 'ShowMusic'         0
    Set-RegDword $startPath 'ShowPictures'      0
    Set-RegDword $startPath 'ShowVideos'        0
    Set-RegDword $startPath 'ShowNetwork'       0
}
# 팁/계정 알림 차단, 전원 버튼 옆 폴더를 설정/탐색기/다운로드 3개로 고정합니다.

# -----------------------------
# Taskbar / Notification Tweaks
# -----------------------------
if ($EnableTaskbarAndNotificationTweaks -and (Confirm-Step -Title '[+] 작업표시줄/알림 정리 (레지스트리)' -Details @(
    'ShowTaskViewButton = 0 (작업 보기 버튼 숨김)',
    'TaskbarDa = 0 (Widgets 숨김)',
    'AllowNewsAndInterests = 0',
    'ContentDeliveryManager 310093, 338393, 353694, 353696 비활성화',
    'ScoobeSystemSettingEnabled = 0 (Windows 환영 경험 비활성화)'
))) {
    Write-Log 'Applying taskbar and notification tweaks'

    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowTaskViewButton' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-310093Enabled' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338393Enabled' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353694Enabled' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353696Enabled' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0
}
# Widgets, Task View, Windows 환영 경험, 설정 완료 추천, 팁/추천 알림을 줄입니다.

# -----------------------------
# Lock Screen Content Tweaks
# -----------------------------
if ($EnableLockScreenContentTweaks -and (Confirm-Step -Title '[+] 잠금화면 콘텐츠 제한 (레지스트리)' -Details @(
    'RotatingLockScreenEnabled = 0 (Spotlight 비활성화)',
    'RotatingLockScreenOverlayEnabled = 0',
    'SubscribedContent-338387Enabled = 0',
    'LockScreenOverlayEnabled = 0',
    'SoftLandingEnabled = 0',
    'SlideshowEnabled = 0 (잠금화면 슬라이드쇼 비활성화)'
))) {
    Write-Log 'Applying lock screen content tweaks'

    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'RotatingLockScreenEnabled' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'RotatingLockScreenOverlayEnabled' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338387Enabled' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'LockScreenOverlayEnabled' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SoftLandingEnabled' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen' 'SlideshowEnabled' 0
}
# 잠금화면 Spotlight, 팁, 추천 콘텐츠, 슬라이드쇼성 표시를 줄입니다.

# -----------------------------
# Optional Windows Feature Disable
# -----------------------------
if ($EnableOptionalFeatureDisable -and (Confirm-Step -Title '[+] Windows 선택적 기능 비활성화' -Details @(
    'Printing-XPSServices-Features (XPS 문서 작성기)',
    'WorkFolders-Client (회사 폴더 클라이언트)',
    'SMB1Protocol (레거시 파일 공유 프로토콜, 보안 취약)',
    '경고: 환경에 따라 필요한 기능이 있을 수 있으니 확인 후 진행하십시오'
))) {
    Write-Log 'Disabling selected optional features' 'WARN'

    $Features = @(
        'Printing-XPSServices-Features',
        'WorkFolders-Client',
        'SMB1Protocol'
    )
    # XPS, WorkFolders, SMB1 비활성화
    # 환경에 따라 필요한 기능이 있을 수 있어 기본 false입니다.

    foreach ($f in $Features) {
        try {
            Disable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Write-Log "Attempted feature disable: $f"
        }
        catch {}
    }
}
# 기능 비활성화는 용량/공격면 감소에 도움될 수 있으나 호환성 영향이 있습니다.

# -----------------------------
# CleanMgr
# -----------------------------
if ($EnableCleanMgr -and (Confirm-Step -Title '[+] Windows 디스크 정리 (cleanmgr)' -Details @(
    'cleanmgr.exe /verylowdisk 실행 (완료까지 대기)',
    '시스템 기본 디스크 정리 항목 자동 처리'
))) {
    Write-Log 'Running cleanmgr'
    try {
        Start-Process cleanmgr.exe '/verylowdisk' -Wait -NoNewWindow
    }
    catch {}
}
# Windows 기본 디스크 정리

# -----------------------------
# DISM Cleanup
# -----------------------------
$dismDetails = @('dism /online /cleanup-image /startcomponentcleanup 실행')
if ($EnableResetBase) {
    $dismDetails += '/resetbase 포함 (WinSxS 최대 정리, 롤백 불가)'
} else {
    $dismDetails += '/resetbase 미포함 (롤백 가능성 유지)'
}

if ($EnableDismCleanup -and (Confirm-Step -Title '[+] DISM 컴포넌트 저장소 정리' -Details $dismDetails)) {
    Write-Log 'Running DISM cleanup'
    try {
        $dismArgs = '/online /cleanup-image /startcomponentcleanup'
        if ($EnableResetBase) {
            $dismArgs = "$dismArgs /resetbase"
        }
        Start-Process dism.exe $dismArgs -Wait -NoNewWindow
    }
    catch {}
}
# 컴포넌트 저장소 정리의 핵심
# resetbase는 기존 업데이트 롤백 기반을 줄이는 대신 용량 절감 효과가 큽니다.

# -----------------------------
# CompactOS (optional)
# -----------------------------
if ($EnableCompactOS -and (Confirm-Step -Title '[+] CompactOS 적용' -Details @(
    'compact.exe /compactos:always 실행',
    'OS 파일을 XPRESS4K 압축으로 저장 (수 GB 절감 가능)',
    '경고: CPU 오버헤드 증가 및 업데이트/관리 복잡도 상승 가능',
    '경고: 복제 VM에서 검증 후 반영 권장'
))) {
    Write-Log 'Applying CompactOS' 'WARN'
    try {
        Start-Process compact.exe '/compactos:always' -Wait -NoNewWindow
    }
    catch {}
}
# CompactOS는 OS 파일 압축을 시도합니다.

# -----------------------------
# Edge Tweaks
# -----------------------------
if ($EnableEdgeTweaks -and (Confirm-Step -Title '[+] Microsoft Edge 최적화 (VDOT 기준 정책 레지스트리)' -Details @(
    'BackgroundModeEnabled = 0 (OS 로그인 시 백그라운드 프로세스 자동 시작 비활성화)',
    'StartupBoostEnabled = 0 (시작 부스트/사전 로드 비활성화)',
    'HideFirstRunExperience = 1 (최초 실행 스플래시 화면 숨김)',
    'ShowRecommendationsEnabled = 0 (제품 내 추천/알림 비활성화)',
    'WebWidgetAllowed = 0 (바탕화면 Edge 검색 위젯 비활성화)',
    'EfficiencyMode = 0 (비활성 탭 슬립 효율성 모드 비활성화)',
    'AllowPrelaunch = 0 / AllowTabPreloading = 0 (레거시 Edge 사전 로드 차단)',
    'MicrosoftEdgeDataOptIn = 0 (Edge 데이터 수집 옵트인 비활성화)',
    'AllowEdgeSwipe = 0 (EdgeUI 스와이프 제스처 비활성화)',
    'UpdatesSuppressed: 04:00 ~ 15시간 (VDI 업무 시간대 Edge 자동 업데이트 억제)',
    'AutofillAddressEnabled = 0 (주소 자동완성 비활성화)',
    'AutofillCreditCardEnabled = 0 (신용카드/결제 정보 자동완성 비활성화)',
    'PasswordManagerEnabled = 0 (비밀번호 저장 및 자동완성 비활성화)',
    'NewTabPagePrerenderEnabled = 0 (새 탭 페이지 사전 렌더링 비활성화)',
    'NetworkPredictionOptions = 2 (DNS 프리페치 및 TCP 사전 연결 비활성화)',
    'HardwareAccelerationModeEnabled = 1 (하드웨어 가속 명시적 활성화 유지)',
    '주의: HKCU 항목은 현재 사용자 프로필에만 적용됩니다 (Sysprep 후 신규 사용자 미적용)'
))) {
    Write-Log 'Applying Edge optimization policies (VDOT baseline)'

    # Edge Chromium 정책 (HKLM) ─ 모든 사용자에게 적용
    $edgePolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
    Set-RegDword $edgePolicy 'BackgroundModeEnabled'                              0
    Set-RegDword $edgePolicy 'StartupBoostEnabled'                                0
    Set-RegDword $edgePolicy 'HideFirstRunExperience'                             1
    Set-RegDword $edgePolicy 'HideInternetExplorerRedirectUXForIncompatibleSitesEnabled' 1
    Set-RegDword $edgePolicy 'ShowRecommendationsEnabled'                         0
    Set-RegDword $edgePolicy 'EfficiencyMode'                                     0
    Set-RegDword $edgePolicy 'WebWidgetAllowed'                                   0
    Set-RegDword $edgePolicy 'AutofillAddressEnabled'                             0
    Set-RegDword $edgePolicy 'AutofillCreditCardEnabled'                          0
    Set-RegDword $edgePolicy 'PasswordManagerEnabled'                             0
    Set-RegDword $edgePolicy 'NewTabPagePrerenderEnabled'                         0
    Set-RegDword $edgePolicy 'NetworkPredictionOptions'                           2
    Set-RegDword $edgePolicy 'HardwareAccelerationModeEnabled'                    1

    # 레거시 Edge (EdgeHTML) 정책 (HKLM)
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main'         'AllowPrelaunch'               0
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main'         'PreventFirstRunPage'          1
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\TabPreloader' 'AllowTabPreloading'           0
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\ServiceUI'    'AllowWebContentOnNewTabPage'  0
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\BooksLibrary' 'AllowConfigurationUpdateForBooksLibrary' 0
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\BooksLibrary' 'EnableExtendedBooksTelemetry' 0

    # Edge 데이터 수집 옵트인 비활성화 (HKLM)
    Set-RegDword 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'MicrosoftEdgeDataOptIn' 0

    # Windows EdgeUI 제스처/추적 (HKLM)
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI' 'AllowEdgeSwipe'    0
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI' 'DisableHelpSticker' 1

    # Windows EdgeUI MFU 추적 비활성화 (HKCU ─ 현재 사용자)
    Set-RegDword 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI' 'DisableMFUTracking' 1

    # Edge 자동 업데이트 억제: 04:00 시작, 900분(15시간) 억제 (HKCU ─ 현재 사용자)
    $edgeUpdate = 'HKCU:\SOFTWARE\Policies\Microsoft\EdgeUpdate'
    Set-RegDword $edgeUpdate 'UpdatesSuppressedStartHour'    4
    Set-RegDword $edgeUpdate 'UpdatesSuppressedStartMin'     0
    Set-RegDword $edgeUpdate 'UpdatesSuppressedDurationMin'  900
}
# VDOT(Virtual Desktop Optimization Tool) 기준 Edge 정책 항목을 적용합니다.
# HKCU 항목은 현재 감사 모드 계정에만 적용되며 Sysprep 후 신규 사용자에게는 별도 적용이 필요합니다.

# -----------------------------
# Control Panel View Tweak
# -----------------------------
if ($EnableControlPanelViewTweak -and (Confirm-Step -Title '[+] 제어판 보기 기준: 큰 아이콘' -Details @(
    'AllItemsIconView = 0 (큰 아이콘)',
    'StartupPage = 1 (모든 항목 보기)'
))) {
    Write-Log 'Applying Control Panel large icon view'
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel' 'AllItemsIconView' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel' 'StartupPage'      1
}

# -----------------------------
# Boot Timeout Tweak
# -----------------------------
if ($EnableBootTimeoutTweak -and (Confirm-Step -Title '[+] 시작 및 복구: OS 목록 표시 시간 3초' -Details @(
    'bcdedit /timeout 3'
))) {
    Write-Log 'Setting boot timeout to 3 seconds'
    try {
        Start-Process bcdedit.exe '/timeout 3' -Wait -NoNewWindow -ErrorAction Stop
        Write-Log 'Boot timeout set to 3s'
    } catch {
        Write-Log "bcdedit 실행 실패 — $_" 'WARN'
    }
}

# -----------------------------
# System Volume Tweak
# -----------------------------
if ($EnableSystemVolumeTweak -and (Confirm-Step -Title '[+] 시스템 볼륨 50% 설정' -Details @(
    'Windows Core Audio API (IAudioEndpointVolume) 사용',
    'SetMasterVolumeLevelScalar(0.5)'
))) {
    Write-Log 'Setting system master volume to 50%'
    try {
        if (-not ('AudioVolumeHelper' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDeviceEnumerator {}
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
    int EnumAudioEndpoints(int df, int sm, out IntPtr pp);
    int GetDefaultAudioEndpoint(int df, int role, [MarshalAs(UnmanagedType.Interface)] out IMMDevice ppDev);
}
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
    int Activate([MarshalAs(UnmanagedType.LPStruct)] Guid iid, int ctx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object ppI);
    int OpenPropertyStore(int access, out IntPtr pp);
    int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
    int GetState(out int state);
}
[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {
    int RegisterControlChangeNotify(IntPtr pNotify);
    int UnregisterControlChangeNotify(IntPtr pNotify);
    int GetChannelCount(out int pnChannelCount);
    int SetMasterVolumeLevel(float fLevelDB, [MarshalAs(UnmanagedType.LPStruct)] Guid pguidEventContext);
    int SetMasterVolumeLevelScalar(float fLevel, [MarshalAs(UnmanagedType.LPStruct)] Guid pguidEventContext);
}
public static class AudioVolumeHelper {
    public static void SetVolume(float level) {
        var enumerator = (IMMDeviceEnumerator)new MMDeviceEnumerator();
        IMMDevice device;
        enumerator.GetDefaultAudioEndpoint(0, 1, out device);
        object volObj;
        var iid = new Guid("5CDF2C82-841E-4546-9722-0CF74078229A");
        device.Activate(iid, 23, IntPtr.Zero, out volObj);
        var vol = (IAudioEndpointVolume)volObj;
        vol.SetMasterVolumeLevelScalar(level, Guid.Empty);
        Marshal.ReleaseComObject(vol);
        Marshal.ReleaseComObject(device);
        Marshal.ReleaseComObject(enumerator);
    }
}
'@
        }
        [AudioVolumeHelper]::SetVolume(0.5)
        Write-Log 'System volume set to 50%'
    } catch {
        Write-Log "볼륨 설정 실패 — $_" 'WARN'
    }
}

# -----------------------------
# Computer Rename
# -----------------------------
if ($EnableComputerRename -and (Confirm-Step -Title '[+] 컴퓨터 이름 변경: VDI-Win11' -Details @(
    'Rename-Computer -NewName VDI-Win11 -Force',
    '변경 사항은 재부팅 후 적용됩니다'
))) {
    Write-Log 'Renaming computer to VDI-Win11'
    try {
        Rename-Computer -NewName 'VDI-Win11' -Force -ErrorAction Stop
        Write-Log 'Computer renamed to VDI-Win11 (재부팅 후 적용)'
    } catch {
        Write-Log "컴퓨터 이름 변경 실패 — $_" 'WARN'
    }
}

# -----------------------------
# Visual Effects Tweak
# -----------------------------
if ($EnableVisualEffectsTweak -and (Confirm-Step -Title '[+] 성능 옵션 시각 효과: Custom (4개만 활성화)' -Details @(
    'VisualFXSetting = 3 (Custom)',
    '[ON]  바탕 화면 아이콘 레이블 그림자 (ListviewShadow = 1)',
    '[ON]  아이콘 대신 미리 보기 (IconsOnly = 0)',
    '[ON]  창 아래에 그림자 표시 (SPI_SETDROPSHADOW)',
    '[ON]  화면 글꼴 가장자리 다듬기 ClearType (FontSmoothing = 2)',
    '[OFF] 나머지 모든 애니메이션/전환 효과'
))) {
    Write-Log 'Applying custom visual effects (4 items only)'

    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 3

    # 애니메이션 전체 비활성화
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations'  0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'EnableAeroPeek'     0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewAlphaSelect' 0
    if (-not (Test-Path 'HKCU:\Control Panel\Desktop\WindowMetrics')) {
        New-Item 'HKCU:\Control Panel\Desktop\WindowMetrics' -Force | Out-Null
    }
    Set-ItemProperty 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate'     '0' -Force
    Set-ItemProperty 'HKCU:\Control Panel\Desktop'               'DragFullWindows' '0' -Force

    # UserPreferencesMask: Best Performance 기준 (모든 UI 애니메이션 비활성화)
    $maskBytes = [byte[]]@(0x90, 0x12, 0x01, 0x80, 0x10, 0x00, 0x00, 0x00)
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' 'UserPreferencesMask' $maskBytes -Type Binary -Force

    # [ON] 바탕 화면 아이콘 레이블 그림자
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewShadow' 1
    # [ON] 아이콘 대신 미리 보기 (0 = 썸네일 표시)
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'IconsOnly' 0
    # [ON] 화면 글꼴 가장자리 다듬기 (ClearType)
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' 'FontSmoothing'     '2' -Force
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' 'FontSmoothingType' '2' -Force

    # [ON] 창 아래에 그림자 표시 — SPI_SETDROPSHADOW (0x1025) 로 설정 및 레지스트리 영속화
    if (-not ('SpiDropShadow' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class SpiDropShadow {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
}
'@
    }
    # SPIF_UPDATEINIFILE(0x01) | SPIF_SENDCHANGE(0x02) = 0x03 으로 레지스트리에 영속화
    [SpiDropShadow]::SystemParametersInfo(0x1025, 0, [IntPtr]1, 3) | Out-Null

    Write-Log 'Visual effects applied: 4 items ON, all animations OFF'
}

# -----------------------------
# Desktop Icons
# -----------------------------
if ($EnableDesktopIcons -and (Confirm-Step -Title '[+] 바탕화면 시스템 아이콘 표시: 내 PC / 제어판' -Details @(
    '{20D04FE0-3AEA-1069-A2D8-08002B30309D} = 0  (내 PC)',
    '{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0} = 0  (제어판)',
    'HideDesktopIcons\NewStartPanel 레지스트리'
))) {
    Write-Log 'Enabling desktop icons: 내 PC, 제어판'
    $iconRegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'
    if (-not (Test-Path $iconRegPath)) { New-Item $iconRegPath -Force | Out-Null }
    Set-ItemProperty $iconRegPath '{20D04FE0-3AEA-1069-A2D8-08002B30309D}' 0 -Type DWord -Force
    Set-ItemProperty $iconRegPath '{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}' 0 -Type DWord -Force
    Write-Log 'Desktop icons set: 내 PC, 제어판'
}

# -----------------------------
# Start Menu Pinned Cleanup
# -----------------------------
if ($EnableStartMenuPinnedCleanup -and (Confirm-Step -Title '[+] 시작 메뉴 고정 항목 정리 (Edge / 파일 탐색기 / 설정만 유지)' -Details @(
    'LayoutModification.json 작성',
    '유지: Microsoft Edge / 파일 탐색기 / 설정',
    '제거: 나머지 모든 기본 고정 항목',
    '현재 사용자 및 Default 사용자 프로필 모두 적용'
))) {
    Write-Log 'Applying Start Menu pinned layout (Edge, Explorer, Settings only)'

    $layoutJson = '{
  "pinnedList": [
    { "desktopAppId": "MSEdge" },
    { "desktopAppId": "Microsoft.Windows.Explorer" },
    { "packagedAppId": "windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel" }
  ]
}'

    # 현재 사용자 (Audit Mode) — CopyProfile 로 Default Profile 에 복사됨
    $userLayoutDir = "$env:LOCALAPPDATA\Microsoft\Windows\Shell"
    if (-not (Test-Path $userLayoutDir)) { New-Item $userLayoutDir -ItemType Directory -Force | Out-Null }
    [System.IO.File]::WriteAllText(
        "$userLayoutDir\LayoutModification.json",
        $layoutJson,
        [System.Text.UTF8Encoding]::new($false)
    )

    # Default 사용자 프로필 — CopyProfile 미적용 환경 대비 명시적 복사
    $defaultLayoutDir = 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell'
    try {
        if (-not (Test-Path $defaultLayoutDir)) { New-Item $defaultLayoutDir -ItemType Directory -Force | Out-Null }
        [System.IO.File]::WriteAllText(
            "$defaultLayoutDir\LayoutModification.json",
            $layoutJson,
            [System.Text.UTF8Encoding]::new($false)
        )
        Write-Log 'LayoutModification.json applied to Default user profile'
    } catch {
        Write-Log "Default 프로필 적용 실패 (무시) — $_" 'WARN'
    }

    Write-Log 'Start Menu pinned layout applied'
}

# -----------------------------
# Restart stopped services
# -----------------------------
if ($EnableUpdateCacheCleanup -or $EnableTempCleanup) {
    $ServicesToStopForCleanup | ForEach-Object { Start-ServiceSafe $_ }
}
# 처음에 중지했던 Update/BITS/DO 서비스를 다시 시작합니다.

# -----------------------------
# Defrag Free Space
# -----------------------------
if ($EnableDefragFreeSpace -and (Confirm-Step -Title '[+] 여유 공간 통합 (defrag /X)' -Details @(
    "defrag $env:SystemDrive /X /U /V",
    'VHD compact 전 여유 공간을 연속된 영역으로 모읍니다.',
    '경고: 소요 시간이 길 수 있습니다. SSD/NVMe 기반 VM에서는 생략을 권장합니다.'
))) {
    Write-Log "Defragmenting free space: $env:SystemDrive"
    try {
        Start-Process defrag.exe "$env:SystemDrive /X /U /V" -Wait -NoNewWindow
    }
    catch {
        Write-Log 'defrag 실행 실패' 'WARN'
    }
}
# VHD compact 전 여유 공간을 연속 배치해 압축률을 높입니다.
# SSD 기반 VM이나 thin-provisioned 디스크에서는 생략해도 무방합니다.


Write-Log '=== Optimization Complete ===' 'SUCCESS'
Write-Host ''
Write-Host '완료되었습니다.'
Write-Host '권장 후속 작업:'
Write-Host '1) 별도 검증 문서와 docs/guide.md 기준 결과 점검'
Write-Host '2) Sysprep 실행'
Write-Host '3) 종료'
Write-Host '4) 이후 VHD compact / 보관은 조직 표준 후처리 절차로 수행'
