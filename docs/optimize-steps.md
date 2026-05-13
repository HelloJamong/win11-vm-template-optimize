# 최적화 스크립트 실행 항목 목록

`scripts/win11_master_template_optimize.ps1` 실행 시 처리되는 44개 단계를 기록합니다.

**기본값 표기**
- ✅ 기본 활성화 (스크립트 실행 시 적용됨)
- ⬜ 기본 비활성화 (필요 시 스크립트 상단 옵션 변수를 `$true`로 변경 후 실행)

---

## 1. 데이터 정리

| # | 항목 | 기본값 | 주요 처리 내용 |
|---|------|:------:|--------------|
| 1 | 임시 파일 및 캐시 정리 | ✅ | `Windows\Temp`, `Prefetch`, `Minidump`, `SoftwareDistribution\Download`, `DeliveryOptimization`, `System32\LogFiles`, `$Recycle.Bin`, `MEMORY.DMP` 삭제 / 사용자별 `AppData\Local\Temp`, `INetCache`, Explorer 캐시, `D3DSCache`, `CrashDumps`, UWP 앱 `TempState`·`LocalCache` 삭제 |
| 1-a | 설치 잔여물 정리 | ✅ | `Windows\Installer\$PatchCache$`, `ProgramData\Package Cache`, `ProgramData\Microsoft\Windows\WER` 및 사용자 영역 동일 경로 삭제 (`$EnableInstallerResidueCleanup`) |
| 1-b | 설치·배포 로그 정리 | ✅ | `Windows\Panther`, `Sysprep\Panther`, `Logs\DISM`, `Logs\CBS` 삭제 (`$EnableSetupLogCleanup`) |
| 1-c | 다운로드/바탕화면 정리 | ⬜ | 사용자 `Downloads`, `Desktop` 내용 삭제 (`$EnableDownloadsDesktopCleanup`) |
| 2 | Windows Update 캐시 정리 | ✅ | `SoftwareDistribution\Download`, `SoftwareDistribution\DeliveryOptimization` 삭제 |
| 3 | Windows Defender 검사 기록 정리 | ✅ | `Windows Defender\Scans\History`, `Windows Defender\Scans\Tmp` 삭제 |
| 4 | 이벤트 로그 초기화 | ✅ | `wevtutil` 로 전체 이벤트 로그 채널 순회하여 초기화 |

---

## 2. 시스템 구성

| # | 항목 | 기본값 | 주요 처리 내용 |
|---|------|:------:|--------------|
| 5 | 최대 절전 비활성화 | ✅ | `powercfg -h off` 실행, `hiberfil.sys` 제거 |
| 6 | 전원 계획 및 절전 설정 조정 | ✅ | 고성능 전원 계획(`SCHEME_MIN`) 활성화 / 모니터·절전·최대절전 타임아웃 0으로 설정(AC/DC 모두) / 레지스트리 `GlobalFlags=0`, 잠금화면 표시 옵션 조정 |
| 7 | Pagefile 비활성화 | ⬜ | 자동 pagefile 관리 해제, `C:\pagefile.sys` 삭제 시도 — 재부팅 후 검증 필요 |

---

## 3. 앱 제거

| # | 항목 | 기본값 | 주요 처리 내용 |
|---|------|:------:|--------------|
| 8 | Appx 앱 제거 | ✅ | Xbox, GamingApp, Clipchamp, ZuneMusic/Video, Camera, Teams, SkypeApp, YourPhone, CrossDevice, Mail&Calendar, OfficeHub, Outlook, Todos, PowerAutomate, OneNote, Copilot, Cortana, BingNews, BingWeather, Maps, Solitaire, People, StickyNotes, Alarms, FeedbackHub, GetHelp, Getstarted, DevHome, QuickAssist + `configs/appx-remove-list.txt` 추가 항목 |
| 9 | Provisioned Appx 제거 | ✅ | 동일 패턴으로 `Get-AppxProvisionedPackage` 대상 제거 — 신규 사용자 생성 시 앱 재설치 방지 |
| 10 | OneDrive 제거 | ✅ | `OneDriveSetup.exe /uninstall` (32bit/64bit 모두 시도), `ProgramData\Microsoft OneDrive`, `OneDriveTemp` 폴더 삭제 |

