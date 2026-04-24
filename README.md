# Windows 11 VM 마스터 템플릿 최적화

VM 환경 기반 Windows 11 마스터 템플릿을 일관되게 생성하기 위한 자동화 스크립트와 운영 문서 모음입니다. 이 저장소는 Audit Mode에서 템플릿을 정리하고, Sysprep 및 `unattend.xml`을 통해 사용자 프로필 위치를 OS 드라이브가 아닌 별도 사용자 프로필 드라이브로 구성한 뒤, 종료 및 VHD 후처리까지 이어지는 표준 절차를 제공합니다.

## 1. 프로젝트 개요

이 프로젝트는 Windows 11을 새로 설치한 뒤 조직에서 재사용 가능한 VM 마스터 템플릿을 만들기 위한 기준 절차를 정리합니다. 기본 스크립트는 PowerShell 중심으로 구성되어 외부 상용 도구에 의존하지 않으며, 각 단계마다 Y/n 확인을 통해 필요한 항목만 선택적으로 적용할 수 있습니다.

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

이 저장소는 위 문제를 줄이기 위해 "절차 문서 + 보수적 기본값 + 옵션화된 자동화 + 변경 이력" 형태로 운영 기준을 제공합니다.

## 3. 주요 기능

- Audit Mode 진입 및 템플릿 작업 흐름 문서화
- `unattend.xml`을 사용한 별도 사용자 프로필 드라이브 구성 예시 제공
- PowerShell 기반 단일 최적화 스크립트 제공
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
│  ├─ build-vm-optimize-iso.ps1            ← VM_optimize ISO 생성 도구
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

전체 작업 절차 및 각 단계별 상세 안내는 **[`docs/guide.md`](docs/guide.md)** 를 참조하십시오.

작업 흐름 요약:

1. VM 부팅 후 OOBE에서 `Ctrl+Shift+F3` → Audit Mode 진입
2. D 드라이브 준비 및 Writethrough 설정
3. Sysprep 파일 배치 (`unattend.xml` / `first_logon.ps1` / `SetupComplete.cmd`)
4. Sysprep 실행 → VM 자동 종료
5. 재부팅 후 OOBE → 사용자 계정 생성 → 최초 로그인 (`first_logon.ps1` 자동 실행)
6. 필요한 프로그램 설치 및 설정
7. `win11_master_template_optimize.ps1` 실행
8. `sdelete64 -z C:` 실행 → VM 종료
9. diskpart 또는 VBoxManage로 VDI compact

## 7. 주의사항

- 공공기관/망분리 환경에서는 클라우드 연동, 소비자 경험, 광고성 구성요소, Copilot, Recall, Bing 검색을 제한하는 방향이 적합할 수 있으나, 조직 정책 및 감사 기준을 우선합니다.
- 일부 Appx 또는 Provisioned Appx 제거는 업무 앱, Windows 기능, 파일 연결, Store 기반 업데이트에 영향을 줄 수 있습니다.
- 서비스 비활성화는 부팅 시간과 리소스 사용량을 줄일 수 있지만, 진단, 업데이트, 보안 제품 연동에 영향을 줄 수 있습니다.
- 이벤트 로그 초기화는 마스터 템플릿 배포 전 흔적 제거에는 유용하지만, 감사 추적이 필요한 단계에서는 실행 시점을 기록해야 합니다.
- SDelete, 하이퍼바이저 전용 디스크 관리 도구 등 외부 도구는 기본 최적화 스크립트에 포함하지 않습니다. 필요 시 별도 후처리 단계에서 수동으로 사용합니다.
- Sysprep 실패 시 `C:\Windows\System32\Sysprep\Panther` 로그를 먼저 확인합니다.
- `ProfileList` 레지스트리를 직접 강제 수정하는 방식은 비권장합니다. 사용자 프로필 위치는 Sysprep 응답 파일로 구성합니다.

## 8. 참고 프로젝트 및 라이선스

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

## 9. 향후 계획

- Windows 11 버전별 Appx 제거 영향도 매트릭스 작성
- Sysprep 실패 사례와 조치 가이드 확장
- 오프라인/망분리 환경용 패키지 반입 기준 문서 보강
- PowerShell Pester 기반 정적 검증 테스트 추가
- VHD 후처리 절차와 조직 표준 보관 검증 문서 보강
- `CHANGELOG.md` 기반 릴리스 노트 운영
