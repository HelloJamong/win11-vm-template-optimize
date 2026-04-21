# Windows 11 VM 마스터 템플릿 통합 가이드

이 문서는 Windows 11 VM 마스터 템플릿 생성 절차를 처음부터 끝까지 설명합니다.
Audit Mode 작업, 최적화 스크립트 실행, Sysprep, 최초 로그인 자동화, VHD 후처리까지
모든 단계를 한 곳에 정리했습니다.

---

## 1. 아키텍처 개요

### 드라이브 구조

| 드라이브 | 용도 | VirtualBox 설정 |
|----------|------|----------------|
| C:\ | OS + 사용자 프로필(`C:\Users`) | 스냅샷 대상 |
| D:\ | 사용자 데이터(`D:\UserData\{사용자명}`) | **Writethrough** (스냅샷 제외) |

### 설계 원칙

- `C:\Users`는 절대 이동하지 않습니다. Sysprep, AppData, 프로필 레지스트리가 이 경로에 의존합니다.
- 사용자가 실제로 저장하는 파일(바탕화면, 문서, 다운로드 등)만 D 드라이브로 리디렉션합니다.
- 리디렉션은 `first_logon.ps1`이 최초 로그인 시 자동으로 처리합니다.
- `ProfilesDirectory`를 변경해 Users 폴더 전체를 이동하는 방식은 사용하지 않습니다.
  (VirtualBox 스냅샷 구조, Sysprep, Store 앱과 충돌 발생)

### 실행 흐름

```
[Audit Mode]
  1. D 드라이브 준비 (diskpart)
  2. VirtualBox D 드라이브 Writethrough 설정
  3. win11_master_template_optimize.ps1 실행
  4. sysprep 파일 배치 (unattend.xml / first_logon.ps1 / SetupComplete.cmd)
  5. Sysprep /generalize → CopyProfile 적용 → /shutdown

[OOBE]
  6. SetupComplete.cmd 자동 실행 (SYSTEM, 로그인 전)

[최초 로그인]
  7. first_logon.ps1 자동 실행
       ├─ D:\UserData\{사용자명} 폴더 생성
       ├─ 쉘 폴더 리디렉션 (Desktop/Documents/Downloads 등 → D:\)
       ├─ Appx 제거
       ├─ HKCU 설정 재적용
       └─ 완료 플래그 설정

[VM 종료 후]
  8. VHD 후처리 (zero-fill → compact)
```

---

## 2. 배포 ZIP 파일 구조

```text
VM-Optimize.zip
├─ win11_master_template_optimize.ps1   ← Audit Mode 최적화 스크립트
├─ build-vm-optimize-iso.ps1            ← VM_optimize ISO 생성 도구
├─ sysprep/
│  ├─ unattend.xml                      ← Sysprep 응답 파일
│  ├─ first_logon.ps1                   ← 최초 로그인 자동화 스크립트
│  ├─ setupcomplete.cmd                 ← Setup 완료 후 사전 준비 훅
│  └─ build-unattend-iso.ps1            ← vmsetup ISO 생성 도구
├─ docs/
│  └─ guide.md                          ← 이 문서
└─ Version.txt
```

---

## 3. 사전 준비

### 필요 항목

- Windows 11 ISO
- VirtualBox (또는 조직 표준 하이퍼바이저)
- 배포 ZIP 파일 (`VM-Optimize.zip`)
- D 드라이브용 VDI 파일 (또는 별도 파티션)

### VM 권장 설정

| 항목 | 권장값 |
|------|--------|
| 펌웨어 | UEFI + Secure Boot |
| TPM | 2.0 |
| 메모리 | 4GB 이상 |
| C 드라이브 | 64GB 이상, 동적 확장 VDI |
| D 드라이브 | 별도 VDI, **Writethrough** 모드 |

---

## 4. OS 설치 및 Audit Mode 진입

1. VirtualBox에서 Windows 11 VM을 새로 생성합니다.
2. Windows 11 ISO를 연결하고 부팅합니다.
3. 일반 설치 절차를 진행합니다.
4. OOBE 화면이 표시되면 **일반 사용자 계정을 만들지 않습니다.**
5. OOBE 화면에서 `Ctrl + Shift + F3`을 눌러 Audit Mode로 진입합니다.
6. 재부팅 후 Administrator 계정으로 자동 로그인됩니다.
7. Sysprep 창이 열리면 닫거나 최소화합니다.

---

## 5. D 드라이브 준비

### 5.1 VirtualBox Writethrough 설정

스냅샷을 롤백해도 D 드라이브 데이터가 보존되도록 Writethrough 모드로 연결합니다.
**VM이 종료된 상태에서** 호스트 PowerShell 또는 터미널에서 실행합니다.

```powershell
VBoxManage storageattach "VM이름" `
    --storagectl "SATA" --port 1 --device 0 `
    --type hdd --medium "D드라이브.vdi" `
    --mtype writethrough
