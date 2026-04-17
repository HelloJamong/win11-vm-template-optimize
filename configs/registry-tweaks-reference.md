# 정책/레지스트리 설정 참조

이 문서는 `scripts/win11_master_template_optimize.ps1`에서 적용하는 Search/Bing/Copilot/Recall/Consumer/privacy 관련 정책 키의 목적과 주의사항을 정리합니다.

## 1. Windows Search/Bing/Cloud Search

| 경로 | 값 | 권장값 | 의미 | 주의사항 |
| --- | --- | --- | --- | --- |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | `DisableWebSearch` | `1` | Windows 검색의 웹 검색 제한 | 시작 메뉴 검색 결과가 로컬 중심으로 제한됨 |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | `AllowCloudSearch` | `0` | 클라우드 검색 제한 | Microsoft 계정/조직 계정 검색 통합 영향 가능 |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | `ConnectedSearchUseWeb` | `0` | 연결된 웹 검색 사용 제한 | 버전별 적용 범위 확인 필요 |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | `ConnectedSearchUseWebOverMeteredConnections` | `0` | 종량제 연결에서 웹 검색 제한 | 망분리 환경에서는 보수적으로 적용 |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer` | `DisableSearchBoxSuggestions` | `1` | 검색 상자 제안 제한 | 사용자 경험 변경 가능 |

## 2. Copilot/AI/Recall

| 경로 | 값 | 권장값 | 의미 | 주의사항 |
| --- | --- | --- | --- | --- |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot` | `TurnOffWindowsCopilot` | `1` | Windows Copilot 제한 | Windows 11 버전별 정책 지원 확인 |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `DisableAIDataAnalysis` | `1` | AI 데이터 분석 기능 제한 의도 | 버전별로 미지원일 수 있음 |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `AllowRecallEnablement` | `0` | Recall 계열 기능 제한 의도 | 하드웨어/버전별 제공 여부 확인 필요 |

## 3. Consumer Experience/Cloud Content

| 경로 | 값 | 권장값 | 의미 | 주의사항 |
| --- | --- | --- | --- | --- |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableWindowsConsumerFeatures` | `1` | 소비자 기능 및 추천 앱 제한 | 일부 추천/자동 설치 흐름 감소 |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableTailoredExperiencesWithDiagnosticData` | `1` | 진단 데이터 기반 맞춤 경험 제한 | 개인정보 최소화 목적 |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableThirdPartySuggestions` | `1` | 타사 제안 제한 | 광고성 제안 감소 목적 |

## 4. Privacy/Telemetry/Activity

| 경로 | 값 | 권장값 | 의미 | 주의사항 |
| --- | --- | --- | --- | --- |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection` | `AllowTelemetry` | `0` | 진단 데이터 최소화 의도 | 에디션에 따라 Security 수준 적용 제한 가능 |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo` | `DisabledByGroupPolicy` | `1` | 광고 ID 제한 | 사용자 맞춤 광고 감소 |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\System` | `EnableActivityFeed` | `0` | 활동 피드 제한 | 타임라인/활동 연동 영향 |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\System` | `PublishUserActivities` | `0` | 사용자 활동 게시 제한 | 계정 연동 기능 영향 가능 |
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\System` | `UploadUserActivities` | `0` | 사용자 활동 업로드 제한 | 클라우드 동기화 기능 영향 가능 |

## 5. 운영 메모

- 조직 GPO가 적용되는 환경에서는 로컬 정책이 GPO에 의해 덮어써질 수 있습니다.
- Windows 11 릴리스별로 정책 키가 무시되거나 다른 정책이 추가될 수 있습니다.
- 정책 변경 후에는 재부팅 또는 `gpupdate /force`가 필요할 수 있습니다.
- 모든 정책 적용 결과는 변경 이력에 기록하십시오.

## 6. 추가 통합 스크립트 설정

제공된 통합 최적화 스크립트 반영으로 아래 정책/레지스트리 값도 적용 후보에 포함됩니다.

