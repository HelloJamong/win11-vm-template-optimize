# Sysprep 전 검증 체크리스트

Audit Mode에서 최적화 스크립트를 실행한 뒤 Sysprep 전에 확인할 항목입니다.

## 1. 기본 상태

- [ ] Windows 11 설치가 정상 완료되었다.
- [ ] 현재 세션이 Audit Mode Administrator 세션이다.
- [ ] 일반 사용자 계정을 생성하지 않았다.
- [ ] 필요한 드라이버 또는 Guest Additions 설치가 완료되었다.
- [ ] 재부팅 대기 상태가 아니다.

## 2. 별도 사용자 프로필 드라이브 및 사용자 프로필 경로

- [ ] 설치 미디어 또는 게스트 도구 CD-ROM이 사용자 프로필용 드라이브 문자를 점유하지 않는다.
- [ ] 사용자 프로필용 별도 파티션/디스크가 조직 표준 드라이브 문자로 할당되어 있다.
- [ ] 별도 사용자 프로필 드라이브 아래 사용자 프로필 루트 폴더가 존재한다.
- [ ] 별도 사용자 프로필 루트 권한이 과도하게 수정되지 않았다.
- [ ] `scripts\sysprep\unattend.xml` 또는 배치된 응답 파일의 `ProfilesDirectory`가 실제 별도 사용자 프로필 드라이브 경로로 치환되어 있다.

확인 명령 예시:

```powershell
Get-Volume
Test-Path '<ProfileDrive>:\Users'
Select-String -Path 'C:\Windows\System32\Sysprep\unattend.xml' -Pattern 'ProfilesDirectory'
```

## 3. Appx 및 불필요 앱

- [ ] 제거 대상 Appx 목록을 검토했다.
- [ ] Phone Link 제거 여부를 확인했다.
- [ ] Xbox 관련 앱 제거 여부를 확인했다.
- [ ] Copilot 관련 앱 또는 정책 제한 여부를 확인했다.
- [ ] Provisioned Appx 제거 결과를 확인했다.
- [ ] 업무 앱 또는 보안 에이전트 의존성 문제가 없는지 확인했다.

확인 명령 예시:

```powershell
Get-AppxPackage -AllUsers *Xbox*
Get-AppxPackage -AllUsers *YourPhone*
Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like '*Xbox*'
```

## 4. 정책/레지스트리

- [ ] Bing/Web Search 제한 정책을 확인했다.
- [ ] Cloud Search 제한 정책을 확인했다.
- [ ] Copilot 제한 정책을 확인했다.
- [ ] Recall/AI 관련 제한 정책을 확인했다.
- [ ] Consumer Experience 제한 정책을 확인했다.
- [ ] Privacy/Telemetry 관련 정책을 확인했다.

확인 명령 예시:

```powershell
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -ErrorAction SilentlyContinue
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' -ErrorAction SilentlyContinue
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -ErrorAction SilentlyContinue
```

## 5. VM 일괄 설정

- [ ] `--standard` 또는 `--advanced` 모드에서 전원 계획/절전 타임아웃 설정을 확인했다.
- [ ] 탐색기 최근 항목/자주 쓰는 폴더/Office.com 파일 표시 제한을 확인했다.
- [ ] 시작 메뉴 추천/최근 항목 제한을 확인했다.
- [ ] Widgets/Task View/Windows 추천 알림 제한을 확인했다.
- [ ] 잠금화면 Spotlight/추천 콘텐츠 제한을 확인했다.
- [ ] 조직 GPO 또는 보안 에이전트 정책과 충돌하지 않는지 확인했다.

확인 명령 예시:

```powershell
powercfg /getactivescheme
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' -ErrorAction SilentlyContinue
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -ErrorAction SilentlyContinue
```

## 6. 서비스 및 예약 작업

- [ ] 비활성화 후보 서비스 목록을 검토했다.
- [ ] 비활성화된 서비스가 업무 앱 또는 보안 제품과 충돌하지 않는다.
- [ ] 예약 작업 비활성화 결과를 확인했다.

확인 명령 예시:

```powershell
Get-Service DiagTrack, WerSvc -ErrorAction SilentlyContinue
Get-ScheduledTask | Where-Object State -eq 'Disabled'
```

## 7. 정리 작업

- [ ] Temp/Cache 정리가 완료되었다.
- [ ] Windows Update cache 정리가 완료되었다.
- [ ] Defender Scans History 정리가 완료되었다.
- [ ] 이벤트 로그 초기화 여부를 기록했다.
- [ ] `hiberfil.sys`가 제거되었다.
- [ ] cleanmgr 실행 여부를 기록했다.
- [ ] DISM cleanup 실행 여부를 기록했다.

확인 명령 예시:

```powershell
Test-Path 'C:\hiberfil.sys'
Get-ChildItem 'C:\Windows\SoftwareDistribution\Download' -Force -ErrorAction SilentlyContinue
```

## 8. Administrator/defaultuser0

- [ ] Administrator 바탕 화면, 다운로드, 문서 폴더에 작업 파일이 남아 있지 않다.
- [ ] Administrator 임시 파일을 정리했다.
- [ ] `defaultuser0` 존재 여부를 확인했다.
- [ ] `defaultuser0` 정리 여부와 사유를 기록했다.

확인 명령 예시:

```powershell
Get-LocalUser | Where-Object Name -in @('Administrator', 'defaultuser0')
Get-ChildItem 'C:\Users' -Directory | Where-Object Name -match 'Administrator|defaultuser0'
Get-ChildItem '<ProfileDrive>:\Users' -Directory -ErrorAction SilentlyContinue
```

## 9. Sysprep 준비 상태

- [ ] `C:\Windows\System32\Sysprep\unattend.xml`이 존재한다.
- [ ] XML 파일의 `ProfilesDirectory`가 실제 별도 사용자 프로필 드라이브 경로로 치환되어 있고 `TimeZone` 값이 올바르다.
- [ ] Sysprep Panther 로그에 기존 오류가 없는지 확인했다.
- [ ] Pending reboot 상태가 아니다.
- [ ] 최종 스냅샷 또는 백업 지점을 확보했다.

## 10. 승인 기록

- [ ] 적용 모드: 
- [ ] 실행 스크립트 버전/커밋: 
- [ ] 실행 일시: 
- [ ] 작업자: 
- [ ] 검토자: 
- [ ] 특이사항: 