---

## 4. 서비스 및 예약 작업

| # | 항목 | 기본값 | 주요 처리 내용 |
|---|------|:------:|--------------|
| 11 | 서비스 비활성화 | ✅ | `DiagTrack`(진단 추적), `MapsBroker`(지도), `OneSyncSvc`(계정 동기화) → Disabled + `configs/services-disable-list.txt` 추가 항목 |
| 12 | NetBIOS over TCP/IP 비활성화 | ✅ | IP 활성 어댑터 전체에 `SetTCPIPNetBIOS(2)` 적용 — 불필요한 NetBIOS 브로드캐스트 제거 및 LLMNR/NetBIOS 기반 MITM 공격 노출 감소 |
| 13 | NetBIOS 포트 인바운드 차단 | ✅ | `137/UDP`(NBNS), `138/UDP`(Datagram), `139/TCP`(Session) 인바운드 방화벽 차단 — 모든 프로필 적용, 12단계와 이중 차단 구성 |
| 14 | SMB 포트 인바운드 차단 | ✅ | `445/TCP`(SMB Direct) 인바운드 방화벽 차단 — 완전 망분리·독립 VM 환경 권장. 도메인 가입·파일 서버 연결 환경에서는 건너뜀 권장 |
| 15 | 예약 작업 비활성화 | ✅ | Application Experience: `Compatibility Appraiser`, `ProgramDataUpdater` / CEIP: `Consolidator`, `UsbCeip` / DiskDiagnostic: `DiskDiagnosticDataCollector` / Feedback: `DmClient`, `DmClientOnScenarioDownload` / Maps: `MapsUpdateTask` + `configs/tasks-disable-list.txt` 추가 항목 |

---

## 5. 정책 및 레지스트리 조정

### 5-1. 검색·AI

| # | 항목 | 기본값 | 주요 처리 내용 |
|---|------|:------:|--------------|
| 16 | 검색/Bing/클라우드 연계 차단 | ✅ | `AllowCortana=0`, `DisableWebSearch=1`, `ConnectedSearchUseWeb=0`, `AllowCloudSearch=0`, `DisableSearchBoxSuggestions=1` |
| 17 | Copilot 비활성화 | ✅ | `TurnOffWindowsCopilot=1` (HKLM + HKCU) |
| 18 | AI/Recall 기능 차단 | ✅ | `DisableAIDataAnalysis=1`, `TurnOffSavingSnapshots=1`, `AllowRecallEnablement=0` |

### 5-2. 소비자 경험·개인정보

| # | 항목 | 기본값 | 주요 처리 내용 |
|---|------|:------:|--------------|
| 19 | 소비자 경험/광고/추천 앱 비활성화 | ✅ | `DisableWindowsConsumerFeatures=1`, `DisableConsumerAccountStateContent=1`, `DisableCloudOptimizedContent=1`, `DisableTailoredExperiencesWithDiagnosticData=1`, `DisableThirdPartySuggestions=1` / ContentDeliveryManager 구독 콘텐츠 항목 비활성화, `SoftLandingEnabled=0` |
| 20 | 개인정보/텔레메트리 정책 적용 | ✅ | `AllowTelemetry=0`, `DoNotShowFeedbackNotifications=1`, 광고 ID `DisabledByGroupPolicy=1`, `EnableActivityFeed=0`, `PublishUserActivities=0`, `UploadUserActivities=0` |
| 21 | 개인 정보 및 보안 > 일반/권장 사항 조정 | ✅ | `HttpAcceptLanguageOptOut=1`(언어 목록 웹 공유 차단), `EnableAccountNotifications=0`(설정 알림 끔), `IsDeviceSearchHistoryEnabled=0` / `Search\RecentApps` 레지스트리 키 삭제 |

