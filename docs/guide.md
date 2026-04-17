# Windows 11 VM 마스터 템플릿 통합 가이드

이 문서는 Windows 11 VM 마스터 템플릿 생성, Audit Mode 작업, 별도 사용자 프로필 드라이브 구성, 최적화 스크립트 실행, Sysprep, 종료, 후처리, 감사 체크포인트를 한 곳에 정리한 통합 운영 가이드입니다.

## 1. 운영 원칙

- VM 환경과 하이퍼바이저 종류에 종속되지 않는 절차를 우선합니다.
- 기본 자동화는 PowerShell 중심으로 유지합니다.
- 외부 도구 실행은 기본 스크립트에 포함하지 않고 후처리 단계에서만 별도 수행합니다.
- 공공기관/망분리 환경을 고려해 과도한 제거/비활성화는 모드 옵션으로 분리합니다.
- 사용자 프로필 위치는 기존 프로필을 레지스트리로 강제 이동하지 않고 Sysprep `unattend.xml`에서 `ProfilesDirectory`로 지정합니다.
- 실행한 정리, 삭제, 비활성화, 정책 변경은 `CHANGELOG.md` 또는 내부 변경 이력에 기록합니다.

## 2. 사전 준비

- Windows 11 ISO
- VM 실행 환경
- 조직 표준 VM 설정값
  - vCPU
  - Memory
  - TPM/Secure Boot
  - 그래픽/네트워크 설정
  - 기본 디스크 크기
- 이 저장소 파일 일체
- 선택 후처리 도구
  - SDelete 등 영공간 정리 도구: 기본 스크립트에는 포함하지 않음
  - 하이퍼바이저 전용 디스크 관리 도구: VM 디스크 compact용, 기본 스크립트에는 포함하지 않음

## 3. OS 설치 및 Audit Mode 진입

1. 사용 중인 VM 환경에서 새 Windows 11 VM을 생성합니다.
2. Windows 11 요구사항에 맞게 TPM, Secure Boot, CPU, Memory, Storage를 구성합니다.
3. Windows 11 ISO를 연결하고 VM을 부팅합니다.
4. 일반 설치 절차를 진행합니다.
5. 설치 완료 후 OOBE 화면이 표시되면 일반 사용자 계정을 만들지 않습니다.
6. OOBE 화면에서 `Ctrl + Shift + F3`을 눌러 Audit Mode로 진입합니다.
7. 재부팅 후 Administrator 계정으로 자동 로그인되면 Sysprep 창을 닫거나 최소화합니다.

Audit Mode는 사용자 계정 생성 전 상태에서 드라이버, 앱, 정책, 정리 작업을 수행하기 위한 준비 모드입니다.

## 4. 별도 사용자 프로필 드라이브 준비

1. `diskmgmt.msc` 또는 `diskpart`로 OS 드라이브와 분리된 사용자 프로필용 파티션/디스크를 준비합니다.
2. 설치 미디어 또는 게스트 도구 ISO가 사용자 프로필용 드라이브 문자를 점유하고 있으면 다른 문자로 변경합니다.
3. 사용자 프로필용 파티션에 조직 표준 드라이브 문자를 할당합니다.
4. NTFS로 포맷하고 조직 표준 볼륨 레이블을 지정합니다.
5. 별도 사용자 프로필 드라이브 아래에 사용자 프로필 루트 폴더를 만듭니다.

예시:

```powershell
New-Item -ItemType Directory -Path '<ProfileDrive>:\Users' -Force
icacls '<ProfileDrive>:\Users'
```

`<ProfileDrive>`는 실제 운영 드라이브 문자로 치환해야 합니다.

## 5. Sysprep unattend.xml 준비

샘플 파일:

```text
scripts\sysprep\unattend.xml
```

핵심 설정:

```xml
<FolderLocations>
  <ProfilesDirectory>&lt;ProfileDrive&gt;:\Users</ProfilesDirectory>
</FolderLocations>
<TimeZone>Korea Standard Time</TimeZone>
```

주의사항:

- `unattend.xml`은 드라이브 문자를 자동 선택하지 않습니다.
- 실제 Sysprep 실행 전 `<ProfileDrive>`를 조직 표준 사용자 프로필 드라이브 문자로 치환해야 합니다.
- 해당 드라이브와 사용자 프로필 루트 폴더는 Sysprep 실행 전에 존재해야 합니다.
- 기존 사용자 프로필을 `ProfileList` 레지스트리로 강제 이동하는 방식은 비권장입니다.

