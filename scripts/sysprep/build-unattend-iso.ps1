<#
.SYNOPSIS
    Sysprep 응답 파일과 최초 로그인 스크립트를 VM 연결 가능한 ISO 로 생성합니다.

.DESCRIPTION
    scripts/sysprep/ 의 다음 파일을 하나의 ISO 로 패키징합니다.
      - unattend.xml      → VM 에서 C:\Windows\System32\Sysprep\ 에 복사
      - first_logon.ps1   → VM 에서 C:\Windows\Setup\Scripts\ 에 복사
      - SetupComplete.cmd → VM 에서 C:\Windows\Setup\Scripts\ 에 복사 (선택)

    Windows IMAPI2 COM API 를 사용해 외부 도구 없이 ISO 를 생성합니다.

    ISO 마운트 후 Audit Mode PowerShell 에서 아래 명령으로 한 번에 배치하십시오:
      $iso = (Get-Volume | Where-Object { $_.FileSystemLabel -eq 'VMSETUP' }).DriveLetter + ':'
      Copy-Item "$iso\unattend.xml"    "C:\Windows\System32\Sysprep\unattend.xml" -Force
      Copy-Item "$iso\Scripts\*"       "C:\Windows\Setup\Scripts\"               -Force

.PARAMETER OutputIso
    생성할 ISO 파일 경로. 기본값: scripts/sysprep/vmsetup.iso

.PARAMETER VolumeName
    ISO 볼륨 이름. 기본값: VMSETUP

.EXAMPLE
    .\build-unattend-iso.ps1

.EXAMPLE
    .\build-unattend-iso.ps1 -OutputIso D:\iso\win11-template.iso

.NOTES
    - Windows PowerShell (5.x) 에서 실행해야 합니다. IMAPI2 COM API 필요.
    - ProfileDrive 파라미터는 제거되었습니다.
      프로필 경로 이동 방식(ProfilesDirectory) 대신 first_logon.ps1 의
      쉘 폴더 리디렉션 방식을 사용합니다.
#>

[CmdletBinding()]
param(
    [string]$OutputIso = (Join-Path $PSScriptRoot 'vmsetup.iso'),

    [ValidatePattern('^[A-Za-z0-9_\-]{1,32}$')]
    [string]$VolumeName = 'VMSETUP'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

function Write-Info  { param([string]$m) Write-Host "[INFO]  $m" }
function Write-Ok    { param([string]$m) Write-Host "[OK]    $m" }
function Write-Warn  { param([string]$m) Write-Host "[WARN]  $m" -ForegroundColor Yellow }

# ──────────────────────────────────────────────────────────────────────
# IStream → 파일 저장 헬퍼 (IMAPI2 COM 스트림을 디스크에 씁니다)
# ──────────────────────────────────────────────────────────────────────
function Save-IStreamToFile {
    param(
        [Parameter(Mandatory)]$ImageStream,
        [Parameter(Mandatory)][string]$Path
    )

    if (-not ('IStreamFileWriter' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

public static class IStreamFileWriter
{
    public static void Save(object sourceStream, string outputPath)
    {
        IStream stream = (IStream)sourceStream;
        byte[] buffer  = new byte[1024 * 1024];
        IntPtr pRead   = Marshal.AllocHGlobal(sizeof(int));
        try
        {
            using (FileStream file = File.Create(outputPath))
            {
                while (true)
                {
                    stream.Read(buffer, buffer.Length, pRead);
                    int n = Marshal.ReadInt32(pRead);
                    if (n <= 0) break;
                    file.Write(buffer, 0, n);
                }
            }
        }
        finally { Marshal.FreeHGlobal(pRead); }
    }
}
'@
    }
    [IStreamFileWriter]::Save($ImageStream, $Path)
}

# ──────────────────────────────────────────────────────────────────────
# ディレクトリ → ISO 生成
# ──────────────────────────────────────────────────────────────────────
function New-IsoFromDirectory {
    param(
        [Parameter(Mandatory)][string]$SourceDirectory,
        [Parameter(Mandatory)][string]$IsoPath,
        [Parameter(Mandatory)][string]$IsoVolumeName
    )

    $fsi = $null; $img = $null
    try {
        $fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
        # ISO9660(1) + Joliet(2) + UDF(4) — 호환성을 위해 모두 활성화
        $fsi.FileSystemsToCreate = 7
        $fsi.VolumeName          = $IsoVolumeName
        $fsi.Root.AddTree($SourceDirectory, $false)

        $img = $fsi.CreateResultImage()
        Save-IStreamToFile -ImageStream $img.ImageStream -Path $IsoPath
    }
    finally {
        if ($img) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($img) }
        if ($fsi) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($fsi) }
    }
}

