# Windows 11 VM 마스터 템플릿 최적화

VM 환경 기반 Windows 11 마스터 템플릿을 일관되게 생성하기 위한 자동화 스크립트와 운영 문서 모음입니다. 이 저장소는 Audit Mode에서 템플릿을 정리하고, Sysprep 및 `unattend.xml`을 통해 사용자 프로필 위치를 OS 드라이브가 아닌 별도 사용자 프로필 드라이브로 구성한 뒤, 종료 및 VHD 후처리까지 이어지는 표준 절차를 제공합니다.

## 1. 프로젝트 개요

이 프로젝트는 Windows 11을 새로 설치한 뒤 조직에서 재사용 가능한 VM 마스터 템플릿을 만들기 위한 기준 절차를 정리합니다. 기본 스크립트는 PowerShell 중심으로 구성되어 외부 상용 도구에 의존하지 않으며, 공공기관 및 망분리 환경에서 문제가 될 수 있는 과도한 기능 제거는 단일 스크립트의 모드 옵션으로 분리합니다.

주요 산출물은 다음과 같습니다.

- Windows 11 설치 후 Audit Mode 작업 절차 문서
- 별도 사용자 프로필 드라이브 기반 사용자 프로필 생성을 위한 Sysprep `unattend.xml` 템플릿
- 템플릿 종료 전 임시 파일, 업데이트 캐시, Defender 기록, 이벤트 로그 등 정리 스크립트
- Appx, Provisioned Appx, 서비스, 예약 작업, 검색/Bing/Copilot/Recall/개인정보 정책 조정 기준
- Sysprep, 종료, VHD 후처리 및 보관까지 이어지는 표준 절차 문서화

## 2. 프로젝트가 해결하려는 문제

Windows 11 VM 템플릿을 수작업으로 만들면 다음 문제가 반복됩니다.

1. 작업자별 절차 편차로 인해 템플릿 품질이 달라집니다.
2. Sysprep 전후 정리 항목이 누락되어 용량이 커지고 개인정보성 흔적이 남을 수 있습니다.
3. 사용자 프로필 위치를 뒤늦게 레지스트리로 강제 변경하여 업데이트, Store 앱, Sysprep 호환성 문제가 발생할 수 있습니다.
4. 공공기관/망분리 환경에서 클라우드 검색, 소비자 기능, 불필요 앱이 남아 감사 대응 부담이 증가합니다.
5. VHD 후처리 및 보관 과정이 문서화되지 않아 재현성과 변경 추적이 어렵습니다.

이 저장소는 위 문제를 줄이기 위해 “절차 문서 + 보수적 기본값 + 옵션화된 자동화 + 변경 이력” 형태로 운영 기준을 제공합니다.

## 3. 주요 기능

- Audit Mode 진입 및 템플릿 작업 흐름 문서화
- `unattend.xml`을 사용한 별도 사용자 프로필 드라이브 구성 예시 제공
- PowerShell 기반 템플릿 최적화 스크립트 제공
- `--lite`, `--standard`, `--advanced` 모드를 제공하는 단일 PowerShell 스크립트
- 임시 파일, 업데이트 캐시, Defender 검사 기록, 이벤트 로그 정리
- Windows Appx 및 Provisioned Appx 제거 후보 관리
- 서비스 및 예약 작업 비활성화 후보 관리
- 검색/Bing/Copilot/Recall/소비자 기능/개인정보/전원/탐색기/시작 메뉴/작업표시줄 관련 정책 참조 제공
- Sysprep 전후 검증 기준은 통합 가이드에서 안내
- VHD 후처리 기준은 통합 가이드에서 안내

## 4. 지원 범위

본 프로젝트는 다음 범위를 대상으로 합니다.

- Windows 11 VM 템플릿
- VM 환경 기반 마스터 이미지 운영
- Windows OOBE 단계에서 Audit Mode 진입
- Sysprep + `unattend.xml` 기반 초기 구성
- OS 드라이브가 아닌 별도 사용자 프로필 드라이브 구성
- 데이터 정리, 성능 최적화, 앱 제거, 정책 설정
- 공공기관/망분리 환경을 고려한 보수적 기본 정책