권장 배치 위치:

```text
C:\Windows\System32\Sysprep\unattend.xml
```

복사 예시:

```powershell
Copy-Item '.\scripts\sysprep\unattend.xml' 'C:\Windows\System32\Sysprep\unattend.xml' -Force
```

### 5.1 선택: unattend.xml ISO 생성

VM에 파일을 직접 복사하기 어렵다면 ISO로 전달할 수 있습니다.

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\scripts\sysprep\build-unattend-iso.ps1 -ProfileDrive E -OutputIso .\scripts\sysprep\unattend-E.iso
```

생성된 ISO를 VM에 연결한 뒤 Audit Mode에서 복사합니다.

```powershell
Copy-Item '<ISODrive>:\unattend.xml' 'C:\Windows\System32\Sysprep\unattend.xml' -Force
```

`<ISODrive>`는 VM 안에서 ISO가 연결된 드라이브 문자입니다.

## 6. 최적화 스크립트 실행

관리자 PowerShell에서 실행합니다.

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\scripts\win11_master_template_optimize.ps1 --standard
```

모드:

| 모드 | 설명 | 권장 상황 |
| --- | --- | --- |
| `--lite` | 보수적/저위험 정리 | 공공기관/망분리 초기 검증, 영향도 최소화 |
| `--standard` | 기본 균형형 최적화 | 일반적인 VM 마스터 템플릿 |
| `--advanced` | 강한 정리/비활성화 | 복제 VM 검증 후 제한적으로 사용 |

주요 작업:

- Temp/Cache 정리
- Windows Update 다운로드 캐시 정리
- Defender scan history 정리
- 이벤트 로그 초기화
- hibernation 비활성화
- Appx 및 Provisioned Appx 제거
- 서비스/예약 작업 비활성화
- Search/Bing/Copilot/Recall/Consumer/privacy 정책 설정
- 전원 계획, 탐색기 개인정보, 시작 메뉴, 작업표시줄, 잠금화면 콘텐츠 정리
- cleanmgr 실행
- DISM component cleanup 실행

## 7. 정리 대상과 주의사항

| 경로/항목 | 역할 | 삭제 가능 여부 | 주의사항 |
| --- | --- | --- | --- |
| `C:\Windows\Temp` | 시스템 임시 파일 | 일반적으로 가능 | 설치/업데이트 중에는 일부 파일이 잠길 수 있음 |
| `%TEMP%`, `%TMP%` | 현재 사용자 임시 파일 | 가능 | Audit Mode Administrator 기준 정리 |
| `C:\Users\*\AppData\Local\Temp` | 사용자별 임시 파일 | 가능 | 사용자 앱 세션 파일 포함 가능 |
| `C:\Windows\SoftwareDistribution\Download` | Windows Update 다운로드 캐시 | 가능 | 업데이트 설치 중 삭제 금지 |
| `C:\Windows\Panther` | Windows 설치 로그 | 조건부 가능 | Sysprep 실패 분석 전 삭제 금지 |
| `C:\Windows\System32\Sysprep\Panther` | Sysprep 로그 | 조건부 가능 | Sysprep 실패 원인 분석 핵심 위치 |
| `C:\ProgramData\Microsoft\Windows Defender\Scans\History` | Defender 검사 기록 | 가능 | 보안 감사상 보존 필요 여부 확인 |
| 이벤트 로그 | 시스템/응용 프로그램/보안 이벤트 | 조건부 가능 | 감사/장애 분석 필요 시 보존 |
| `hiberfil.sys` | 최대 절전 파일 | 가능 | VM 템플릿에서는 보통 제거 권장 |
| `pagefile.sys` | 페이지 파일 | 비권장/옵션 | 덤프/메모리 압박 대응에 필요할 수 있음 |
| `C:\ProgramData\Package Cache` | 설치 패키지 캐시 | 비권장 | MSI/런타임 복구에 필요할 수 있음 |

운영 원칙:

1. 정리 작업은 Sysprep 직전 1회 수행을 원칙으로 합니다.
2. 업데이트, 드라이버, 보안 제품 설치 중에는 캐시를 삭제하지 않습니다.
3. 감사 또는 장애 분석에 필요한 로그는 삭제 전 보존 여부를 결정합니다.
4. 삭제 항목과 실행 시점은 변경 이력에 기록합니다.

