# CHANGELOG

이 프로젝트의 변경 이력은 `연도.메이저버전.마이너버전` 형식으로 관리합니다.

- `연도`: 릴리스 연도의 두 자리 표기입니다. 예: 2026년 → `26`
- `메이저버전`: 프로젝트 기준선 또는 운영 방식이 크게 바뀌는 변경입니다.
- `마이너버전`: 동일 메이저 기준선 안에서 누적되는 기능/문서/검증 개선 변경입니다.

## [26.1.14] - 2026-04-22

### Fixed

- `scripts/win11_master_template_optimize.ps1` configs 경로 탐색 오류 수정
  - 배포 환경(스크립트가 루트에 위치)에서 `configs/` 폴더를 찾지 못하는 문제 수정.
  - 원인: `$Script:RootDir = Split-Path -Parent $PSScriptRoot` 는 개발 환경(`scripts/` 하위 실행) 기준 설계.
    릴리즈 ZIP에서 스크립트를 루트에서 실행 시 `configs/`를 한 단계 위 경로에서 탐색해 경로가 틀어짐.
  - 수정: 스크립트와 동일 레벨에 `configs/`가 있으면 그 경로를 우선 사용하고,
    없으면 부모 디렉터리에서 탐색하는 폴백 로직 추가. 개발/배포 환경 모두 대응.
- `.github/workflows/release.yml` 릴리즈 ZIP에 `configs/` 폴더 누락 수정
  - `appx-remove-list.txt`, `services-disable-list.txt`, `tasks-disable-list.txt` 를
    `_release/configs/` 에 포함하도록 추가.

### Verification

- 배포 환경(루트 실행) 경로 폴백 로직 확인
- 개발 환경(`scripts/` 하위 실행) 기존 동작 유지 확인
- 릴리즈 ZIP `configs/` 디렉터리 구조 확인

## [26.1.13] - 2026-04-22

### Fixed

- `scripts/sysprep/first_logon.ps1` Desktop 탐색기 네비게이션 패널 누락 수정
  - 쉘 폴더 리디렉션 후 파일 탐색기 좌측 패널에서 Desktop이 사라지는 문제 수정.
  - 원인: `User Shell Folders` 레지스트리 변경은 파일 라우팅에는 충분하지만,
    탐색기 네비게이션 패널은 Known Folder 캐시(`SHGetKnownFolderPath`)를 참조합니다.
    Desktop은 Shell 네임스페이스 루트와 연결되어 있어 Documents/Downloads 등과 달리
    `SHSetKnownFolderPath` API 호출 없이는 패널에서 사라지는 Windows 동작이 있습니다.
  - 수정: 리디렉션 루프 직후 `SHSetKnownFolderPath` P/Invoke로 Desktop Known Folder
    경로(`{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}`)를 `D:\UserData\{사용자명}\Desktop`으로 동기화.
  - D 드라이브가 없는 환경에서는 호출하지 않습니다 (`$DriveReady` 조건 유지).

### Verification

- `first_logon.ps1` `SHSetKnownFolderPath` P/Invoke 코드 삽입 위치 확인
- D 드라이브 없는 환경 분기(`$DriveReady`) 유지 확인

## [26.1.12] - 2026-04-22

### Fixed

- `scripts/sysprep/unattend.xml` OOBE 계정 생성 화면 누락 수정
  - `<SkipMachineOOBE>true</SkipMachineOOBE>` 및 `<SkipUserOOBE>true</SkipUserOOBE>` 제거.
  - 두 설정이 사용자 계정 생성 단계를 건너뛰면서 `<UserAccounts>` 미정의 상태와 결합되어
    Sysprep 재부팅 후 로그인 화면만 표시되고 계정 생성 자체가 불가능한 문제 수정.
  - `<HideOnlineAccountScreens>true</HideOnlineAccountScreens>` 는 유지되어
    Microsoft 계정 요구 없이 로컬 계정 생성 화면이 정상 표시됩니다.

### Verification

- Sysprep 재부팅 후 로컬 계정 생성 화면 진입 확인

## [26.1.11] - 2026-04-22

### Fixed

- `scripts/sysprep/build-unattend-iso.ps1` 인코딩 수정
  - UTF-8 without BOM → UTF-8 with BOM 으로 변경.
  - Windows PowerShell 5.x 에서 한글 출력 깨짐 및 `TerminatorExpectedAtEndOfString` 파싱 오류 수정.