다음 항목은 기본 스크립트 범위에 포함하지 않습니다.

- 외부 상용 도구 기반 최적화
- SDelete 기반 영공간 정리 자동 실행
- 하이퍼바이저 전용 디스크 compact 자동 실행
- 조직별 보안 제품, NAC, DLP 등 에이전트 설치
- Windows 라이선스 인증

외부 도구가 필요한 작업은 문서상 후처리 단계에서만 언급합니다.

## 5. 디렉터리 구조 설명

```text
win11-vm-template-optimize/
├─ README.md
├─ LICENSE
├─ NOTICE.md
├─ CHANGELOG.md
├─ .gitignore
├─ docs/
│  └─ guide.md
├─ scripts/
│  ├─ win11_master_template_optimize.ps1   ← Audit Mode 최적화 (단일 스크립트)
│  └─ sysprep/
│     ├─ unattend.xml                      ← Sysprep 응답 파일 (CopyProfile=true)
│     ├─ first_logon.ps1                   ← 최초 로그인 자동화 (D:\UserData 리디렉션)
│     ├─ setupcomplete.cmd                 ← Setup 완료 후 사전 준비 훅
│     └─ build-unattend-iso.ps1            ← vmsetup.iso 생성 도구
├─ configs/
│  ├─ appx-remove-list.txt
│  ├─ services-disable-list.txt
│  ├─ tasks-disable-list.txt
│  └─ registry-tweaks-reference.md
```

- `CHANGELOG.md`: 연도.메이저버전.마이너버전 형식의 공식 변경 이력
- `docs/guide.md`: 템플릿 생성, 정리 항목, Sysprep, 감사 대응을 통합한 운영 가이드
- `scripts/win11_master_template_optimize.ps1`: Audit Mode에서 실행하는 단일 최적화 스크립트
- `scripts/sysprep/`: Sysprep 응답 파일, 최초 로그인 스크립트, ISO 생성 도구 모음
- `configs/`: 제거/비활성화 후보 목록 및 정책 레지스트리 설명

## 6. 사용 흐름

### 6.1 OS 설치

1. 사용 중인 VM 환경에서 Windows 11 VM을 새로 생성합니다.
2. TPM, Secure Boot, CPU, 메모리, 디스크 크기 등 조직 기준에 맞게 VM 설정을 구성합니다.
3. Windows 11 ISO로 부팅해 일반 설치를 진행합니다.
4. 설치 중 네트워크 연결 여부는 조직 정책에 맞춥니다. 망분리 환경에서는 오프라인 설치 흐름을 우선 검토합니다.

### 6.2 OOBE 진입

Windows 설치가 끝나고 국가/키보드/네트워크/계정 생성을 요구하는 OOBE 화면에 도달하면 일반 사용자 계정을 만들지 않습니다. 마스터 템플릿 작업은 OOBE에서 Audit Mode로 전환한 뒤 수행합니다.

### 6.3 Audit Mode 진입

OOBE 화면에서 다음 키를 입력합니다.

```text
Ctrl + Shift + F3
```

시스템이 재부팅되며 기본 Administrator 계정으로 Audit Mode에 진입합니다. Sysprep 창이 자동으로 열릴 수 있으나, 작업이 끝나기 전까지 닫거나 최소화합니다.

### 6.4 D 드라이브(UserData) 구성

이전 방식(ProfilesDirectory로 C:\Users 전체를 D로 이동)은 VirtualBox 스냅샷 구조, Sysprep, Store 앱과 충돌하므로 사용하지 않습니다.

**현재 아키텍처:**

| 항목 | 경로 | 드라이브 용도 |
|------|------|--------------|
| 사용자 프로필 | `C:\Users\{사용자명}` | C (스냅샷 대상) |
| 사용자 데이터 | `D:\UserData\{사용자명}` | D (Writethrough, 스냅샷 제외) |

