# Windows 11 VM 마스터 템플릿 최적화

VM 환경 기반 Windows 11 마스터 템플릿을 일관되게 생성하기 위한 자동화 스크립트와 운영 문서 모음입니다. 이 저장소는 Audit Mode에서 템플릿을 정리하고, Sysprep 및 `unattend.xml`을 통해 사용자 프로필 위치를 OS 드라이브가 아닌 별도 사용자 프로필 드라이브로 구성한 뒤, 종료 및 VHD 후처리까지 이어지는 표준 절차를 제공합니다.

## 1. 프로젝트 개요

이 프로젝트는 Windows 11을 새로 설치한 뒤 조직에서 재사용 가능한 VM 마스터 템플릿을 만들기 위한 기준 절차를 정리합니다. 기본 스크립트는 PowerShell 중심으로 구성되어 외부 상용 도구에 의존하지 않으며, 공공기관 및 망분리 환경에서 문제가 될 수 있는 과도한 기능 제거는 단일 스크립트의 모드 옵션으로 분리합니다.

주요 산출물은 다음과 같습니다.

- Windows 11 설치 후 Audit Mode 작업 절차 문서
- 별도 사용자 프로필 드라이브 기반 사용자 프로필 생성을 위한 Sysprep `unattend.xml` 템플릿
- 템플릿 종료 전 임시 파일, 업데이트 캐시, Defender 기록, 이벤트 로그 등 정리 스크립트
- Appx, Provisioned Appx, 서비스, 예약 작업, 검색/Bing/Copilot/Recall/개인정보 정책 조정 기준
- Sysprep, 종료, VHD 후처리, 압축까지 이어지는 운영 체크리스트

## 2. 프로젝트가 해결하려는 문제

Windows 11 VM 템플릿을 수작업으로 만들면 다음 문제가 반복됩니다.

1. 작업자별 절차 편차로 인해 템플릿 품질이 달라집니다.
2. Sysprep 전후 정리 항목이 누락되어 용량이 커지고 개인정보성 흔적이 남을 수 있습니다.
3. 사용자 프로필 위치를 뒤늦게 레지스트리로 강제 변경하여 업데이트, Store 앱, Sysprep 호환성 문제가 발생할 수 있습니다.
4. 공공기관/망분리 환경에서 클라우드 검색, 소비자 기능, 불필요 앱이 남아 감사 대응 부담이 증가합니다.
5. VHD 압축 및 보관 과정이 문서화되지 않아 재현성과 변경 추적이 어렵습니다.

이 저장소는 위 문제를 줄이기 위해 “절차 문서 + 보수적 기본값 + 옵션화된 자동화 + 검증 체크리스트” 형태로 운영 기준을 제공합니다.

## 3. 주요 기능

- Audit Mode 진입 및 템플릿 작업 흐름 문서화
- `unattend.xml`을 사용한 별도 사용자 프로필 드라이브 구성 예시 제공
- PowerShell 기반 템플릿 최적화 스크립트 제공
- `--lite`, `--standard`, `--advanced` 모드를 제공하는 단일 PowerShell 스크립트
- 임시 파일, 업데이트 캐시, Defender 검사 기록, 이벤트 로그 정리
- Windows Appx 및 Provisioned Appx 제거 후보 관리
- 서비스 및 예약 작업 비활성화 후보 관리
- 검색/Bing/Copilot/Recall/소비자 기능/개인정보/전원/탐색기/시작 메뉴/작업표시줄 관련 정책 참조 제공
- Sysprep 전후 체크리스트 및 빌드 후 검증 체크리스트 제공
- VHD 후처리 및 `.pck` 압축/해제 보조 배치 파일 제공

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
- 조직별 보안 제품, NAC, DLP, VDI 에이전트 설치 자동화
- Windows 라이선스 인증 자동화

외부 도구가 필요한 작업은 문서상 후처리 단계에서만 언급합니다.

## 5. 디렉터리 구조 설명

```text
win11-vm-template-optimize/
├─ README.md
├─ LICENSE
├─ NOTICE.md
├─ .gitignore
├─ docs/
│  ├─ build-process.md
│  ├─ cleanup-items.md
│  ├─ sysprep-guide.md
│  ├─ audit-notes.md
│  └─ changelog-template.md
├─ scripts/
│  ├─ win11_master_template_optimize.ps1
│  ├─ sysprep/
│  │  └─ unattend.xml
│  └─ compress/
│     ├─ compack.bat
│     └─ extract.bat
├─ configs/
│  ├─ appx-remove-list.txt
│  ├─ services-disable-list.txt
│  ├─ tasks-disable-list.txt
│  └─ registry-tweaks-reference.md
└─ tests/
   ├─ validation-checklist.md
   └─ post-build-checklist.md
```

