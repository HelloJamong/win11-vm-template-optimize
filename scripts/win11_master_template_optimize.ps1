#requires -RunAsAdministrator
# 위 선언은 "관리자 권한으로 실행되어야 함"을 의미합니다.
# 제거하면 일반 권한 실행 시 일부 정리/정책/서비스 변경이 실패할 수 있습니다.

<#
.SYNOPSIS
    Windows 11 VM 마스터 템플릿 최적화 스크립트입니다.

.DESCRIPTION
    Audit Mode에서 Sysprep 전 실행하는 PowerShell 중심 단일 파일 최적화 스크립트입니다.
    별도 프로필 ps1 없이 이 파일 하나에서 --standard, --advanced, --lite 모드를 선택합니다.
    외부 실행 도구 의존 없이 Windows 기본 명령과 PowerShell cmdlet만 사용합니다.

.USAGE
    .\win11_master_template_optimize.ps1
    .\win11_master_template_optimize.ps1 --standard
    .\win11_master_template_optimize.ps1 --advanced
    .\win11_master_template_optimize.ps1 --lite

.MODE
    --standard : 기본값. 기존 standard 프로필에 해당하는 균형형 최적화입니다.
    --advanced : 기존 aggressive 설정에 해당하는 강한 정리/비활성화 모드입니다.
    --lite     : 기존 conservative 설정에 해당하는 보수적/저위험 모드입니다.

.NOTES
    - 공공기관/망분리 환경의 최초 검증은 --lite 모드를 권장합니다.
    - 이벤트 로그 삭제, Appx 제거, 서비스 비활성화는 감사/업무 영향이 있을 수 있습니다.
    - 앱/서비스/예약 작업 후보는 configs 디렉터리의 목록 파일과 스크립트 기본 후보를 함께 사용합니다.
#>

function Show-Usage {
    Write-Host '사용법:'
    Write-Host '  .\win11_master_template_optimize.ps1 [--standard|--advanced|--lite]'
    Write-Host ''
    Write-Host '모드:'
    Write-Host '  --standard  기본값. 성능/용량 균형형 최적화입니다.'
    Write-Host '  --advanced  기존 aggressive에 해당하는 강한 정리/비활성화 모드입니다.'
    Write-Host '  --lite      기존 conservative에 해당하는 보수적/저위험 모드입니다.'
    Write-Host ''
    Write-Host 'PowerShell 관례에 맞게 -standard, -advanced, -lite 형식도 허용합니다.'
}

$RawArguments = @($args)
$Script:SelectedMode = 'standard'
$selectedModes = New-Object System.Collections.Generic.List[string]

foreach ($arg in $RawArguments) {
    switch -Regex ($arg.ToLowerInvariant()) {
        '^(--|-|/)standard$' { $selectedModes.Add('standard'); continue }
        '^(--|-|/)advanced$' { $selectedModes.Add('advanced'); continue }
        '^(--|-|/)lite$' { $selectedModes.Add('lite'); continue }
        '^(--|-|/)(help|h|\?)$' { Show-Usage; exit 0 }
        default {
            Write-Host "알 수 없는 옵션: $arg"
            Show-Usage
            exit 2
        }
    }
}

if ($selectedModes.Count -gt 1) {
    Write-Host "모드는 하나만 지정할 수 있습니다: $($selectedModes -join ', ')"
    Show-Usage
    exit 2
}
elseif ($selectedModes.Count -eq 1) {
    $Script:SelectedMode = $selectedModes[0]
}

$ErrorActionPreference = 'SilentlyContinue'
# 일부 항목이 없거나 삭제에 실패해도 전체 중단하지 않고 계속 진행합니다.
# 엄격한 검증이 필요하면 개별 함수 내부의 로그와 Windows 이벤트/PowerShell 오류를 함께 확인하십시오.

$Script:RootDir = Split-Path -Parent $PSScriptRoot
$Script:ConfigDir = Join-Path $Script:RootDir 'configs'
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
# 기본값은 --standard 모드이며, Apply-ModePreset 함수가 --lite/--advanced 선택 시 값을 덮어씁니다.

$EnableTempCleanup                 = $true
# 시스템/사용자 Temp, 캐시, 일부 로그를 정리합니다.
# false로 바꾸면 정리 범위가 줄어들고 최종 용량 감소 효과가 약해집니다.

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