## 8. 공공기관/망분리 체크포인트

### 8.1 Administrator 계정/폴더

- Administrator 바탕 화면, 다운로드, 문서 폴더에 작업 파일이 남아 있지 않은지 확인
- `%TEMP%` 및 `C:\Users\Administrator\AppData\Local\Temp` 정리
- 브라우저 다운로드 기록, 캐시, 자동 완성 데이터 정리
- Administrator 계정 활성/비활성 정책 확인
- 임시 비밀번호가 이미지에 남지 않도록 관리

### 8.2 defaultuser0

- 기본 OS 프로필 경로 또는 별도 사용자 프로필 드라이브 아래의 `defaultuser0` 존재 여부 확인
- Sysprep 전 단계에서 무리하게 삭제하지 않음
- OOBE 테스트 후 잔여 계정으로 확인될 때 정리 검토

### 8.3 앱/클라우드/소비자 기능

검토 대상:

- Phone Link
- Xbox 관련 앱
- Copilot 관련 앱 또는 정책
- Teams 개인용 구성요소
- 소비자 경험 기반 추천 앱
- Bing/Web/Cloud Search
- Recall/AI 스냅샷성 기능

정책 방향:

- 제거보다 비활성화가 안전한 항목은 비활성화를 우선 검토합니다.
- 제거 후보는 `configs/appx-remove-list.txt`에서 관리합니다.
- 업무 앱과 보안 에이전트 영향도를 복제 VM에서 검증합니다.

### 8.4 감사 대응 기록

다음을 기록합니다.

- 적용 모드
- 실행 스크립트 버전 또는 커밋
- 적용 일시와 실행자
- 삭제한 Appx 목록
- 비활성화한 서비스/예약 작업 목록
- 적용한 정책 키
- 업무 앱 검증 결과
- Sysprep 결과
- 후처리 및 보관 검증 결과

## 9. Sysprep 실행

Sysprep 전 별도 관리 중인 검증 문서와 아래 핵심 항목을 확인한 뒤 실행합니다.

```cmd
C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\System32\Sysprep\unattend.xml
```

옵션:

- `/generalize`: SID, 장치 고유 정보 등 일반화
- `/oobe`: 다음 부팅 시 OOBE로 진입
- `/shutdown`: Sysprep 완료 후 종료
- `/unattend`: 응답 파일 지정

Sysprep 실패 시 확인 위치:

- `C:\Windows\System32\Sysprep\Panther\setuperr.log`
- `C:\Windows\System32\Sysprep\Panther\setupact.log`
- `C:\Windows\Panther\setuperr.log`
- `C:\Windows\Panther\setupact.log`

## 10. 종료 및 후처리

Sysprep이 정상 완료되면 VM이 종료됩니다.

중요:

- 종료 후 원본 VM을 다시 부팅하지 않습니다.
- 먼저 디스크 파일을 복제하거나 스냅샷/템플릿 정책을 적용합니다.
- 원본을 부팅하면 OOBE가 진행되어 템플릿 상태가 변경될 수 있습니다.

선택 후처리:

- 영공간 zero-fill: 외부 도구를 수동 사용
- VM 디스크 compact: 사용 중인 하이퍼바이저의 디스크 관리 도구 수동 사용
- 보관이 필요한 경우 조직 표준 도구와 절차를 별도로 사용

## 11. 핵심 검증 항목

검증 체크리스트는 별도 문서로 관리합니다. 이 저장소에서는 Sysprep 전후 반드시 확인할 핵심 기준만 유지합니다.

- 별도 사용자 프로필 드라이브와 사용자 프로필 루트 폴더 존재 여부
- `unattend.xml`의 `<ProfileDrive>` 치환 여부
- `ProfilesDirectory`와 `TimeZone` 값 확인
- 최적화 스크립트 실행 로그 확인
- Appx, 서비스, 예약 작업, 정책 적용 결과 확인
- Administrator/defaultuser0 잔여 상태 확인
- Sysprep 로그 오류 여부 확인
- OOBE 후 신규 사용자 프로필 경로 확인
- 조직 표준 후처리 및 보관 검증 결과 확인

공식 변경 이력은 `CHANGELOG.md`에 기록합니다.