- `C:\Users`는 절대 이동하지 않습니다. Sysprep, AppData, 프로필 레지스트리가 이 경로에 의존합니다.
- Desktop, Documents, Downloads 등 실제 데이터 폴더만 D 드라이브로 리디렉션합니다.
- 리디렉션은 `first_logon.ps1`이 최초 로그인 시 자동 처리합니다.

**Audit Mode에서 D 드라이브 준비:**

```powershell
# D 드라이브가 없으면 diskpart 또는 디스크 관리에서 먼저 파티션을 생성합니다.
# first_logon.ps1이 D:\UserData\{사용자명} 하위 폴더를 자동 생성하므로
# Audit Mode 단계에서는 D 드라이브 자체만 준비하면 됩니다.
```

### 6.5 Sysprep 파일 배치 (ISO 사용)

`scripts/sysprep/build-unattend-iso.ps1`로 `vmsetup.iso`를 생성합니다. 이 ISO에는 `unattend.xml`, `first_logon.ps1`, `SetupComplete.cmd`가 포함됩니다.

```powershell
# 호스트 또는 Audit Mode PowerShell에서 실행
.\scripts\sysprep\build-unattend-iso.ps1
# 출력: scripts/sysprep/vmsetup.iso
```

ISO를 VM에 마운트한 뒤 Audit Mode 관리자 PowerShell에서 배치합니다.

```powershell
$iso = (Get-Volume | Where-Object { $_.FileSystemLabel -eq 'VMSETUP' }).DriveLetter + ':'
Copy-Item "$iso\unattend.xml" 'C:\Windows\System32\Sysprep\unattend.xml' -Force
Copy-Item "$iso\Scripts\*"    'C:\Windows\Setup\Scripts\'                -Force
```

또는 수동으로 파일을 직접 복사해도 됩니다.

```text
scripts/sysprep/unattend.xml       → C:\Windows\System32\Sysprep\unattend.xml
scripts/sysprep/first_logon.ps1    → C:\Windows\Setup\Scripts\first_logon.ps1
scripts/sysprep/setupcomplete.cmd  → C:\Windows\Setup\Scripts\SetupComplete.cmd
```

**`first_logon.ps1` 역할:**

최초 로그인 시 `unattend.xml`의 `FirstLogonCommands`에 의해 자동 실행됩니다.

1. `D:\UserData\{사용자명}` 폴더 구조 생성
2. Desktop / Documents / Downloads / Pictures / Videos / Music → D 드라이브로 리디렉션
3. Appx 불필요 앱 제거 (Xbox, PhoneLink, Copilot, Teams, Clipchamp)
4. Provisioned Appx 제거 (신규 사용자 자동 설치 차단)
5. HKCU 설정 재적용 (Search, Copilot, Consumer Experience, Telemetry, Explorer)
6. Explorer 재시작
7. 재실행 방지 플래그 설정 (`HKCU:\Software\VMTemplateSetup\FirstLogonComplete`)

로그는 `C:\Windows\Logs\first_logon.log`에 기록됩니다.

### 6.6 최적화 스크립트 실행

#### 실행 정책(Execution Policy) 설정

Windows PowerShell은 기본적으로 스크립트 실행을 제한합니다. 실행 전 다음 오류가 발생하면 실행 정책 설정이 필요합니다.

```text
이 시스템에서 스크립트를 실행할 수 없으므로 파일을 로드할 수 없습니다.
```

**권장 방법 — 현재 세션에만 임시 적용 (Scope: Process)**

가장 안전한 방법입니다. PowerShell 창을 닫으면 자동으로 원복됩니다.

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

**대안 — 현재 사용자에게 영구 적용 (Scope: CurrentUser)**

세션이 닫혀도 설정이 유지됩니다. 작업 후 원복을 권장합니다.

```powershell
# 적용
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
# 작업 완료 후 원복
Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser -Force
```

**인터넷에서 내려받은 스크립트인 경우**

파일에 Zone.Identifier(인터넷 다운로드 표시)가 붙어 있으면 별도로 차단 해제가 필요합니다.

```powershell
Unblock-File -Path .\scripts\win11_master_template_optimize.ps1
```