# ──────────────────────────────────────────────────────────────────────
# 소스 파일 확인
# ──────────────────────────────────────────────────────────────────────
$UnattendSrc    = Join-Path $PSScriptRoot 'unattend.xml'
$FirstLogonSrc  = Join-Path $PSScriptRoot 'first_logon.ps1'
$SetupCompleteSrc = Join-Path $PSScriptRoot 'setupcomplete.cmd'

foreach ($f in @($UnattendSrc, $FirstLogonSrc)) {
    if (-not (Test-Path $f)) {
        throw "필수 파일 없음: $f"
    }
}

$outputFullPath = [System.IO.Path]::GetFullPath($OutputIso)
$outputDir      = Split-Path -Parent $outputFullPath
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir -Force | Out-Null }

Write-Info "unattend.xml   : $UnattendSrc"
Write-Info "first_logon.ps1: $FirstLogonSrc"
Write-Info "출력 ISO       : $outputFullPath"

# ──────────────────────────────────────────────────────────────────────
# 임시 디렉터리에 ISO 콘텐츠 구성
#
#   <ISO 루트>/
#     unattend.xml          → C:\Windows\System32\Sysprep\unattend.xml
#     Scripts/
#       first_logon.ps1     → C:\Windows\Setup\Scripts\first_logon.ps1
#       SetupComplete.cmd   → C:\Windows\Setup\Scripts\SetupComplete.cmd
#     README.txt
# ──────────────────────────────────────────────────────────────────────
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("vmsetup-iso-{0}" -f [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    # unattend.xml (루트)
    Copy-Item -LiteralPath $UnattendSrc -Destination (Join-Path $tempRoot 'unattend.xml') -Force

    # Scripts 폴더
    $scriptsDir = Join-Path $tempRoot 'Scripts'
    New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    Copy-Item -LiteralPath $FirstLogonSrc -Destination (Join-Path $scriptsDir 'first_logon.ps1') -Force

    if (Test-Path $SetupCompleteSrc) {
        Copy-Item -LiteralPath $SetupCompleteSrc -Destination (Join-Path $scriptsDir 'SetupComplete.cmd') -Force
        Write-Info "setupcomplete.cmd 포함됨"
    } else {
        Write-Warn "setupcomplete.cmd 없음 — 건너뜁니다"
    }

    # README.txt
    $readme = Join-Path $tempRoot 'README.txt'
    Set-Content -LiteralPath $readme -Encoding Unicode -Value @"
Windows 11 VM 마스터 템플릿 Sysprep ISO
========================================

아키텍처:
  - 프로필 위치 : C:\Users (변경 없음)
  - 사용자 데이터: D:\UserData\{사용자명} (first_logon.ps1 이 리디렉션)
  - C 드라이브   : VirtualBox 스냅샷 대상
  - D 드라이브   : VirtualBox Writethrough (스냅샷 제외)

배치 방법 (Audit Mode PowerShell, 관리자):
  `$iso = (Get-Volume | Where-Object { `$_.FileSystemLabel -eq 'VMSETUP' }).DriveLetter + ':'
  Copy-Item "`$iso\unattend.xml"  'C:\Windows\System32\Sysprep\unattend.xml' -Force
  Copy-Item "`$iso\Scripts\*"     'C:\Windows\Setup\Scripts\'               -Force

Sysprep 실행:
  C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\System32\Sysprep\unattend.xml

로그 위치:
  C:\Windows\Logs\first_logon.log
  C:\Windows\Logs\setupcomplete.log
"@

    New-IsoFromDirectory -SourceDirectory $tempRoot -IsoPath $outputFullPath -IsoVolumeName $VolumeName
    Write-Ok "ISO 생성 완료: $outputFullPath"
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
