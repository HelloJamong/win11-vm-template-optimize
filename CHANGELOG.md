# CHANGELOG

이 프로젝트의 변경 이력은 `연도.메이저버전.마이너버전` 형식으로 관리합니다.

- `연도`: 릴리스 연도의 두 자리 표기입니다. 예: 2026년 → `26`
- `메이저버전`: 프로젝트 기준선 또는 운영 방식이 크게 바뀌는 변경입니다.
- `마이너버전`: 동일 메이저 기준선 안에서 누적되는 기능/문서/검증 개선 변경입니다.

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