#### 스크립트 실행

Audit Mode의 관리자 PowerShell에서 다음과 같이 실행합니다.

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
cd C:\Path\To\win11-vm-template-optimize
.\scripts\win11_master_template_optimize.ps1 --standard
```

`--standard`는 기본값이므로 옵션을 생략해도 동일하게 동작합니다. 공공기관/망분리 환경의 최초 도입 또는 영향도 검토 전에는 `--lite`를 권장합니다. 더 강한 정리/비활성화가 필요하고 복제 VM 검증이 가능한 경우에만 `--advanced`를 사용합니다.

### 6.7 Sysprep

스크립트 실행 후 별도 관리 중인 검증 문서와 `docs/guide.md`의 검증 기준을 참고해 Sysprep 전 상태를 확인합니다. 문제가 없으면 다음 명령을 실행합니다.

```cmd
C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\System32\Sysprep\unattend.xml
```

### 6.8 종료

Sysprep이 완료되면 VM은 자동 종료됩니다. 종료된 상태를 마스터 템플릿의 기준 상태로 간주합니다. 이 시점 이후 원본 VM을 부팅하면 OOBE/Sysprep 상태가 변경될 수 있으므로, 먼저 디스크 파일을 복제하거나 스냅샷 정책을 따릅니다.

### 6.9 VHD 후처리

최적화 스크립트 실행 및 Sysprep 종료 후 VHD 파일 크기를 줄이려면 다음 순서로 후처리를 수행합니다.

#### 1단계: SDelete로 여유 공간 Zero-Fill

SDelete는 Microsoft Sysinternals에서 제공하는 공식 도구입니다.

- 다운로드: [https://learn.microsoft.com/en-us/sysinternals/downloads/sdelete](https://learn.microsoft.com/en-us/sysinternals/downloads/sdelete)

VM이 종료되기 전 마지막 단계로 관리자 PowerShell에서 실행합니다.

```cmd
sdelete64.exe -z C:
```

- `-z` 옵션은 여유 공간을 0으로 채워 VHD compact 시 실제 사용 블록만 남깁니다.
- 실행 후 추가 파일 쓰기 없이 즉시 VM을 종료해야 효과가 유지됩니다.
- 소요 시간은 디스크 여유 공간 크기에 따라 달라집니다.
- 망분리 환경에서는 sdelete 실행 파일을 별도 반입 절차를 통해 준비합니다.

#### 2단계: VHD Compact

VM이 완전히 종료된 상태에서 사용 중인 하이퍼바이저의 디스크 관리 도구로 compact을 수행합니다.

#### 3단계: 보관

조직 표준 도구와 절차를 별도로 사용합니다.

## 7. 스크립트 모드 설명

### --lite

장애 가능성이 낮은 항목만 활성화한 보수적 모드입니다.

- 임시 파일 및 업데이트 캐시 정리
- Defender 검사 기록 정리
- hibernation 비활성화
- 보수적 정책 설정
- Appx/서비스/예약 작업 제거 및 비활성화는 제한적
- Optional Feature 비활성화, pagefile 비활성화, CompactOS 등 영향도 큰 항목은 비활성화

공공기관/망분리 환경의 초기 기준선으로 권장합니다.

실행 예시:

```powershell
.\scripts\win11_master_template_optimize.ps1 --lite
```

### --standard

일반적인 마스터 템플릿에 권장되는 균형형 기본 모드입니다.

- 정리 항목 대부분 활성화
- Appx 및 Provisioned Appx 제거 후보 적용
- 서비스 및 예약 작업 비활성화 후보 적용
- Search/Bing/Copilot/Recall/Consumer/privacy 정책 적용
- 전원 계획, 탐색기 개인정보, 시작 메뉴, 작업표시줄, 잠금화면 콘텐츠 정리
- cleanmgr 및 DISM cleanup 실행

업무 앱 호환성 테스트가 가능한 환경에서 기본 후보로 사용합니다. 옵션을 생략하면 `--standard`로 동작합니다.

실행 예시:

```powershell
.\scripts\win11_master_template_optimize.ps1
.\scripts\win11_master_template_optimize.ps1 --standard
```

### --advanced

더 강한 정리와 비활성화를 수행하는 고강도 모드입니다.

- 불필요 앱 및 provisioned package 제거 범위 확대
- 이벤트 로그 초기화 포함
- 예약 작업 및 소비자 기능 비활성화 강화
- CompactOS 등 용량 최적화 옵션을 검토 대상으로 포함

이 모드는 업무 앱, 보안 에이전트, Windows 업데이트, Store 앱 의존성이 있는 환경에서 장애를 유발할 수 있습니다. 운영 반영 전 반드시 복제 VM에서 검증하십시오.

실행 예시:

```powershell
.\scripts\win11_master_template_optimize.ps1 --advanced
```

## 8. 주의사항

- 공공기관/망분리 환경에서는 클라우드 연동, 소비자 경험, 광고성 구성요소, Copilot, Recall, Bing 검색을 제한하는 방향이 적합할 수 있으나, 조직 정책 및 감사 기준을 우선합니다.
- 일부 Appx 또는 Provisioned Appx 제거는 업무 앱, Windows 기능, 파일 연결, Store 기반 업데이트에 영향을 줄 수 있습니다.
- 서비스 비활성화는 부팅 시간과 리소스 사용량을 줄일 수 있지만, 진단, 업데이트, 보안 제품 연동에 영향을 줄 수 있습니다.
- 이벤트 로그 초기화는 마스터 템플릿 배포 전 흔적 제거에는 유용하지만, 감사 추적이 필요한 단계에서는 실행 시점을 기록해야 합니다.
- SDelete, 하이퍼바이저 전용 디스크 관리 도구 등 외부 도구는 기본 최적화 스크립트에 포함하지 않습니다. 필요 시 별도 후처리 단계에서 수동으로 사용합니다.
- Sysprep 실패 시 `C:\Windows\System32\Sysprep\Panther` 로그를 먼저 확인합니다.
- `ProfileList` 레지스트리를 직접 강제 수정하는 방식은 비권장합니다. 사용자 프로필 위치는 Sysprep 응답 파일로 구성합니다.

## 9. 참고 프로젝트 및 라이선스

이 저장소의 코드는 자체 작성되었으며, 저장소 자체 코드에는 MIT License를 적용합니다. 다음 프로젝트는 아이디어, 구성 방식, 최적화 방향을 참고했습니다.

### MIT 라이선스 프로젝트 참고

- Win11Debloat: [프로젝트 바로가기](https://github.com/Raphire/Win11Debloat)
  - 라이선스: MIT License
  - 참고 범위: Windows 10/11 불필요 앱 제거, 개인정보/소비자 기능 조정 방향
  - 본 저장소에는 원본 소스를 그대로 포함하지 않습니다.
- WinUtil: [프로젝트 바로가기](https://github.com/ChrisTitusTech/winutil)
  - 라이선스: MIT License
  - 참고 범위: Windows 최적화 옵션 분류, 사용자 선택형 튜닝 구성 방식
  - 본 저장소에는 원본 소스를 그대로 포함하지 않습니다.

### 개념 참고

- Virtual-Desktop-Optimization-Tool: [프로젝트 바로가기](https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool)
  - 참고 범위: 가상 데스크톱/VDI 환경에서 성능 관련 설정을 분류하고 적용하는 운영 개념
  - 직접 코드, 설정 파일, 원본 스크립트는 포함하지 않습니다.

자세한 고지는 `NOTICE.md`를 참조하십시오. 운영 절차는 `docs/guide.md`를 기준으로 관리합니다.

## 10. 향후 계획

- Windows 11 버전별 Appx 제거 영향도 매트릭스 작성
- Sysprep 실패 사례와 조치 가이드 확장
- 오프라인/망분리 환경용 패키지 반입 기준 문서 보강
- PowerShell Pester 기반 정적 검증 테스트 추가
- VHD 후처리 절차와 조직 표준 보관 검증 문서 보강
- `CHANGELOG.md` 기반 릴리스 노트 운영