- `docs/`: 템플릿 생성, 정리 항목, Sysprep, 감사 대응, 변경 이력 템플릿 문서
- `scripts/`: Audit Mode에서 실행할 단일 PowerShell 스크립트, Sysprep 응답 파일, 압축 보조 스크립트
- `configs/`: 제거/비활성화 후보 목록 및 정책 레지스트리 설명
- `tests/`: Sysprep 전 검증과 빌드 후 검증 체크리스트

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

### 6.4 별도 사용자 프로필 드라이브 구성

1. 디스크 관리 또는 `diskpart`로 OS 드라이브와 분리된 사용자 프로필용 파티션/디스크를 준비합니다.
2. 설치 ISO 또는 게스트 도구 ISO가 사용할 드라이브 문자를 점유하고 있다면 조직 표준에 맞게 다른 문자로 변경합니다.
3. 사용자 프로필용 파티션에 조직 표준 드라이브 문자를 할당합니다.
4. 필요 시 볼륨 레이블을 조직 표준 이름으로 지정합니다.
5. 별도 사용자 프로필 드라이브 아래에 사용자 프로필 루트 폴더를 미리 생성합니다.

예시:

```powershell
New-Item -ItemType Directory -Path '<ProfileDrive>:\Users' -Force
```

### 6.5 unattend.xml 적용

샘플 응답 파일은 `scripts/sysprep/unattend.xml`에 있습니다. 이 파일은 `ProfilesDirectory`를 별도 사용자 프로필 드라이브의 사용자 폴더로 지정하는 템플릿입니다. 실제 적용 전 `<ProfileDrive>`를 조직 표준 드라이브 문자로 치환하십시오.

권장 배치 위치 예시는 다음과 같습니다.

```text
C:\Windows\System32\Sysprep\unattend.xml
```

또는 Sysprep 실행 시 `/unattend:<경로>`로 직접 지정할 수 있습니다.

### 6.6 최적화 스크립트 실행

Audit Mode의 관리자 PowerShell에서 다음과 같이 실행합니다.

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
cd C:\Path\To\win11-vm-template-optimize
.\scripts\win11_master_template_optimize.ps1 --standard
```

`--standard`는 기본값이므로 옵션을 생략해도 동일하게 동작합니다. 공공기관/망분리 환경의 최초 도입 또는 영향도 검토 전에는 `--lite`를 권장합니다. 더 강한 정리/비활성화가 필요하고 복제 VM 검증이 가능한 경우에만 `--advanced`를 사용합니다.

### 6.7 Sysprep

스크립트 실행 후 `tests/validation-checklist.md`를 기준으로 Sysprep 전 상태를 확인합니다. 문제가 없으면 다음 명령을 실행합니다.

```cmd
C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\System32\Sysprep\unattend.xml
```

### 6.8 종료

Sysprep이 완료되면 VM은 자동 종료됩니다. 종료된 상태를 마스터 템플릿의 기준 상태로 간주합니다. 이 시점 이후 원본 VM을 부팅하면 OOBE/Sysprep 상태가 변경될 수 있으므로, 먼저 디스크 파일을 복제하거나 스냅샷 정책을 따릅니다.

### 6.9 VHD 후처리 및 압축

기본 스크립트는 SDelete 또는 하이퍼바이저 전용 디스크 관리 도구를 실행하지 않습니다. 필요한 경우 운영자가 별도 후처리 단계에서 다음을 검토합니다.

- 영공간 zero-fill: SDelete 등 외부 도구를 수동 사용
- VM 디스크 compact: 사용 중인 하이퍼바이저의 디스크 관리 도구 수동 사용
- 보관 압축: `scripts/compress/compack.bat` 사용
- 압축 해제 검증: `scripts/compress/extract.bat` 사용

## 7. 스크립트 모드 설명

### --lite

기존 `conservative`에 해당합니다. 장애 가능성이 낮은 항목만 활성화한 보수적 모드입니다.

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

기존 `standard`에 해당합니다. 일반적인 마스터 템플릿에 권장되는 균형형 기본 모드입니다.

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

기존 `aggressive`에 해당합니다. 더 강한 정리와 비활성화를 수행하는 고강도 모드입니다.

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
- SDelete, 하이퍼바이저 전용 디스크 관리 도구, 7-Zip 등 외부 도구는 기본 최적화 스크립트에 포함하지 않습니다. 필요 시 별도 후처리 단계에서 수동으로 사용합니다.
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

자세한 고지는 `NOTICE.md`를 참조하십시오.

## 10. 향후 계획

- 조직별 커스텀 모드 또는 옵션 프리셋 예시 추가
- Windows 11 버전별 Appx 제거 영향도 매트릭스 작성
- Sysprep 실패 사례와 조치 가이드 확장
- 오프라인/망분리 환경용 패키지 반입 체크리스트 추가
- PowerShell Pester 기반 정적 검증 테스트 추가
- VHD 후처리 절차와 압축 검증 자동화 문서 보강
- 변경 이력 템플릿 기반 릴리스 노트 운영
