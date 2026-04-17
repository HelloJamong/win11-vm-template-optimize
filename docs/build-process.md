# Windows 11 VM 마스터 템플릿 생성 절차

이 문서는 VM 환경 기반 Windows 11 마스터 템플릿을 처음부터 생성하고, Audit Mode 최적화, Sysprep, 종료, VHD 후처리까지 진행하는 표준 절차입니다.

## 1. 사전 준비

- Windows 11 ISO
- VM 실행 환경
- 충분한 디스크 공간
- 조직 표준 VM 설정값
  - vCPU
  - Memory
  - TPM/Secure Boot
  - 그래픽/네트워크 설정
  - 기본 디스크 크기
- 이 저장소의 파일 일체
- 선택 후처리 도구
  - 7-Zip: `.pck` 보관 압축용
  - SDelete: 영공간 정리용, 기본 스크립트에는 포함하지 않음
  - 하이퍼바이저 전용 디스크 관리 도구: 디스크 compact용, 기본 스크립트에는 포함하지 않음

## 2. OS 설치

1. 사용 중인 VM 환경에서 새 Windows 11 VM을 생성합니다.
2. Windows 11 요구사항에 맞게 TPM, Secure Boot, CPU, Memory, Storage를 구성합니다.
3. Windows 11 ISO를 연결하고 VM을 부팅합니다.
4. 일반 Windows 설치 절차를 진행합니다.
5. 설치 대상 디스크에는 OS 파티션을 구성합니다.
6. 설치 완료 후 OOBE 화면이 나타날 때까지 기다립니다.

주의사항:

- 마스터 템플릿 생성 중에는 개인 사용자 계정을 만들지 않는 것이 원칙입니다.
- 네트워크 연결 여부는 조직 정책에 따릅니다.
- 망분리 환경에서는 온라인 계정 또는 Microsoft Store 의존 흐름이 발생하지 않도록 설치 절차를 사전에 검토합니다.

## 3. OOBE에서 Audit Mode 진입

OOBE 화면에서 다음 키를 입력합니다.

```text
Ctrl + Shift + F3
```

이 키 조합은 OOBE를 중단하고 Audit Mode로 재부팅하게 합니다. Audit Mode에서는 기본 Administrator 계정으로 로그인되며, 일반 사용자 계정 생성 전 상태에서 드라이버, 앱, 정책, 정리 작업을 수행할 수 있습니다.

Audit Mode 진입 후 Sysprep 창이 자동으로 표시될 수 있습니다. 아직 Sysprep을 실행하지 말고 창을 닫거나 최소화합니다.

## 4. Audit Mode 기본 점검

Audit Mode 진입 후 다음을 확인합니다.

- 관리자 권한 PowerShell 실행 가능 여부
- OS 빌드 및 에디션
- Windows 정품 인증 정책 상태
- 네트워크 연결 필요 여부
- VM 게스트 도구 설치 여부
- 디스크 구성 상태
- CD-ROM 드라이브 문자

예시 명령:

```powershell
winver
Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsBuildNumber
Get-Volume
```

## 5. 설치 미디어/게스트 도구 드라이브 문자 확인

Windows 설치 ISO 또는 VM 게스트 도구 ISO가 사용자 프로필용으로 사용할 드라이브 문자를 점유하고 있으면 별도 사용자 프로필 드라이브 구성이 꼬일 수 있습니다.

1. `diskmgmt.msc`를 실행합니다.
2. 설치 미디어 또는 게스트 도구 CD-ROM 드라이브를 선택합니다.
3. 조직 표준에 맞는 다른 드라이브 문자로 변경합니다.
4. 사용자 프로필용 파티션에 사용할 드라이브 문자가 비어 있는지 확인합니다.

PowerShell 또는 `diskpart`를 사용할 수도 있으나, 운영 절차에서는 디스크 관리 GUI로 변경 결과를 확인하는 방식을 권장합니다.

## 6. 별도 사용자 프로필 드라이브 생성 및 레이블 설정

데이터용 파티션을 생성하거나 기존 보조 디스크를 초기화해 사용자 프로필용 별도 드라이브로 할당합니다.

예시 절차:

1. 디스크 관리에서 새 단순 볼륨을 생성합니다.
2. 조직 표준에 맞는 드라이브 문자를 지정합니다.
3. NTFS로 포맷합니다.
4. 볼륨 레이블을 조직 표준 이름으로 지정합니다.

예시 확인 명령:

```powershell
Get-Volume
```

## 7. 별도 사용자 프로필 루트 준비

Sysprep 응답 파일에서 사용자 프로필 위치를 별도 사용자 프로필 드라이브의 사용자 폴더로 지정하기 전에 대상 폴더를 준비합니다. 아래 `<ProfileDrive>`는 실제 운영 드라이브 문자로 치환하십시오.

```powershell
New-Item -ItemType Directory -Path '<ProfileDrive>:\Users' -Force
icacls '<ProfileDrive>:\Users'
```