- `scripts/build-vm-optimize-iso.ps1` 인코딩 수정
  - UTF-8 without BOM → UTF-8 with BOM 으로 변경.
  - Windows PowerShell 5.x 에서 한글 출력 깨짐 및 `TerminatorExpectedAtEndOfString` 파싱 오류 수정.

### Verification

- `build-unattend-iso.ps1` UTF-8 BOM(`EF BB BF`) 적용 확인
- `build-vm-optimize-iso.ps1` UTF-8 BOM(`EF BB BF`) 적용 확인

## [26.1.10] - 2026-04-21

### Added

- `scripts/sysprep/first_logon.ps1` 추가
  - OOBE 후 최초 로그인 시 `unattend.xml`의 `FirstLogonCommands`에 의해 자동 실행됩니다.
  - `D:\UserData\{사용자명}` 폴더 구조(Desktop/Documents/Downloads/Pictures/Videos/Music) 자동 생성.
  - 쉘 폴더(Desktop/Documents/Downloads/Pictures/Videos/Music)를 `D:\UserData`로 리디렉션합니다.
    Downloads는 Known Folder GUID(`{374DE290-123F-4565-9164-39C4925E467B}`) 키를 사용합니다.
  - Appx 및 Provisioned Appx 제거 (Xbox, PhoneLink, Copilot, Teams, Clipchamp).
  - HKCU 설정 재적용: Search/Bing/Cortana 비활성화, Copilot 비활성화, Consumer Experience 비활성화, Telemetry 최소화, Explorer 최근 항목 비활성화.
  - Explorer 재시작으로 리디렉션 즉시 반영.
  - `HKCU:\Software\VMTemplateSetup\FirstLogonComplete` 플래그로 재실행 방지.
  - 실행 로그: `C:\Windows\Logs\first_logon.log`.
  - D 드라이브 없는 환경에서는 리디렉션을 건너뛰고 나머지 작업 계속 진행.
- `scripts/sysprep/setupcomplete.cmd` 추가
  - Windows Setup 완료 후 SYSTEM 권한으로 자동 실행되는 사전 준비 훅.
  - `C:\Windows\Logs`, `C:\Windows\Setup\Scripts` 디렉터리 확보.
  - PowerShell LocalMachine 실행 정책을 RemoteSigned로 완화.

### Changed

- `scripts/sysprep/unattend.xml` 전면 재작성
  - 기존: `ProfilesDirectory`로 `C:\Users` 전체를 D 드라이브로 이동하는 방식.
  - 변경: `C:\Users` 위치 유지 + `CopyProfile=true` + `FirstLogonCommands` 조합으로 전환.
  - `generalize` 패스에 `CopyProfile=true` 추가: Audit Mode 사용자 설정을 Default Profile로 복사.
  - `oobeSystem` 패스에 `FirstLogonCommands` 추가: `first_logon.ps1` 자동 실행 연결.
  - OOBE 간소화 설정 추가: `HideEULAPage`, `HideOEMRegistrationScreen`, `SkipMachineOOBE` 등.
  - `ProfilesDirectory` 방식 제거: VirtualBox 스냅샷 구조/Sysprep/Store 앱 충돌 방지.
- `scripts/sysprep/build-unattend-iso.ps1` 개선
  - `-ProfileDrive` 필수 파라미터 제거 (ProfilesDirectory 방식 폐기에 따른 변경).
  - ISO에 `unattend.xml` 외 `Scripts/first_logon.ps1`, `Scripts/SetupComplete.cmd` 번들링 추가.
  - 출력 ISO 이름 변경: `unattend.iso` → `vmsetup.iso`, 볼륨 이름: `UNATTEND` → `VMSETUP`.
  - ISO 내 `README.txt`에 배치 명령 및 아키텍처 설명 업데이트.
- `.github/workflows/release.yml` 릴리스 ZIP 구조 개선
  - `sysprep/` 서브디렉터리 추가: `unattend.xml`, `first_logon.ps1`, `setupcomplete.cmd`, `build-unattend-iso.ps1` 포함.
  - `docs/` 서브디렉터리 추가: `guide.md` 포함.