### 5-3. 로그인·앱

| # | 항목 | 기본값 | 주요 처리 내용 |
|---|------|:------:|--------------|
| 22 | 로그인 옵션 조정 | ✅ | `DisableAutomaticRestartSignOn=1` — 업데이트/재시작 후 ARSO(자동 로그인 완료) 비활성화 |
| 23 | 작업 표시줄 작업 종료 버튼 활성화 | ✅ | `TaskbarEndTask=1` — 작업 표시줄 우클릭 메뉴에 '작업 종료' 항목 표시 |
| 24 | 앱 자동 재시작 비활성화 | ✅ | `RestartApps=0` — 로그인 시 이전 앱 자동 재시작 차단 |
| 25 | Delivery Optimization 외부 공유 차단 | ✅ | `DODownloadMode=0` (Config + Policies 두 경로 모두 적용) |

### 5-4. 탐색기·UI

| # | 항목 | 기본값 | 주요 처리 내용 |
|---|------|:------:|--------------|
| 26 | 파일 탐색기 UI 조정 | ✅ | `ShowSyncProviderNotifications=0`(OneDrive 등 동기화 알림 제거), `LaunchTo=1`(탐색기 기본 시작 위치: 내 PC) |
| 27 | 파일 탐색기 사용 흔적 정리 | ✅ | `ShowRecent=0`, `ShowFrequent=0`, `ShowCloudFilesInQuickAccess=0`, `Start_TrackDocs=0` / `RecentDocs`, `RunMRU`, `TypedPaths`, `WordWheelQuery` 레지스트리 키 삭제 / `AppData\Roaming\Microsoft\Windows\Recent` 내용 삭제 |

### 5-5. 시작 메뉴·작업표시줄

| # | 항목 | 기본값 | 주요 처리 내용 |
|---|------|:------:|--------------|
| 28 | 시작 메뉴 추천/최근 항목 표시 제한 | ✅ | `ShowRecentList=0`, `ShowFrequentList=0`, `ShowRecommendations=0`, `Start_TrackDocs=0`, `Start_TrackProgs=0` |
| 29 | 개인설정 > 시작 조정 | ✅ | `Start_IrisRecommendations=0`(팁/권장 사항 끔), `Start_AccountNotifications=0`(계정 알림 끔) / 전원 버튼 옆 폴더: 설정·파일 탐색기·다운로드 3개만 표시(`VisiblePlaces` 기준) |
| 30 | 작업표시줄/알림 정리 | ✅ | `ShowTaskViewButton=0`(작업 보기 버튼 숨김), `TaskbarDa=0`(Widgets 숨김), `AllowNewsAndInterests=0`, ContentDeliveryManager `310093`·`338393` 비활성화, `ScoobeSystemSettingEnabled=0`(Windows 환영 경험 끔) |
| 31 | 잠금화면 콘텐츠 제한 | ✅ | `RotatingLockScreenEnabled=0`(Spotlight 끔), `RotatingLockScreenOverlayEnabled=0`, `SubscribedContent-338387Enabled=0`, `LockScreenOverlayEnabled=0`, `SlideshowEnabled=0` |

---

## 6. 디스크 정리

| # | 항목 | 기본값 | 주요 처리 내용 |
|---|------|:------:|--------------|
| 32 | Windows 선택적 기능 비활성화 | ⬜ | `Printing-XPSServices-Features`, `WorkFolders-Client`, `SMB1Protocol` 비활성화 |
| 33 | Windows 디스크 정리 (cleanmgr) | ✅ | `cleanmgr.exe /verylowdisk` 실행 |
| 34 | DISM 컴포넌트 저장소 정리 | ✅ | `dism /online /cleanup-image /startcomponentcleanup /resetbase` 실행 (`$EnableResetBase=true`이면 `/resetbase` 포함 — 롤백 기반 제거) |
| 35 | CompactOS 적용 | ⬜ | `compact.exe /compactos:always` — OS 파일 XPRESS4K 압축 (CPU 오버헤드 증가 가능) |

