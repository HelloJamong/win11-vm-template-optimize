# 빌드 후 검증 체크리스트

Sysprep 종료 후 복제본 또는 템플릿에서 최초 부팅/OOBE/압축 결과를 검증하는 체크리스트입니다.

## 1. Sysprep 및 OOBE

- [ ] Sysprep이 오류 없이 종료되었다.
- [ ] VM이 자동 종료되었다.
- [ ] 원본 VM을 재부팅하지 않고 복제본으로 검증했다.
- [ ] 복제본 부팅 시 OOBE가 정상 표시되었다.
- [ ] OOBE 완료 후 로그인할 수 있다.

## 2. 사용자 프로필 위치

- [ ] 신규 사용자 `%USERPROFILE%`이 OS 드라이브가 아닌 별도 사용자 프로필 드라이브 아래 경로이다.
- [ ] `C:\Users`에 불필요한 신규 사용자 프로필이 생성되지 않았다.
- [ ] 별도 사용자 프로필 루트 권한이 정상이다.
- [ ] 사용자 로그인/로그오프가 정상 동작한다.

확인 명령 예시:

```cmd
echo %USERPROFILE%
```

```powershell
[Environment]::GetFolderPath('UserProfile')
Get-ChildItem '<ProfileDrive>:\Users' -Directory
```

## 3. 앱 제거 및 정책 적용

- [ ] unwanted Appx 제거 여부를 확인했다.
- [ ] Provisioned Appx 제거 여부를 확인했다.
- [ ] Copilot 제거 또는 정책 제한 여부를 확인했다.
- [ ] Phone Link 제거 여부를 확인했다.
- [ ] Xbox 관련 앱 제거 여부를 확인했다.
- [ ] Search/Bing/Cloud Search 제한 정책이 적용되어 있다.
- [ ] Consumer/privacy 정책이 적용되어 있다.

## 4. 정리 결과

- [ ] 이벤트 로그 초기화 여부를 기록했다.
- [ ] `hiberfil.sys`가 존재하지 않는다.
- [ ] Windows Update cache가 과도하게 남아 있지 않다.
- [ ] Defender scan history 정리 결과를 확인했다.
- [ ] 임시 폴더에 작업 파일이 남아 있지 않다.

## 5. Administrator/defaultuser0 잔여 여부

- [ ] Administrator 프로필에 작업 파일이 남아 있지 않다.
- [ ] Administrator 계정 상태가 조직 정책에 부합한다.
- [ ] `defaultuser0` 계정이 불필요하게 남아 있지 않다.
- [ ] `defaultuser0` 프로필 폴더가 불필요하게 남아 있지 않다.

## 6. 기능 회귀 검증

- [ ] 시작 메뉴가 정상 동작한다.
- [ ] 파일 탐색기가 정상 동작한다.
- [ ] Windows 설정 앱이 정상 동작한다.
- [ ] 네트워크 설정이 정상 동작한다.
- [ ] Windows Update 정책이 조직 기준에 맞게 동작한다.
- [ ] 보안 에이전트 또는 백신이 정상 동작한다.
- [ ] 업무 필수 앱 설치/실행이 정상이다.

## 7. VHD 후처리 및 압축 결과

- [ ] 종료된 원본 디스크를 안전하게 복제했다.
- [ ] 필요 시 영공간 정리를 별도 절차로 수행했다.
- [ ] 필요 시 VM 디스크 compact를 별도 절차로 수행했다.
- [ ] `compack.bat`로 `.pck` 압축 파일을 생성했다.
- [ ] 압축 파일 크기를 기록했다.
- [ ] `extract.bat`로 압축 해제를 검증했다.
- [ ] 복원된 VHD/VHDX 파일 해시 또는 크기를 확인했다.

## 8. 최종 기록

- [ ] 템플릿 이름: 
- [ ] Windows 버전/빌드: 
- [ ] 적용 모드: 
- [ ] 스크립트 버전/커밋: 
- [ ] Sysprep 일시: 
- [ ] 압축 파일명: 
- [ ] 압축 파일 크기: 
- [ ] 보관 위치: 
- [ ] 검증자: 
- [ ] 승인자: 
- [ ] 특이사항: 