- `docs/guide.md` 전면 재작성
  - 새 아키텍처(C:\Users 유지 + D:\UserData 쉘 폴더 리디렉션) 기준으로 전체 재작성.
  - VirtualBox D 드라이브 Writethrough 설정 명령 추가.
  - `first_logon.ps1`, `setupcomplete.cmd` 배치 방법(직접 복사/ISO) 상세 안내.
  - 배포 ZIP 파일 구조, Sysprep 전후 검증 체크리스트 추가.
- `README.md` 업데이트
  - 섹션 5 디렉터리 구조에 신규 파일(`first_logon.ps1`, `setupcomplete.cmd`) 반영.
  - 섹션 6.4를 D 드라이브(UserData) 구성 방식으로 전면 교체.
  - 섹션 6.5를 Sysprep 파일 배치 안내(ISO/직접 복사)로 전면 교체.
- `scripts/win11_master_template_optimize.ps1` 인코딩 수정
  - UTF-8 without BOM → UTF-8 with BOM 으로 변경 (Windows PowerShell 5.x 한글 파싱 오류 수정).

### Removed

- `scripts/sysprep/unattend.xml`에서 `<FolderLocations><ProfilesDirectory>` 설정 제거.
  - Users 폴더 전체 이동 방식은 스냅샷 구조와 충돌하므로 폐기.
- `scripts/sysprep/build-unattend-iso.ps1`에서 `-ProfileDrive` 파라미터 제거.

### Fixed

