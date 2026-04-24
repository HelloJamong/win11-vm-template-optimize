# Windows 11 VM 마스터 템플릿 통합 가이드

이 문서는 Windows 11 VM 마스터 템플릿 생성 절차를 처음부터 끝까지 설명합니다.
Audit Mode 작업, Sysprep, 최초 로그인 자동화, 최적화 스크립트 실행, VHD 후처리까지
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
[VM 부팅 및 설치]
  1. Windows 11 ISO로 VM 부팅 및 OS 설치
  2. OOBE 화면에서 Ctrl+Shift+F3 → Audit Mode 진입

[Audit Mode]
  3. D 드라이브 준비 (diskpart)
  4. VirtualBox D 드라이브 Writethrough 설정
  5. Sysprep 파일 배치 (unattend.xml / first_logon.ps1 / SetupComplete.cmd)
  6. Sysprep /generalize → CopyProfile 적용 → /shutdown

[OOBE 및 초기 설정]
  7. SetupComplete.cmd 자동 실행 (SYSTEM, 로그인 전)
  8. 사용자 계정 생성 및 최초 로그인
  9. first_logon.ps1 자동 실행
       ├─ D:\UserData\{사용자명} 폴더 생성
       ├─ 쉘 폴더 리디렉션 (Desktop/Documents/Downloads 등 → D:\)
       ├─ Appx 제거
       ├─ HKCU 설정 재적용
       └─ 완료 플래그 설정
  10. 필요한 프로그램 설치 및 설정

[최적화 및 정리]
  11. win11_master_template_optimize.ps1 실행
  12. sdelete64 -z C: 실행

[VM 종료 후]
  13. diskpart 또는 VBoxManage로 VDI compact
```

---

## 2. 배포 ZIP 파일 구조

```text
VM-Optimize.zip
├─ win11_master_template_optimize.ps1   ← Audit Mode 최적화 스크립트
├─ build-vm-optimize-iso.ps1            ← VM_optimize ISO 생성 도구
├─ configs/
│  ├─ appx-remove-list.txt              ← 추가 Appx 제거 후보 목록
│  ├─ services-disable-list.txt         ← 추가 서비스 비활성화 후보 목록
│  └─ tasks-disable-list.txt            ← 추가 예약 작업 비활성화 후보 목록
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

## 6. Sysprep 파일 배치

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

## 7. Sysprep 실행

파일 배치를 완료한 뒤 아래 명령을 실행합니다.

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

## 8. 최초 로그인 자동화 (first_logon.ps1)

Sysprep 후 VM을 부팅해 OOBE를 진행하고 사용자 계정을 생성합니다.
최초 로그인 시 `unattend.xml`의 `FirstLogonCommands`에 의해 `first_logon.ps1`이 자동 실행됩니다.

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

## 9. 프로그램 설치 및 설정

최초 로그인 후 조직 표준에 따라 필요한 프로그램을 설치하고 설정을 구성합니다.

- 업무용 프로그램 설치 (오피스, 보안 솔루션, 에이전트 등)
- 조직 정책 적용 (GPO, 인증서, VPN 클라이언트 등)
- Administrator 잔여 파일 정리 (바탕화면, 다운로드, 브라우저 캐시 등)

---

## 10. 최적화 스크립트 실행