| 구분 | 경로 | 값 | 권장값 | 의미 | 주의사항 |
| --- | --- | --- | --- | --- | --- |
| Search | `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search` | `AllowCortana` | `0` | Cortana/검색 연동 제한 | Windows 11 빌드별로 무시될 수 있음 |
| Recall/AI | `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` | `TurnOffSavingSnapshots` | `1` | 스냅샷 저장 계열 기능 제한 의도 | 기능 제공 여부는 하드웨어/빌드에 따라 다름 |
| Consumer | `HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableConsumerAccountStateContent` | `1` | 계정 상태 기반 추천 콘텐츠 제한 | 개인화 추천 감소 |
| Consumer | `HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent` | `DisableCloudOptimizedContent` | `1` | 클라우드 최적화 콘텐츠 제한 | 에디션/빌드별 적용 차이 가능 |
| ContentDelivery | `HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager` | `SubscribedContent-*Enabled` | `0` | 사용자별 추천/제안 콘텐츠 제한 | Audit Mode Administrator 기준 HKCU에 먼저 적용됨 |
| ContentDelivery | `HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager` | `SoftLandingEnabled` | `0` | Windows 팁/추천성 UI 제한 | 사용자 경험 변경 가능 |
| Delivery Optimization | `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config` | `DODownloadMode` | `0` | Delivery Optimization 공유 제한 | 조직 WSUS/DO 정책과 충돌 여부 확인 |
| Delivery Optimization | `HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization` | `DODownloadMode` | `0` | 정책 기반 Delivery Optimization 제한 | GPO 적용 시 GPO가 우선 |
| Explorer | `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `ShowSyncProviderNotifications` | `0` | 탐색기 동기화 공급자 알림 축소 | UI 알림 감소 목적 |
| Explorer | `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `LaunchTo` | `1` | 파일 탐색기 시작 위치 조정 | 사용자별 설정 |

> `HKCU` 기반 설정은 Audit Mode의 현재 사용자에 먼저 적용됩니다. 새 사용자 전체에 동일 정책을 강제하려면 GPO, 기본 사용자 프로필, 배포 후 로그인 스크립트 등 조직 표준 방식을 별도로 검토하십시오.

## 7. VM 일괄 설정 추가 항목

과거 배치 테스트 도구에서 운영 가치가 높다고 판단한 항목을 PowerShell 단일 스크립트의 선택 토글로 재구성했습니다.

| 토글 | 주요 경로/명령 | 의미 | 기본 적용 모드 | 주의사항 |
| --- | --- | --- | --- | --- |
| `EnablePowerPlanTweaks` | `powercfg /setactive SCHEME_MIN`, `powercfg /change *-timeout-* 0` | 고성능 전원 계획 적용, 화면 꺼짐/절전/최대절전 타임아웃 해제 | `--standard`, `--advanced` | 절전 정책이 필요한 조직 이미지는 비활성화 검토 |
| `EnableExplorerPrivacyCleanup` | `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer` | 최근 파일, 자주 쓰는 폴더, Office.com 파일 표시 제한 및 탐색기 기록 정리 | 전체 모드 | Audit Mode 현재 사용자 기준 HKCU 설정임 |
| `EnableStartMenuTweaks` | `HKCU\Software\Microsoft\Windows\CurrentVersion\Start`, `ContentDeliveryManager` | 시작 메뉴 최근/추천/계정 알림성 표시 제한 | `--standard`, `--advanced` | 사용자 경험 변경 가능 |
| `EnableTaskbarAndNotificationTweaks` | `HKCU\...\Explorer\Advanced`, `HKLM\SOFTWARE\Policies\Microsoft\Dsh` | Task View/Widgets 버튼 및 Windows 추천/환영/팁 알림 제한 | `--standard`, `--advanced` | 검색 UI 형태는 강제하지 않음 |
| `EnableLockScreenContentTweaks` | `HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager` | 잠금화면 Spotlight, 팁, 추천 콘텐츠, 슬라이드쇼성 표시 제한 | 전체 모드 | 조직 GPO가 있으면 GPO가 우선 |

반영하지 않은 고위험 항목:

- 컴퓨터 이름 강제 변경
- 특정 제품명 기반 시작 프로그램 allowlist
- 관리자 공유 비활성화
- 복원 지점 전체 삭제
- 특정 드라이브 문자 고정 정리