$EnableExplorerTweaks              = $true
# Explorer 알림/동기화 알림과 일부 UI 기본값을 조정합니다.
# false면 UI 관련 기본값이 원래 상태에 가깝게 유지됩니다.

$EnableDeliveryOptimizationTweaks  = $true
# Delivery Optimization의 외부 공유 성격을 줄입니다.
# false면 업데이트 공유/캐시 관련 기본 동작이 더 남을 수 있습니다.

$EnableOneDriveRemoval             = $false
# OneDrive 제거 시도 옵션입니다.
# 조직 정책이나 특정 업무 요구가 있으면 false 유지 권장.

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

$EnableSetupLogCleanup             = $false
# Panther, Sysprep Panther, CBS/DISM 로그 등 설치/배포 분석 로그를 정리합니다.
# Sysprep 실패 분석에 필요할 수 있어 --lite/--standard 모드에서는 false를 권장합니다.

$EnableResetBase                   = $true
# DISM /StartComponentCleanup 실행 시 /ResetBase를 함께 사용합니다.
# 용량 절감 효과가 크지만 기존 업데이트 롤백 가능성이 줄어듭니다.

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

function Apply-ModePreset {
    param([ValidateSet('standard', 'advanced', 'lite')][string]$ModeName)

    $modePresets = @{
        lite = @{
            EnableTempCleanup                = $true
            EnableUpdateCacheCleanup         = $true
            EnableDefenderCleanup            = $true
            EnableEventLogClear              = $false
            EnableHibernationOff             = $true
            EnableCleanMgr                   = $false
            EnableDismCleanup                = $false
            EnableAppxRemoval                = $false
            EnableProvisionedAppxRemoval     = $false
            EnableServiceOptimization        = $false
            EnableScheduledTaskOptimization  = $false
            EnableSearchTweaks               = $true
            EnableConsumerTweaks             = $true
            EnableCopilotTweaks              = $true
            EnableRecallTweaks               = $true
            EnablePrivacyTweaks              = $true
            EnableExplorerTweaks             = $false
            EnableDeliveryOptimizationTweaks = $true
            EnableOneDriveRemoval            = $false
            EnablePagefileDisable            = $false
            EnableOptionalFeatureDisable     = $false
            EnableDownloadsDesktopCleanup    = $false
            EnableCompactOS                  = $false
            EnableSetupLogCleanup            = $false
            EnableResetBase                  = $false
        }
        standard = @{
            EnableTempCleanup                = $true
            EnableUpdateCacheCleanup         = $true
            EnableDefenderCleanup            = $true
            EnableEventLogClear              = $true
            EnableHibernationOff             = $true
            EnableCleanMgr                   = $true
            EnableDismCleanup                = $true
            EnableAppxRemoval                = $true
            EnableProvisionedAppxRemoval     = $true
            EnableServiceOptimization        = $true
            EnableScheduledTaskOptimization  = $true
            EnableSearchTweaks               = $true
            EnableConsumerTweaks             = $true
            EnableCopilotTweaks              = $true
            EnableRecallTweaks               = $true
            EnablePrivacyTweaks              = $true
            EnableExplorerTweaks             = $true
            EnableDeliveryOptimizationTweaks = $true
            EnableOneDriveRemoval            = $false
            EnablePagefileDisable            = $false
            EnableOptionalFeatureDisable     = $false
            EnableDownloadsDesktopCleanup    = $false
            EnableCompactOS                  = $false
            EnableSetupLogCleanup            = $false
            EnableResetBase                  = $true
        }
        advanced = @{
            EnableTempCleanup                = $true
            EnableUpdateCacheCleanup         = $true
            EnableDefenderCleanup            = $true
            EnableEventLogClear              = $true
            EnableHibernationOff             = $true
            EnableCleanMgr                   = $true
            EnableDismCleanup                = $true
            EnableAppxRemoval                = $true
            EnableProvisionedAppxRemoval     = $true
            EnableServiceOptimization        = $true
            EnableScheduledTaskOptimization  = $true
            EnableSearchTweaks               = $true
            EnableConsumerTweaks             = $true
            EnableCopilotTweaks              = $true
            EnableRecallTweaks               = $true
            EnablePrivacyTweaks              = $true
            EnableExplorerTweaks             = $true
            EnableDeliveryOptimizationTweaks = $true
            EnableOneDriveRemoval            = $true
            EnablePagefileDisable            = $true
            EnableOptionalFeatureDisable     = $true
            EnableDownloadsDesktopCleanup    = $true
            EnableCompactOS                  = $true
            EnableSetupLogCleanup            = $true
            EnableResetBase                  = $true
        }
    }

    foreach ($key in $modePresets[$ModeName].Keys) {
        Set-Variable -Name $key -Scope Script -Value ([bool]$modePresets[$ModeName][$key])
    }

    switch ($ModeName) {
        'lite'     { Write-Log '모드 적용: --lite (기존 conservative, 보수적/저위험)' }
        'standard' { Write-Log '모드 적용: --standard (기본값, 성능/용량 균형형)' }
        'advanced' { Write-Log '모드 적용: --advanced (기존 aggressive, 강한 정리/비활성화)' 'WARN' }
    }
}
# 단일 ps1 파일 안에서 기존 conservative/standard/aggressive 설정값을 모드 프리셋으로 관리합니다.
# 별도 프로필 ps1 파일을 로드하지 않습니다.