- `.github/workflows/release.yml` 릴리즈 노트 bash 백틱 해석 오류 수정
  - CHANGELOG 마크다운 백틱(`` ` ``)이 bash 명령으로 실행되던 문제 수정.
  - awk 출력을 셸 변수 대신 temp 파일에 직접 저장하고 `cat`으로 읽도록 변경.
  - `Version.txt` 생성 시 `echo "${{ }}"` 대신 `cat notes_file` 방식으로 교체.
  - GitHub Release `body:` → `body-path:` 로 교체.

### Verification

- `first_logon.ps1` D 드라이브 없는 환경 조건 분기 확인
- `unattend.xml` XML 구조 검증 통과
- `build-unattend-iso.ps1` 소스 파일 존재 여부 검증 로직 확인
- 릴리스 ZIP `sysprep/`, `docs/` 서브디렉터리 구조 확인
- `win11_master_template_optimize.ps1` UTF-8 BOM 적용 확인
- 릴리즈 워크플로 백틱 오류 수정 확인

## [26.1.9] - 2026-04-20

### Added

- `scripts/build-vm-optimize-iso.ps1` 추가
  - `scripts/_iso/` 폴더의 파일 전체를 `VM_optimize.iso`로 생성합니다.
  - 실행 시 `_iso` 폴더 안내 메시지 출력 후 Y/n 확인 절차를 거칩니다.
  - Y 입력 후 `_iso` 폴더가 없거나 비어 있으면 오류 메시지를 출력하고 종료합니다.
  - IMAPI2 COM API 사용, UTF-8 콘솔 인코딩 설정 포함.
- `scripts/_iso/` 스테이징 디렉터리 추가
  - `win11_master_template_optimize.ps1`, `sdelete64.exe` 등 VM에 전달할 파일을 배치하는 폴더입니다.
  - `.gitignore`에 `_iso/*` 추가 (내용물 추적 제외, `.gitkeep`으로 구조만 유지).
- `.github/workflows/release.yml` 추가
  - 태그 푸시(`YY.MAJOR.MINOR`) 또는 `workflow_dispatch`로 트리거됩니다.
  - `CHANGELOG.md`에서 해당 버전 릴리즈 노트를 자동 추출합니다.
  - `VM-Optimize.zip` 생성 — 스크립트 4개 + `_iso/` 폴더 + `Version.txt` 포함.
  - `Version.txt`에 버전 번호와 해당 버전 릴리즈 노트를 기록합니다.
- `README.md` 6.6 섹션에 실행 정책(Execution Policy) 상세 안내 추가
  - Process/CurrentUser 범위별 설정 방법, `Unblock-File` 안내 추가.

### Changed

- `scripts/sysprep/build-unattend-iso.ps1` 인코딩 수정
  - 콘솔 출력 UTF-8 고정 (한글 깨짐 방지).
  - ISO 내 `README.txt` 인코딩을 `UTF8` → `Unicode`(UTF-16 LE BOM)로 변경해 Windows에서 한글이 정상 표시되도록 수정.

### Verification

- 워크플로 `_release/_iso/` 경로 포함 및 ZIP 구조 확인
- `build-vm-optimize-iso.ps1` Y/n 분기 및 오류 메시지 경로 확인

## [26.1.8] - 2026-04-20

### Added

- `$EnableDefragFreeSpace` 옵션을 추가했습니다.
  - `defrag /X`로 여유 공간을 통합합니다. VHD compact 전 압축률 향상에 유효합니다.
  - 소요 시간이 길고 SSD/NVMe 기반 VM에서는 불필요하므로 기본값은 `$false`입니다.
  - lite / standard / advanced 세 모드 모두 `$false`로 등록했습니다.

### Changed

- README.md 6.9 VHD 후처리 섹션을 3단계 후처리 절차로 재작성했습니다.
  - SDelete(Microsoft Sysinternals) 공식 다운로드 주소 추가
  - `sdelete64.exe -z C:` 사용법, 주의사항(즉시 종료, 망분리 반입), 소요 시간 안내 추가
  - VHD compact → 보관 순서로 단계 정리
- 전체 문서 및 스크립트에서 `VHDX` 표기를 제거하고 `VHD`로 통일했습니다.
  - `README.md` 내 `VHD/VHDX` 2곳 → `VHD`
  - `scripts/win11_master_template_optimize.ps1` 주석 1곳 → `VHD`
  - `.gitignore`에서 `*.vhdx` 항목 제거

### Removed

- `$EnableZeroFreeSpace` 옵션(`cipher /w` 기반 zero-fill)을 제거했습니다.
  - zero-fill은 스크립트 자동화 대신 SDelete를 사용한 수동 후처리로 안내합니다.
  - README.md 6.9 후처리 가이드에 SDelete 사용법과 다운로드 주소로 대체했습니다.

### Verification

- 스크립트 내 `EnableZeroFreeSpace` 참조 전체 제거 확인
- `VHDX` 표기 전체 제거 확인 (`.gitignore`, `README.md`, `scripts/`)
- README.md 6.9 섹션 sdelete 가이드 및 다운로드 URL 반영 확인

## [26.1.7] - 2026-04-18

### Added

- PowerShell 콘솔 한글 깨짐 방지를 위해 스크립트 최상단에 UTF-8 인코딩 설정을 추가했습니다.
  - `[Console]::OutputEncoding`, `[Console]::InputEncoding`, `$OutputEncoding`을 UTF-8로 고정합니다.
  - Windows PowerShell 5.x 환경에서는 파일 자체도 UTF-8 with BOM으로 저장해야 합니다.
- VDOT(Virtual Desktop Optimization Tool) 기준 Microsoft Edge 최적화 섹션(`$EnableEdgeTweaks`)을 추가했습니다.
  - 백그라운드 실행 차단: `BackgroundModeEnabled=0`
  - 시작 부스트 및 사전 로드 차단: `StartupBoostEnabled=0`, `AllowPrelaunch=0`, `AllowTabPreloading=0`
  - 첫 실행 스플래시 숨김: `HideFirstRunExperience=1`, `PreventFirstRunPage=1`
  - 제품 내 추천/위젯 비활성화: `ShowRecommendationsEnabled=0`, `WebWidgetAllowed=0`
  - 효율성 모드(비활성 탭 슬립) 비활성화: `EfficiencyMode=0`
  - 자동완성 전체 비활성화: `AutofillAddressEnabled=0`, `AutofillCreditCardEnabled=0`, `PasswordManagerEnabled=0`
  - 새 탭 사전 렌더링 비활성화: `NewTabPagePrerenderEnabled=0`
  - 네트워크 예측/DNS 프리페치 비활성화: `NetworkPredictionOptions=2`
  - 하드웨어 가속 명시적 활성화 유지: `HardwareAccelerationModeEnabled=1`
  - 레거시 EdgeHTML 정책, EdgeUI 스와이프/MFU 추적, EdgeUpdate 업무 시간대 업데이트 억제 포함
  - 세 모드(lite/standard/advanced) 모두 기본 활성화

### Changed

- `--interactive` 옵션을 폐지하고 인터랙티브 모드를 기본 동작으로 변경했습니다.
  - `$Script:Interactive` 기본값: `$false → $true`
  - 별도 옵션 없이 항상 각 단계마다 Y/n 확인 후 진행합니다.
- `standard` 모드의 `EnableOneDriveRemoval` 기본값을 `$false → $true`로 변경했습니다.

### Verification

- 스크립트 인수 파싱 로직에서 `--interactive` 관련 케이스 제거 확인
- `Apply-ModePreset` 세 모드에 `EnableEdgeTweaks` 등록 확인
- Edge 정책 키 경로(`HKLM:\SOFTWARE\Policies\Microsoft\Edge`) 확인

## [26.1.6] - 2026-04-17

### Removed

- 별도 문서로 관리하기로 한 `tests/` 디렉터리와 하위 검증 체크리스트 파일을 제거했습니다.

### Changed

- README, 통합 가이드, PowerShell 후속 안내에서 저장소 내 `tests/` 경로 참조를 제거했습니다.
- 검증 항목은 `docs/guide.md`에 핵심 기준만 남기고 상세 체크리스트는 외부 문서 기준으로 안내하도록 정리했습니다.

### Verification

- `tests/` 디렉터리 제거 확인
- 저장소 내 `tests/` 경로 참조 제거 확인

## [26.1.5] - 2026-04-17

### Removed

- 불필요한 `scripts/compress/` 디렉터리와 하위 배치 파일을 제거했습니다.
- 프로젝트 문서와 체크리스트에서 저장소 내 압축 보조 배치 파일 사용 안내를 제거했습니다.

### Changed

- VHD 보관은 저장소 제공 스크립트가 아니라 조직 표준 후처리 절차로 수행하도록 문구를 정리했습니다.

### Verification

- `scripts/compress/` 제거 확인
- 압축 보조 배치 파일 참조 제거 확인

## [26.1.4] - 2026-04-17

### Changed

- 중복되던 `docs/` 문서를 `docs/guide.md` 통합 운영 가이드로 합쳤습니다.
- 기존 `build-process`, `cleanup-items`, `sysprep-guide`, `audit-notes`의 핵심 내용을 절차 중심으로 재배치했습니다.
- `docs/changelog-template.md`를 삭제하고, 향후 버전 갱신 참고용 템플릿을 `CHANGELOG.md` 하단으로 이동했습니다.

### Removed

- `docs/build-process.md`
- `docs/cleanup-items.md`
- `docs/sysprep-guide.md`
- `docs/audit-notes.md`
- `docs/changelog-template.md`

### Verification

- 문서 참조가 `docs/guide.md` 기준으로 갱신되었는지 확인

## [26.1.3] - 2026-04-17

### Added

- `scripts/sysprep/build-unattend-iso.ps1`을 추가해 `<ProfileDrive>` 치환이 완료된 `unattend.xml`을 VM에 연결 가능한 ISO로 생성할 수 있게 했습니다.

### Changed

- `scripts/sysprep/unattend.xml`을 OS 설치 후 프로필 경로 변경 목적에 맞춘 최소 Sysprep 응답 파일 구조로 정리했습니다.
- `ProfilesDirectory`의 드라이브 경로는 고정하지 않고 `<ProfileDrive>:\Users` 자리표시자로 유지하되, 실제 Sysprep 실행 전 조직 표준 드라이브 문자로 치환해야 한다는 XML 주석을 추가했습니다.
- Sysprep 가이드에 `unattend.xml`은 드라이브 문자를 자동 선택하지 않으며 자리표시자 치환이 필요하다는 설명을 보강했습니다.

### Verification

- `scripts/sysprep/unattend.xml` XML 검증 통과
- `build-unattend-iso.ps1` 주요 토큰 및 문서 참조 확인

## [26.1.2] - 2026-04-17

### Added

- Windows 11 VM 마스터 템플릿 최적화 프로젝트의 초기 운영 자산 구조를 생성했습니다.
- 단일 PowerShell 최적화 스크립트 `scripts/win11_master_template_optimize.ps1`를 추가했습니다.
- `--standard`, `--advanced`, `--lite` 모드 기반 실행 구조를 추가했습니다.
- Sysprep용 `unattend.xml` 템플릿을 추가했습니다.
- 별도 사용자 프로필 드라이브를 사용하는 `ProfilesDirectory` 구성 안내를 추가했습니다.
- Appx 제거 후보, 서비스 비활성화 후보, 예약 작업 비활성화 후보, 레지스트리 정책 참조 파일을 추가했습니다.
- VM 템플릿 생성 절차, Sysprep 가이드, 정리 항목, 공공기관/망분리 감사 체크포인트 문서를 추가했습니다.
- Sysprep 전 검증 체크리스트와 빌드 후 검증 체크리스트를 추가했습니다.
- `.pck` 압축/해제용 7-Zip 보조 배치 파일을 추가했습니다.
- VM 일괄 설정용 고가치 PowerShell 토글을 추가했습니다.
  - 전원 계획/절전 타임아웃 조정
  - 탐색기 개인정보/히스토리 정리
  - 시작 메뉴 추천/최근 항목 제한
  - 작업표시줄/Windows 추천 알림 제한
  - 잠금화면 Spotlight/추천 콘텐츠 제한

### Changed

- 특정 하이퍼바이저 이름을 문서에서 제거하고 `VM 환경` 기준 설명으로 일반화했습니다.
- 고정 사용자 프로필 드라이브 경로 안내를 제거하고, `<ProfileDrive>:\Users` 템플릿 기반 안내로 변경했습니다.
- 프로필별 ps1 파일 구조 대신 단일 PowerShell 파일의 모드 옵션 방식으로 통합했습니다.
- README와 NOTICE의 참고 프로젝트 URL을 직접 노출하지 않고 `프로젝트 바로가기` 링크로 표시하도록 변경했습니다.
- Appx 제거 후보 목록에 3D Builder, Skype, OneNote, Sway, Holographic, Quick Assist, Wallet, ConnectivityStore 후보를 추가했습니다.
- 레지스트리 정책 참조 문서와 검증 체크리스트에 VM 일괄 설정 검증 항목을 보강했습니다.

### Not Included

- 특정 조직/제품명 기반 컴퓨터 이름 강제 변경은 포함하지 않았습니다.
- 특정 제품명 allowlist 기반 시작 프로그램 정리는 포함하지 않았습니다.
- 관리자 공유 비활성화와 복원 지점 전체 삭제는 고위험 항목으로 기본 스크립트에 포함하지 않았습니다.
- 특정 드라이브 문자 고정 정리는 포함하지 않았습니다.
- 외부 도구 실행은 기본 PowerShell 최적화 스크립트에 포함하지 않았습니다.

### Verification

- `git diff --check` 통과
- `scripts/sysprep/unattend.xml` XML 검증 통과
- 문서/스크립트에서 특정 하이퍼바이저명 및 고정 사용자 프로필 드라이브 경로 참조 제거 확인
- README/NOTICE에서 직접 URL 노출 제거 확인

### Commits

- `f350a64` - `feat: bootstrap Windows 11 VM template optimization repo`
- `1ead2f6` - `feat: add VM standardization tweaks`

---

## 변경 이력 작성 템플릿

아래 템플릿은 향후 버전 갱신 시 참고용으로 사용합니다. 공식 변경 이력은 이 파일 상단에 최신 버전이 먼저 오도록 작성합니다.

```markdown
## [YY.MAJOR.MINOR] - YYYY-MM-DD

### Added

- 항목을 작성합니다.

### Changed

- 항목을 작성합니다.

### Removed

- 항목을 작성합니다.

### Fixed

- 항목을 작성합니다.

### Security

- 항목을 작성합니다.

### Verification

- 항목을 작성합니다.

### Not Tested

- 항목을 작성합니다.
```

### 운영 변경 기록 참고 항목

| 항목 | 기록 내용 |
| --- | --- |
| 버전 | YY.MAJOR.MINOR |
| 날짜 | YYYY-MM-DD |
| 관련 커밋 | 커밋 해시 또는 태그 |
| 영향도 | 낮음/중간/높음 |
| 적용 모드 | `--lite` / `--standard` / `--advanced` / custom |
| 테스트 결과 | Sysprep, OOBE, 프로필 경로, Appx, 정책, 보관 검증 결과 |
| 롤백 계획 | 문제 발생 시 되돌릴 방법 |
