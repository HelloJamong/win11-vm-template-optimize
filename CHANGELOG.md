# CHANGELOG

이 프로젝트의 변경 이력은 `연도.메이저버전.마이너버전` 형식으로 관리합니다.

- `연도`: 릴리스 연도의 두 자리 표기입니다. 예: 2026년 → `26`
- `메이저버전`: 프로젝트 기준선 또는 운영 방식이 크게 바뀌는 변경입니다.
- `마이너버전`: 동일 메이저 기준선 안에서 누적되는 기능/문서/검증 개선 변경입니다.

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