```

설정 확인:

```powershell
VBoxManage showvminfo "VM이름" | findstr /i "writethrough"
```

### 5.2 Audit Mode에서 D 드라이브 확인

VM을 시작하고 Audit Mode 관리자 PowerShell에서 D 드라이브가 인식되는지 확인합니다.

```powershell
Get-PSDrive D
```

D 드라이브가 없으면 `diskmgmt.msc` 또는 `diskpart`로 파티션을 초기화합니다.

```cmd
diskpart
> list disk
> select disk 1
> create partition primary
> format fs=ntfs label=UserData quick
> assign letter=D
> exit
```

`first_logon.ps1`이 최초 로그인 시 `D:\UserData\{사용자명}` 하위 폴더를 자동 생성하므로
Audit Mode 단계에서는 D 드라이브 자체만 준비하면 됩니다.

---

## 6. 최적화 스크립트 실행

배포 ZIP의 파일들을 VM에 복사한 뒤 관리자 PowerShell에서 실행합니다.

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\win11_master_template_optimize.ps1 --standard
```

### 모드 선택 기준

| 모드 | 설명 | 권장 상황 |
|------|------|----------|
| `--lite` | 보수적/저위험 정리 | 공공기관, 망분리 환경 초기 검증 |
| `--standard` | 기본 균형형 최적화 | 일반적인 VM 마스터 템플릿 (기본값) |
| `--advanced` | 강한 정리/비활성화 | 복제 VM 검증 완료 후 제한적 사용 |

### 주요 수행 작업

- Temp / Cache / Update 다운로드 캐시 정리
- Defender 검사 기록 정리
- 이벤트 로그 초기화
- Hibernation 비활성화
- Appx 및 Provisioned Appx 제거
- 서비스 / 예약 작업 비활성화
- Search / Bing / Copilot / Recall / Consumer / Privacy 정책 설정
- 전원 계획, 탐색기, 시작 메뉴, 작업 표시줄, 잠금 화면 조정
- cleanmgr / DISM component cleanup 실행

---

## 7. Sysprep 파일 배치

`unattend.xml`, `first_logon.ps1`, `SetupComplete.cmd` 세 파일을 모두 배치해야 합니다.

### 방법 A: 직접 복사 (권장)

```powershell
# sysprep 폴더가 배포 ZIP 기준 경로에 있는 경우
Copy-Item ".\sysprep\unattend.xml"      "C:\Windows\System32\Sysprep\unattend.xml" -Force
Copy-Item ".\sysprep\first_logon.ps1"   "C:\Windows\Setup\Scripts\first_logon.ps1" -Force
Copy-Item ".\sysprep\setupcomplete.cmd" "C:\Windows\Setup\Scripts\SetupComplete.cmd" -Force
```

`C:\Windows\Setup\Scripts` 폴더가 없으면 먼저 생성합니다.

```powershell
New-Item -ItemType Directory -Path "C:\Windows\Setup\Scripts" -Force
```

### 방법 B: ISO 생성 후 마운트

```powershell
# 호스트 또는 Audit Mode PowerShell에서 실행
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\sysprep\build-unattend-iso.ps1
# → 같은 폴더에 vmsetup.iso 생성
```

ISO를 VM에 마운트한 뒤:

```powershell
$iso = (Get-Volume | Where-Object { $_.FileSystemLabel -eq 'VMSETUP' }).DriveLetter + ':'
Copy-Item "$iso\unattend.xml"  "C:\Windows\System32\Sysprep\unattend.xml" -Force
Copy-Item "$iso\Scripts\*"     "C:\Windows\Setup\Scripts\"               -Force
```

### 배치 위치 요약