function Write-OptionSummary {
    $optionNames = Get-Variable -Scope Script -Name 'Enable*' |
        Sort-Object Name |
        ForEach-Object { "$($_.Name)=$($_.Value)" }
    Write-Log ('적용 옵션: ' + ($optionNames -join ', '))
}

Write-Log "=== Optimization Start ==="
Write-Log "로그 파일: $Script:LogFile"
Apply-ModePreset -ModeName $Script:SelectedMode
Write-OptionSummary

# -----------------------------
# 후보 목록 구성
# -----------------------------
$DefaultAppxPatterns = @(
    '*Xbox*',
    '*GamingApp*',
    '*Clipchamp*',
    '*Teams*',
    '*BingNews*',
    '*BingWeather*',
    '*Maps*',
    '*ZuneMusic*',
    '*ZuneVideo*',
    '*MicrosoftSolitaireCollection*',
    '*People*',
    '*WindowsFeedbackHub*',
    '*GetHelp*',
    '*Getstarted*',
    '*YourPhone*',
    '*CrossDevice*',
    '*Copilot*'
)
# 제거 대상 예:
# Xbox/GamingApp: 게임 관련
# Clipchamp/Teams: 번들 앱
# BingNews/BingWeather/Maps: 소비자 앱
# ZuneMusic/ZuneVideo: 미디어 앱
# YourPhone/CrossDevice: 모바일 디바이스 연동
# Copilot: AI/보조 기능

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
if ($EnableTempCleanup) {
    $SystemCleanupPaths = @(
        "$env:SystemRoot\Temp",
        "$env:SystemRoot\Prefetch",
        "$env:SystemRoot\Minidump",
        "$env:SystemRoot\SoftwareDistribution\Download",
        "$env:SystemRoot\SoftwareDistribution\DeliveryOptimization",
        "$env:SystemRoot\System32\LogFiles",
        "$env:SystemDrive\`$Recycle.Bin"
    )
    # 각 경로 역할:
    # Temp: 시스템 임시 파일
    # Prefetch: 실행 추적 캐시
    # Minidump: 충돌 덤프
    # SoftwareDistribution\Download: 업데이트 다운로드 잔여물
    # DeliveryOptimization: 업데이트 전달 캐시
    # LogFiles: 일부 시스템 로그
    # $Recycle.Bin: 휴지통

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

    Remove-PathIfExists "$env:SystemRoot\MEMORY.DMP"
    # 대용량 메모리 덤프 제거

    $userRoots = @('C:\Users') + (Get-PSDrive -PSProvider FileSystem |
        Where-Object { $_.Name -ne $env:SystemDrive.TrimEnd(':') -and (Test-Path -LiteralPath "$($_.Name):\Users") } |
        ForEach-Object { "$($_.Name):\Users" })

    foreach ($root in (Get-UniqueList -Items $userRoots)) {
        if (Test-Path -LiteralPath $root) {
            Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notin @('Default', 'Default User', 'Public', 'All Users') } |
                ForEach-Object {
                    $u = $_.FullName

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
if ($EnableUpdateCacheCleanup) {
    Remove-ChildrenIfExists "$env:SystemRoot\SoftwareDistribution\Download"
    Remove-ChildrenIfExists "$env:SystemRoot\SoftwareDistribution\DeliveryOptimization"
}
# TempCleanup를 꺼도 UpdateCacheCleanup만 별도로 쓸 수 있게 분리했습니다.

# -----------------------------
# Defender Cleanup
# -----------------------------
if ($EnableDefenderCleanup) {
    Remove-ChildrenIfExists 'C:\ProgramData\Microsoft\Windows Defender\Scans\History'
    Remove-ChildrenIfExists 'C:\ProgramData\Microsoft\Windows Defender\Scans\Tmp'
}
# Defender 검사 이력과 임시 파일 정리

# -----------------------------
# Event Logs Cleanup
# -----------------------------
if ($EnableEventLogClear) {
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
if ($EnableHibernationOff) {
    Write-Log 'Disabling hibernation'
    try { powercfg -h off | Out-Null } catch {}
}
# hiberfil.sys 제거

# -----------------------------
# Optional Pagefile Disable
# -----------------------------
if ($EnablePagefileDisable) {
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
if ($EnableAppxRemoval) {
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
if ($EnableProvisionedAppxRemoval) {
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
if ($EnableOneDriveRemoval) {
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
if ($EnableServiceOptimization) {
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
if ($EnableScheduledTaskOptimization) {
    Write-Log 'Disabling selected scheduled tasks'
    foreach ($taskRef in $TasksToDisable) {
        Disable-TaskByFullPath -TaskReference $taskRef
    }
}

# -----------------------------
# Search / Bing / Cloud Search Tweaks
# -----------------------------
if ($EnableSearchTweaks) {
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
if ($EnableCopilotTweaks) {
    Write-Log 'Applying Copilot tweaks'

    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
    Set-RegDword 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
}
# Copilot 정책 비활성화

# -----------------------------
# Recall Tweaks
# -----------------------------
if ($EnableRecallTweaks) {
    Write-Log 'Applying Recall-related privacy tweaks'

    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'TurnOffSavingSnapshots' 1
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement' 0
}
# AI/Recall 성격 기능 차단용 보수적 정책

# -----------------------------
# Consumer / Ads / Suggestions Tweaks
# -----------------------------
if ($EnableConsumerTweaks) {
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
if ($EnablePrivacyTweaks) {
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
# Delivery Optimization Tweaks
# -----------------------------
if ($EnableDeliveryOptimizationTweaks) {
    Write-Log 'Applying Delivery Optimization tweaks'

    Set-RegDword 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' 'DODownloadMode' 0
    Set-RegDword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0
}
# Delivery Optimization 공유를 줄여 불필요한 캐시/네트워크 공유 동작을 억제합니다.

# -----------------------------
# Explorer / UI Tweaks
# -----------------------------
if ($EnableExplorerTweaks) {
    Write-Log 'Applying Explorer/UI tweaks'

    Set-RegDword 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' 0
    Set-RegDword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'LaunchTo' 1
}
# 동기화 공급자 알림 줄이기, Explorer 기본 시작 위치 조정

# -----------------------------
# Optional Windows Feature Disable
# -----------------------------
if ($EnableOptionalFeatureDisable) {
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
if ($EnableCleanMgr) {
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
if ($EnableDismCleanup) {
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
if ($EnableCompactOS) {
    Write-Log 'Applying CompactOS' 'WARN'
    try {
        Start-Process compact.exe '/compactos:always' -Wait -NoNewWindow
    }
    catch {}
}
# CompactOS는 OS 파일 압축을 시도합니다.

# -----------------------------
# Restart stopped services
# -----------------------------
if ($EnableUpdateCacheCleanup -or $EnableTempCleanup) {
    $ServicesToStopForCleanup | ForEach-Object { Start-ServiceSafe $_ }
}
# 처음에 중지했던 Update/BITS/DO 서비스를 다시 시작합니다.

Write-Log '=== Optimization Complete ===' 'SUCCESS'
Write-Host ''
Write-Host '완료되었습니다.'
Write-Host '권장 후속 작업:'
Write-Host '1) tests/validation-checklist.md 기준 결과 점검'
Write-Host '2) Sysprep 실행'
Write-Host '3) 종료'
Write-Host '4) 이후 zero-fill / VHD compact / 압축은 별도 후처리 절차로 수행'