주의사항:

- 권한을 과도하게 조정하지 않습니다.
- 기존 사용자 프로필을 강제로 이동하지 않습니다.
- 일반 사용자 계정 생성 전 Sysprep 응답 파일로 위치를 지정하는 것이 원칙입니다.

## 8. unattend.xml 작성/배치

샘플 파일은 다음 위치에 있습니다.

```text
scripts\sysprep\unattend.xml
```

이 파일은 최소한 다음 값을 포함합니다.

- `ProfilesDirectory`: 별도 사용자 프로필 드라이브의 사용자 폴더. 샘플의 `<ProfileDrive>`를 실제 운영 드라이브 문자로 치환
- `TimeZone`: `Korea Standard Time`

권장 배치 위치:

```text
C:\Windows\System32\Sysprep\unattend.xml
```

복사 예시:

```powershell
Copy-Item '.\scripts\sysprep\unattend.xml' 'C:\Windows\System32\Sysprep\unattend.xml' -Force
```

## 9. 최적화 스크립트 실행

관리자 PowerShell에서 저장소 루트로 이동한 뒤 단일 스크립트의 모드를 지정해 실행합니다.

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\scripts\win11_master_template_optimize.ps1 --standard
```

`--standard`는 기본값이므로 옵션을 생략할 수 있습니다. 초기 검증 환경 또는 공공기관/망분리 기준선에서는 다음을 권장합니다.

```powershell
.\scripts\win11_master_template_optimize.ps1 --lite
```

스크립트 주요 작업:

- Temp/Cache 정리
- Windows Update 다운로드 캐시 정리
- Defender scan history 정리
- 이벤트 로그 초기화
- hibernation 비활성화
- Appx 제거
- Provisioned Appx 제거
- 서비스 비활성화
- 예약 작업 비활성화
- Search/Bing/Copilot/Recall/Consumer/privacy 정책 설정
- 전원 계획, 탐색기 개인정보, 시작 메뉴, 작업표시줄, 잠금화면 콘텐츠 정리
- cleanmgr 실행
- DISM component cleanup 실행

## 10. Sysprep 전 검증

`tests/validation-checklist.md`를 기준으로 다음을 확인합니다.

- 별도 사용자 프로필 드라이브의 사용자 폴더 존재 여부
- `unattend.xml` 경로 및 XML 구조
- 제거 대상 Appx 적용 결과
- 서비스 및 예약 작업 비활성화 결과
- `hiberfil.sys` 제거 여부
- 이벤트 로그 초기화 실행 여부
- Administrator/defaultuser0 처리 계획
- Sysprep 로그에 이전 오류가 남아 있는지 여부

Sysprep 전에는 불필요한 재부팅을 최소화하고, 필요한 경우 스냅샷을 생성합니다.

## 11. Sysprep 실행

관리자 명령 프롬프트에서 다음 명령을 실행합니다.

```cmd
C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\System32\Sysprep\unattend.xml
```

옵션 의미:

- `/generalize`: SID, 장치 고유 정보 등 일반화
- `/oobe`: 다음 부팅 시 OOBE로 진입
- `/shutdown`: Sysprep 완료 후 종료
- `/unattend`: 응답 파일 지정

## 12. 최종 종료

Sysprep이 정상 완료되면 VM이 종료됩니다. 이 상태가 마스터 템플릿 기준 상태입니다.

중요:

- 종료 후 원본 VM을 다시 부팅하지 않습니다.
- 먼저 디스크 파일을 복제하거나 스냅샷/템플릿 정책을 적용합니다.
- 원본을 부팅하면 OOBE가 진행되어 템플릿 상태가 변경될 수 있습니다.

## 13. 이후 외부 후처리 개요

기본 스크립트에는 외부 도구 실행이 포함되지 않습니다. 필요 시 아래를 별도 절차로 수행합니다.

### 13.1 영공간 정리

SDelete 같은 도구를 사용해 미사용 영역을 zero-fill할 수 있습니다. 단, 보안 정책상 외부 도구 반입이 허용되는지 확인해야 합니다.

### 13.2 VM 디스크 compact

VHD/VHDX 또는 사용 중인 VM 디스크 포맷과 운영 방식에 따라 하이퍼바이저 전용 compact 또는 clone 작업을 검토합니다. 이 작업은 하이퍼바이저 후처리이며 Windows 내부 최적화 스크립트에는 포함하지 않습니다.

### 13.3 압축 보관

7-Zip 실행 파일이 있는 별도 보관 폴더에서 다음 스크립트를 사용할 수 있습니다.

```cmd
scripts\compress\compack.bat path\to\disk.vhdx
```

압축 결과는 `.pck` 확장자로 생성됩니다.

### 13.4 복원 검증

압축 파일은 반드시 해제 테스트를 수행합니다.

```cmd
scripts\compress\extract.bat path\to\disk.pck
```

`tests/post-build-checklist.md` 기준으로 최종 결과를 기록합니다.