프로그램 설치 및 설정이 완료된 후 관리자 PowerShell에서 실행합니다.

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\win11_master_template_optimize.ps1
```

### 주요 수행 작업

- Temp / Cache / Update 다운로드 캐시 정리
- Defender 검사 기록 정리
- 이벤트 로그 초기화
- Hibernation 비활성화
- Appx 및 Provisioned Appx 제거
- 서비스 / 예약 작업 비활성화
- Search / Bing / Copilot / Recall / Consumer / Privacy 정책 설정
- 로그인 옵션 / 앱 재시작 / 개인설정 시작 메뉴 / 개인정보 일반 조정
- 전원 계획, 탐색기, 시작 메뉴, 작업 표시줄, 잠금 화면 조정
- Edge 정책, 제어판 뷰, 부팅 타임아웃, 시스템 볼륨, 컴퓨터 이름 설정
- cleanmgr / DISM component cleanup 실행

각 단계마다 수행 항목을 표시하고 Y/n으로 진행 여부를 확인합니다.
개별 항목을 제어하려면 스크립트 상단의 `$Enable*` 플래그를 직접 수정합니다.

---

## 11. sdelete 및 VM 종료

최적화 완료 후 여유 공간을 Zero-Fill하여 VDI compact 효율을 높입니다.

```cmd
sdelete64.exe -z C:
```

SDelete 다운로드: https://learn.microsoft.com/en-us/sysinternals/downloads/sdelete

완료 후 VM을 정상 종료합니다.

---

## 12. VDI Compact

VM이 완전히 종료된 상태에서 진행합니다.

### VirtualBox (VDI)

호스트 PowerShell 또는 터미널에서 실행합니다.

```powershell
VBoxManage modifymedium disk "C드라이브.vdi" --compact
```

### VHD / VHDX (diskpart)

```cmd
diskpart
> select vdisk file="C:\path\to\disk.vhd"
> compact vdisk
> exit
```

---

## 13. 정리 대상 및 주의사항

| 경로 / 항목 | 삭제 가능 여부 | 주의사항 |
|------------|--------------|---------|
| `C:\Windows\Temp` | 가능 | 설치/업데이트 중 일부 파일 잠김 |
| `%TEMP%` | 가능 | 실행 계정 기준 |
| `C:\Windows\SoftwareDistribution\Download` | 가능 | 업데이트 중 삭제 금지 |
| `C:\Windows\Panther` | 조건부 | Sysprep 실패 분석 전 삭제 금지 |
| Defender 검사 기록 | 가능 | 보안 감사 보존 정책 확인 |
| 이벤트 로그 | 조건부 | 감사/장애 분석 필요 시 보존 |
| `hiberfil.sys` | 가능 | VM에서는 제거 권장 |
| `pagefile.sys` | 비권장 | 메모리 압박/덤프 대응에 필요 |

---

## 14. 공공기관 / 망분리 체크포인트

### 14.1 Administrator 계정 정리

- 바탕화면, 다운로드, 문서에 작업 파일이 남아 있지 않은지 확인
- `%TEMP%` 및 `C:\Users\Administrator\AppData\Local\Temp` 정리
- 브라우저 다운로드 기록, 캐시, 자동 완성 데이터 정리

### 14.2 제거/비활성화 검토 항목

- Phone Link / Xbox 관련 앱
- Copilot 관련 앱 및 정책
- Teams 개인용 구성요소
- 소비자 경험 기반 추천 앱
- Bing / 웹 검색 / 클라우드 Search
- Recall / AI 스냅샷 기능

### 14.3 감사 대응 기록 항목

- 스크립트 버전 및 실행 일시
- 실행자
- 제거한 Appx 목록
- 비활성화한 서비스 / 예약 작업 목록
- 적용한 정책 키 목록
- 업무 앱 검증 결과
- Sysprep 결과 및 로그
- 후처리 및 보관 검증 결과

---

## 15. 핵심 검증 체크리스트

Sysprep 전 다음 항목을 확인합니다.

- [ ] D 드라이브가 Writethrough 모드로 연결되어 있음
- [ ] `C:\Windows\System32\Sysprep\unattend.xml` 배치 완료
- [ ] `C:\Windows\Setup\Scripts\first_logon.ps1` 배치 완료
- [ ] `C:\Windows\Setup\Scripts\SetupComplete.cmd` 배치 완료
- [ ] Administrator 잔여 파일 정리 완료

Sysprep 후 최초 로그인 시 확인합니다.

- [ ] `C:\Windows\Logs\first_logon.log` 정상 완료 메시지 확인
- [ ] `D:\UserData\{사용자명}` 폴더 생성 확인
- [ ] 바탕화면 / 문서 / 다운로드가 D 드라이브를 가리키는지 확인
- [ ] 불필요 Appx 제거 확인

최적화 스크립트 실행 후 확인합니다.

- [ ] `C:\win11_template_optimize.log` 오류 없음 확인
- [ ] sdelete 완료 확인
- [ ] VDI compact 완료 확인

---

공식 변경 이력은 `CHANGELOG.md`에 기록합니다.
