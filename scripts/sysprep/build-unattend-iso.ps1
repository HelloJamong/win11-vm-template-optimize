<#
.SYNOPSIS
    Sysprep unattend.xml 템플릿을 VM에 연결 가능한 ISO 파일로 생성합니다.

.DESCRIPTION
    scripts/sysprep/unattend.xml의 <ProfileDrive> 자리표시자를 실제 드라이브 문자로 치환한 뒤,
    Windows IMAPI2 COM API를 사용해 별도 외부 도구 없이 ISO 파일을 생성합니다.

.PARAMETER ProfileDrive
    사용자 프로필 루트가 생성될 별도 드라이브 문자입니다. 예: E, F

.PARAMETER TemplatePath
    원본 unattend.xml 템플릿 경로입니다.

.PARAMETER OutputIso
    생성할 ISO 파일 경로입니다. 기본값은 scripts/sysprep/unattend.iso 입니다.

.PARAMETER VolumeName
    ISO 볼륨 이름입니다. 기본값은 UNATTEND 입니다.

.EXAMPLE
    .\build-unattend-iso.ps1 -ProfileDrive E

.EXAMPLE
    .\build-unattend-iso.ps1 -ProfileDrive F -OutputIso .\out\unattend-F.iso

.NOTES
    - Windows PowerShell에서 실행해야 합니다. IMAPI2 COM API가 필요합니다.
    - 생성된 ISO 안에는 치환 완료된 unattend.xml 파일이 루트에 포함됩니다.
    - 생성된 ISO는 VM의 가상 CD/DVD 드라이브에 연결한 뒤 Audit Mode에서 복사해 사용할 수 있습니다.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z]$')]
    [string]$ProfileDrive,

    [string]$TemplatePath = (Join-Path $PSScriptRoot 'unattend.xml'),

    [string]$OutputIso = (Join-Path $PSScriptRoot 'unattend.iso'),

    [ValidatePattern('^[A-Za-z0-9_\-]{1,32}$')]
    [string]$VolumeName = 'UNATTEND'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message"
}

function Save-IStreamToFile {
    param(
        [Parameter(Mandatory = $true)]$ImageStream,
        [Parameter(Mandatory = $true)][string]$Path
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
                    if (bytesRead <= 0)
                    {
                        break;
                    }
                    file.Write(buffer, 0, bytesRead);
                }
            }
        }
        finally
        {
            Marshal.FreeHGlobal(bytesReadPtr);
        }
    }
}
'@
    }

    [IStreamFileWriter]::Save($ImageStream, $Path)
}

function New-IsoFromDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDirectory,
        [Parameter(Mandatory = $true)][string]$IsoPath,
        [Parameter(Mandatory = $true)][string]$IsoVolumeName
    )

    $fileSystemImage = $null
    $resultImage = $null

    try {
        $fileSystemImage = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
        # ISO9660(1) + Joliet(2) + UDF(4). 단일 unattend.xml이므로 호환성을 위해 모두 활성화합니다.
        $fileSystemImage.FileSystemsToCreate = 7
        $fileSystemImage.VolumeName = $IsoVolumeName
        $fileSystemImage.Root.AddTree($SourceDirectory, $false)

        $resultImage = $fileSystemImage.CreateResultImage()
        Save-IStreamToFile -ImageStream $resultImage.ImageStream -Path $IsoPath
    }
    finally {
        if ($resultImage) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($resultImage) }
        if ($fileSystemImage) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($fileSystemImage) }
    }
}

$resolvedTemplate = Resolve-Path -LiteralPath $TemplatePath
$outputFullPath = [System.IO.Path]::GetFullPath($OutputIso)
$outputDirectory = Split-Path -Parent $outputFullPath

if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$driveLetter = $ProfileDrive.ToUpperInvariant()
$templateContent = Get-Content -LiteralPath $resolvedTemplate -Raw -Encoding UTF8
$generatedContent = $templateContent `
    -replace '&lt;ProfileDrive&gt;', $driveLetter `
    -replace '<ProfileDrive>', $driveLetter

try {
    [xml]$xmlCheck = $generatedContent
    [void]$xmlCheck
}
catch {
    throw "치환된 unattend.xml이 올바른 XML이 아닙니다: $($_.Exception.Message)"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("unattend-iso-{0}" -f ([guid]::NewGuid().ToString('N')))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    $generatedXmlPath = Join-Path $tempRoot 'unattend.xml'
    Set-Content -LiteralPath $generatedXmlPath -Value $generatedContent -Encoding UTF8

    $readmePath = Join-Path $tempRoot 'README.txt'
    Set-Content -LiteralPath $readmePath -Encoding UTF8 -Value @"
Windows 11 VM Sysprep unattend ISO

- unattend.xml ProfilesDirectory: ${driveLetter}:\Users
- VM에 이 ISO를 연결한 뒤 Audit Mode에서 unattend.xml을 C:\Windows\System32\Sysprep\unattend.xml로 복사해 사용하십시오.
- Sysprep 전 ${driveLetter}: 드라이브와 ${driveLetter}:\Users 폴더가 존재해야 합니다.
"@

    Write-Info "ProfileDrive: ${driveLetter}:"
    Write-Info "Template: $resolvedTemplate"
    Write-Info "Output ISO: $outputFullPath"
    New-IsoFromDirectory -SourceDirectory $tempRoot -IsoPath $outputFullPath -IsoVolumeName $VolumeName
    Write-Info 'ISO 생성 완료'
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