| 파일 | 배치 위치 | 실행 시점 |
|------|----------|----------|
| `unattend.xml` | `C:\Windows\System32\Sysprep\` | Sysprep 실행 시 |
| `SetupComplete.cmd` | `C:\Windows\Setup\Scripts\` | OOBE 완료 직후 (로그인 전, SYSTEM) |
| `first_logon.ps1` | `C:\Windows\Setup\Scripts\` | 최초 사용자 로그인 시 자동 실행 |

---

## 8. Sysprep 실행

파일 배치와 최적화 스크립트 실행을 완료한 뒤 아래 명령을 실행합니다.

```cmd
C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\System32\Sysprep\unattend.xml
```

| 옵션 | 역할 |
|------|------|
| `/generalize` | SID, 장치 고유 정보 일반화. `CopyProfile=true`가 이 단계에서 실행됨 |
| `/oobe` | 다음 부팅 시 OOBE 진입 |
| `/shutdown` | Sysprep 완료 후 VM 자동 종료 |
| `/unattend` | 응답 파일 지정 |

Sysprep 완료 후 VM이 자동으로 종료됩니다.

### Sysprep 실패 시 확인 로그

```text
C:\Windows\System32\Sysprep\Panther\setuperr.log
C:\Windows\System32\Sysprep\Panther\setupact.log
C:\Windows\Panther\setuperr.log
```

---

## 9. 최초 로그인 자동화 (first_logon.ps1)

Sysprep 후 VM을 배포해 처음 로그인하면 `unattend.xml`의 `FirstLogonCommands`에 의해
`first_logon.ps1`이 자동 실행됩니다. 별도 조작 없이 다음 작업이 자동 처리됩니다.

| 단계 | 내용 |
|------|------|
| 1 | `D:\UserData\{사용자명}` 폴더 구조 생성 |
| 2 | Desktop / Documents / Downloads / Pictures / Videos / Music → `D:\UserData` 리디렉션 |
| 3 | Appx 제거 (Xbox, PhoneLink, Copilot, Teams, Clipchamp) |
| 4 | Provisioned Appx 제거 (신규 사용자 자동 설치 차단) |
| 5 | HKCU 설정 재적용 (Search, Copilot, Consumer Experience, Telemetry, Explorer) |
| 6 | Explorer 재시작 |
| 7 | 재실행 방지 플래그 설정 |

D 드라이브가 없는 환경에서는 리디렉션 단계를 건너뛰고 나머지 작업을 계속합니다.

실행 로그: `C:\Windows\Logs\first_logon.log`

재실행 방지 플래그: `HKCU:\Software\VMTemplateSetup\FirstLogonComplete`

---

## 10. 종료 후 처리

### 10.1 주의 사항

- Sysprep 종료 후 원본 VM을 다시 부팅하지 않습니다.
- 부팅하면 OOBE가 진행되어 템플릿 상태가 변경됩니다.
- 먼저 디스크 파일을 복제하거나 스냅샷 정책을 적용합니다.

### 10.2 VHD 크기 최적화 (선택)

#### 1단계: SDelete로 여유 공간 Zero-Fill

Sysprep 직전 또는 VM 종료 전 관리자 PowerShell에서 실행합니다.

```cmd
sdelete64.exe -z C:
```

SDelete 다운로드: https://learn.microsoft.com/en-us/sysinternals/downloads/sdelete

#### 2단계: VHD Compact

VM이 완전히 종료된 상태에서 호스트 PowerShell에서 실행합니다.

```powershell
# VirtualBox 예시
VBoxManage modifymedium disk "C드라이브.vdi" --compact
```

---

## 11. 정리 대상 및 주의사항

| 경로 / 항목 | 삭제 가능 여부 | 주의사항 |
|------------|--------------|---------|
| `C:\Windows\Temp` | 가능 | 설치/업데이트 중 일부 파일 잠김 |
| `%TEMP%` | 가능 | Audit Mode Administrator 기준 |
| `C:\Windows\SoftwareDistribution\Download` | 가능 | 업데이트 중 삭제 금지 |
| `C:\Windows\Panther` | 조건부 | Sysprep 실패 분석 전 삭제 금지 |
| Defender 검사 기록 | 가능 | 보안 감사 보존 정책 확인 |
| 이벤트 로그 | 조건부 | 감사/장애 분석 필요 시 보존 |
| `hiberfil.sys` | 가능 | VM에서는 제거 권장 |
| `pagefile.sys` | 비권장 | 메모리 압박/덤프 대응에 필요 |

---

## 12. 공공기관 / 망분리 체크포인트

### 12.1 Administrator 계정 정리

- 바탕화면, 다운로드, 문서에 작업 파일이 남아 있지 않은지 확인
- `%TEMP%` 및 `C:\Users\Administrator\AppData\Local\Temp` 정리
- 브라우저 다운로드 기록, 캐시, 자동 완성 데이터 정리

### 12.2 제거/비활성화 검토 항목

- Phone Link / Xbox 관련 앱
- Copilot 관련 앱 및 정책
- Teams 개인용 구성요소
- 소비자 경험 기반 추천 앱
- Bing / 웹 검색 / 클라우드 Search
- Recall / AI 스냅샷 기능

### 12.3 감사 대응 기록 항목

- 적용 모드 및 스크립트 버전
- 실행 일시 및 실행자
- 제거한 Appx 목록
- 비활성화한 서비스 / 예약 작업 목록
- 적용한 정책 키 목록
- 업무 앱 검증 결과
- Sysprep 결과 및 로그
- 후처리 및 보관 검증 결과

---

## 13. 핵심 검증 체크리스트

Sysprep 전 다음 항목을 확인합니다.

- [ ] D 드라이브가 Writethrough 모드로 연결되어 있음
- [ ] `C:\Windows\System32\Sysprep\unattend.xml` 배치 완료
- [ ] `C:\Windows\Setup\Scripts\first_logon.ps1` 배치 완료
- [ ] `C:\Windows\Setup\Scripts\SetupComplete.cmd` 배치 완료
- [ ] 최적화 스크립트 실행 로그 오류 없음
- [ ] Administrator 잔여 파일 정리 완료
- [ ] Sysprep 로그 오류 없음 (`Panther\setuperr.log`)

Sysprep 후 최초 로그인 시 확인합니다.

- [ ] `C:\Windows\Logs\first_logon.log` 정상 완료 메시지 확인
- [ ] `D:\UserData\{사용자명}` 폴더 생성 확인
- [ ] 바탕화면 / 문서 / 다운로드가 D 드라이브를 가리키는지 확인
- [ ] 불필요 Appx 제거 확인

---

공식 변경 이력은 `CHANGELOG.md`에 기록합니다.
