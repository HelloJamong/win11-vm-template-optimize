<#
.SYNOPSIS
    _iso 폴더의 파일들을 VM에 전달할 ISO 파일로 생성합니다.

.DESCRIPTION
    스크립트와 같은 경로의 _iso 디렉터리에 있는 파일 전체를 Windows IMAPI2 COM API로
    ISO 파일로 묶습니다. 외부 도구 없이 Windows 기본 환경에서만 동작합니다.

    ISO에 담길 파일 예시:
      _iso\win11_master_template_optimize.ps1
      _iso\sdelete64.exe

.PARAMETER OutputIso
    생성할 ISO 파일 경로입니다.
    기본값은 스크립트와 같은 경로의 VM_optimize.iso입니다.

.PARAMETER VolumeName
    ISO 볼륨 이름입니다. 기본값은 VM_OPTIMIZE 입니다.

.EXAMPLE
    .\build-vm-optimize-iso.ps1

.EXAMPLE
    .\build-vm-optimize-iso.ps1 -OutputIso D:\output\VM_optimize.iso

.NOTES
    - Windows PowerShell에서 실행해야 합니다. IMAPI2 COM API가 필요합니다.
    - 생성된 ISO는 VM의 가상 CD/DVD 드라이브에 연결해 사용합니다.
#>

[CmdletBinding()]
param(
    [string]$OutputIso = (Join-Path $PSScriptRoot 'VM_optimize.iso'),

    [ValidatePattern('^[A-Za-z0-9_\-]{1,32}$')]
    [string]$VolumeName = 'VM_OPTIMIZE'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

function Write-Info  { param([string]$m) Write-Host "[INFO] $m" }
function Write-Warn  { param([string]$m) Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err   { param([string]$m) Write-Host "[ERROR] $m" -ForegroundColor Red }

function Save-IStreamToFile {
    param(
        [Parameter(Mandatory = $true)]$ImageStream,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not ('IStreamFileWriter2' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

public static class IStreamFileWriter2
{
    public static void Save(object sourceStream, string outputPath)
    {
        IStream stream = (IStream)sourceStream;
        byte[] buffer = new byte[1024 * 1024];
        IntPtr bytesReadPtr = Marshal.AllocHGlobal(sizeof(int));
        try
        {
            using (FileStream file = File.Create(outputPath))
            {
                while (true)
                {
                    stream.Read(buffer, buffer.Length, bytesReadPtr);
                    int bytesRead = Marshal.ReadInt32(bytesReadPtr);
                    if (bytesRead <= 0) break;
                    file.Write(buffer, 0, bytesRead);
                }
            }
        }
        finally { Marshal.FreeHGlobal(bytesReadPtr); }
    }
}
'@
    }

    [IStreamFileWriter2]::Save($ImageStream, $Path)
}

function New-IsoFromDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDirectory,
        [Parameter(Mandatory = $true)][string]$IsoPath,
        [Parameter(Mandatory = $true)][string]$IsoVolumeName
    )

    $fsi = $null
    $resultImage = $null

    try {
        $fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
        $fsi.FileSystemsToCreate = 7
        $fsi.VolumeName = $IsoVolumeName
        $fsi.Root.AddTree($SourceDirectory, $false)

        $resultImage = $fsi.CreateResultImage()
        Save-IStreamToFile -ImageStream $resultImage.ImageStream -Path $IsoPath
    }
    finally {
        if ($resultImage) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($resultImage) }
        if ($fsi)         { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($fsi) }
    }
}

# ── 경로 설정 ─────────────────────────────────────────────────

$isoSourceDir  = Join-Path $PSScriptRoot '_iso'
$repoRoot      = Split-Path $PSScriptRoot -Parent
$mainScript    = Join-Path $PSScriptRoot 'win11_master_template_optimize.ps1'
$configsSrc    = Join-Path $repoRoot 'configs'

# ── 안내 메세지 ────────────────────────────────────────────────

Write-Host ''
Write-Host ('=' * 60) -ForegroundColor DarkCyan
Write-Host '  VM Optimize ISO 생성기' -ForegroundColor Cyan
Write-Host ('=' * 60) -ForegroundColor DarkCyan
Write-Host ''
Write-Host '  다음 파일은 자동으로 _iso 폴더에 복사됩니다:' -ForegroundColor White
Write-Host '    - win11_master_template_optimize.ps1' -ForegroundColor Gray
Write-Host '    - configs\ (appx / services / tasks 목록)' -ForegroundColor Gray
Write-Host ''
Write-Host '  sdelete64.exe는 수동으로 아래 폴더에 배치하십시오:' -ForegroundColor White
Write-Host "  $isoSourceDir" -ForegroundColor Yellow
Write-Host ''

$answer = Read-Host '  계속하시겠습니까? [Y/n]'

if ($answer -notmatch '^[Yy]$' -and $answer -ne '') {
    Write-Warn '취소되었습니다.'
    exit 0
}

# ── 파일 자동 복사 ────────────────────────────────────────────

if (-not (Test-Path -LiteralPath $isoSourceDir)) {
    New-Item -ItemType Directory -Path $isoSourceDir -Force | Out-Null
    Write-Info "_iso 폴더를 생성했습니다: $isoSourceDir"
}

if (-not (Test-Path -LiteralPath $mainScript)) {
    Write-Err "메인 스크립트를 찾을 수 없습니다: $mainScript"
    exit 1
}
Copy-Item -LiteralPath $mainScript -Destination $isoSourceDir -Force
Write-Info "복사 완료: win11_master_template_optimize.ps1"

if (-not (Test-Path -LiteralPath $configsSrc)) {
    Write-Err "configs 폴더를 찾을 수 없습니다: $configsSrc"
    exit 1
}
$configsDst = Join-Path $isoSourceDir 'configs'
Copy-Item -LiteralPath $configsSrc -Destination $configsDst -Recurse -Force
Write-Info "복사 완료: configs\"

# ── 유효성 검사 ───────────────────────────────────────────────

$sourceFiles = Get-ChildItem -LiteralPath $isoSourceDir -Recurse -File -ErrorAction SilentlyContinue
if ($sourceFiles.Count -eq 0) {
    Write-Err "_iso 폴더가 비어 있습니다: $isoSourceDir"
    exit 1
}

# ── 실행 ─────────────────────────────────────────────────────

$outputFullPath = [System.IO.Path]::GetFullPath($OutputIso)
$outputDirectory = Split-Path -Parent $outputFullPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

Write-Host ''
Write-Info "포함 파일 목록:"
$sourceFiles | ForEach-Object {
    $rel = $_.FullName.Substring($isoSourceDir.Length + 1)
    Write-Info "  - $rel"
}
Write-Info "출력 ISO: $outputFullPath"
Write-Info "볼륨 이름: $VolumeName"

New-IsoFromDirectory -SourceDirectory $isoSourceDir `
                     -IsoPath $outputFullPath `
                     -IsoVolumeName $VolumeName

Write-Host ''
Write-Info "ISO 생성 완료: $outputFullPath"