---

## 7. Microsoft Edge 정책

| # | 항목 | 기본값 | 주요 처리 내용 |
|---|------|:------:|--------------|
| 36 | Microsoft Edge 최적화 | ✅ | VDOT 기준 정책 적용: `BackgroundModeEnabled=0`, `StartupBoostEnabled=0`, `HideFirstRunExperience=1`, `ShowRecommendationsEnabled=0`, `WebWidgetAllowed=0`, `EfficiencyMode=0`, `AutofillAddressEnabled=0`, `AutofillCreditCardEnabled=0`, `PasswordManagerEnabled=0`, `NetworkPredictionOptions=2`, `HardwareAccelerationModeEnabled=1` / 레거시 Edge `AllowPrelaunch=0`, `AllowTabPreloading=0` / Edge 업데이트 억제(04:00 기준 900분) |

---

## 8. UI 및 환경 설정

| # | 항목 | 기본값 | 주요 처리 내용 |
|---|------|:------:|--------------|
| 37 | 제어판 보기 기준: 큰 아이콘 | ✅ | `AllItemsIconView=0`, `StartupPage=1` |
| 38 | 시작 및 복구 OS 목록 표시 시간 3초 | ✅ | `bcdedit /timeout 3` |
| 39 | 시스템 볼륨 50% 설정 | ✅ | Windows Core Audio API (`IAudioEndpointVolume`) 사용, `SetMasterVolumeLevelScalar(0.5)` |
| 40 | 컴퓨터 이름 변경 | ✅ | `Rename-Computer -NewName 'VDI-Win11'` — 재부팅 후 적용 |
| 41 | 성능 옵션 시각 효과: Custom | ✅ | `VisualFXSetting=3` / **ON**: 아이콘 레이블 그림자, 썸네일 미리보기, 창 그림자, ClearType 글꼴 / **OFF**: 나머지 모든 애니메이션·전환 효과 |
| 42 | 바탕화면 시스템 아이콘 표시 | ✅ | 내 PC(`{20D04FE0...}`), 제어판(`{5399E694...}`) 아이콘 표시 (`HideDesktopIcons\NewStartPanel` 레지스트리) |
| 43 | 시작 메뉴 고정 항목 정리 | ✅ | `LayoutModification.json` 작성 — Edge / 파일 탐색기 / 설정 3개만 유지, 나머지 기본 고정 항목 제거 (현재 사용자 + Default 사용자 프로필 모두 적용) |

---

## 9. 후처리

| # | 항목 | 기본값 | 주요 처리 내용 |
|---|------|:------:|--------------|
| 44 | 여유 공간 통합 (defrag /X) | ⬜ | `defrag C: /X /U /V` — VHD compact 전 압축률 향상 목적. SSD/NVMe 기반 VM에서는 생략 권장 |

---

## 비활성화 기본값 항목 요약

기본값이 ⬜(비활성)인 항목만 모아서 확인할 수 있도록 정리합니다.

| 옵션 변수 | 단계 | 이유 |
|-----------|------|------|
| `$EnablePagefileDisable` | 7 | 재부팅·검증 필요, 메모리 부족 시 시스템 불안정 위험 |
| `$EnableOptionalFeatureDisable` | 30 | 환경별 필요 기능 포함 가능성, 호환성 영향 |
| `$EnableCompactOS` | 33 | CPU 오버헤드 증가, 업데이트/관리 복잡도 상승 |
| `$EnableDownloadsDesktopCleanup` | 1-c | 의도적으로 둔 파일 삭제 위험 |
| `$EnableDefragFreeSpace` | 44 | 소요 시간이 길고 SSD 환경에서는 불필요 |
