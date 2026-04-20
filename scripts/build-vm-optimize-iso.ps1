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

# ── 안내 메세지 ────────────────────────────────────────────────

$isoSourceDir = Join-Path $PSScriptRoot '_iso'

Write-Host ''
Write-Host ('=' * 60) -ForegroundColor DarkCyan
Write-Host '  VM Optimize ISO 생성기' -ForegroundColor Cyan
Write-Host ('=' * 60) -ForegroundColor DarkCyan
Write-Host ''
Write-Host '  ISO에 포함할 파일을 다음 폴더에 배치하십시오:' -ForegroundColor White
Write-Host "  $isoSourceDir" -ForegroundColor Yellow
Write-Host ''
Write-Host '  배치 파일 예시:' -ForegroundColor Gray
Write-Host '    - win11_master_template_optimize.ps1' -ForegroundColor Gray
Write-Host '    - sdelete64.exe' -ForegroundColor Gray
Write-Host ''

$answer = Read-Host '  파일을 배치했습니까? 계속하시겠습니까? [Y/n]'

if ($answer -notmatch '^[Yy]$' -and $answer -ne '') {
    Write-Warn '취소되었습니다.'
    exit 0
}

# ── 유효성 검사 ───────────────────────────────────────────────

if (-not (Test-Path -LiteralPath $isoSourceDir)) {
    Write-Err "_iso 폴더가 존재하지 않습니다: $isoSourceDir"
    Write-Err "위 경로에 _iso 폴더를 생성하고 파일을 배치한 뒤 다시 실행하십시오."
    exit 1
}

$sourceFiles = Get-ChildItem -LiteralPath $isoSourceDir -File -ErrorAction SilentlyContinue
if ($sourceFiles.Count -eq 0) {
    Write-Err "_iso 폴더가 비어 있습니다: $isoSourceDir"
    Write-Err "ISO에 포함할 파일을 _iso 폴더에 배치한 뒤 다시 실행하십시오."
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
$sourceFiles | ForEach-Object { Write-Info "  - $($_.Name)" }
Write-Info "출력 ISO: $outputFullPath"
Write-Info "볼륨 이름: $VolumeName"

New-IsoFromDirectory -SourceDirectory $isoSourceDir `
                     -IsoPath $outputFullPath `
                     -IsoVolumeName $VolumeName

Write-Host ''
Write-Info "ISO 생성 완료: $outputFullPath"
