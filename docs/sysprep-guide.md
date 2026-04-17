# Sysprep 및 unattend.xml 가이드

## 1. OOBE와 Audit Mode 차이

### OOBE

OOBE(Out-of-Box Experience)는 Windows 설치 후 최종 사용자가 처음 만나는 초기 설정 단계입니다. 국가, 키보드, 네트워크, 계정, 개인정보 설정 등을 구성합니다.

마스터 템플릿 작업에서는 OOBE에서 일반 사용자 계정을 만들기 전에 Audit Mode로 전환하는 것이 좋습니다.

### Audit Mode

Audit Mode는 OEM, 관리자, 이미지 담당자가 사용자 계정 생성 전 상태에서 드라이버, 앱, 정책, 업데이트, 정리 작업을 수행하기 위한 Windows 준비 모드입니다.

특징:

- 기본 Administrator 계정으로 자동 로그인
- 사용자 OOBE 진행 전 상태 유지
- Sysprep 창 자동 표시 가능
- 템플릿 최적화 및 검증 작업에 적합

## 2. Ctrl + Shift + F3 의미

OOBE 화면에서 `Ctrl + Shift + F3`을 누르면 Windows가 Audit Mode로 재부팅됩니다. 이 방식은 일반 사용자 프로필 생성 전 템플릿 작업을 수행할 수 있게 해줍니다.

주의사항:

- OOBE에서 개인 사용자 계정을 먼저 만들면 해당 프로필이 이미지에 남을 수 있습니다.
- Audit Mode에서는 Administrator 프로필이 사용되므로 최종 이미지에 불필요한 흔적이 남지 않도록 정리해야 합니다.

## 3. Sysprep 명령 사용법

권장 명령:

```cmd
C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /unattend:C:\Windows\System32\Sysprep\unattend.xml
```

옵션 설명:

- `/generalize`: 시스템 고유 식별자, 장치별 정보, 일부 로그와 캐시를 일반화합니다.
- `/oobe`: 다음 부팅 시 최종 사용자 초기 설정 화면으로 진입합니다.
- `/shutdown`: Sysprep 완료 후 시스템을 종료합니다.
- `/unattend:<path>`: 응답 파일을 지정합니다.

운영 원칙:

1. Sysprep 전에는 스냅샷 또는 디스크 복제 지점을 확보합니다.
2. Sysprep 실패 시 `C:\Windows\System32\Sysprep\Panther` 로그를 확인합니다.
3. Sysprep 성공 후 종료된 원본 VM은 다시 부팅하지 않습니다.

## 4. ProfilesDirectory를 별도 사용자 프로필 드라이브로 지정하는 목적

`unattend.xml`의 `Microsoft-Windows-Shell-Setup` 구성에서 `FolderLocations/ProfilesDirectory`를 OS 드라이브가 아닌 별도 사용자 프로필 드라이브의 사용자 폴더로 지정하면, OOBE 이후 생성되는 사용자 프로필이 해당 별도 드라이브 아래에 생성됩니다.

목적:

- OS 영역과 사용자 데이터 영역 분리
- 템플릿 재배포 시 사용자 데이터 관리 기준 명확화
- C 드라이브 용량 증가 억제
- 공공기관/망분리 환경에서 사용자 데이터 백업/감사 경로 단순화

예시:

```xml
<FolderLocations>
  <ProfilesDirectory>&lt;ProfileDrive&gt;:\Users</ProfilesDirectory>
</FolderLocations>
```

중요:

- 이 설정은 일반화된 이미지가 OOBE로 들어가기 전에 적용되어야 합니다.
- 이미 생성된 기존 프로필을 자동으로 이동하는 기능이 아닙니다.
- 지정한 별도 사용자 프로필 드라이브가 OOBE 시점에도 안정적으로 존재해야 합니다.

## 5. 기존 ProfileList 강제 수정 방식이 비권장인 이유

일부 환경에서는 다음 레지스트리를 직접 수정해 프로필 경로를 바꾸려는 시도가 있습니다.

```text
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList
```

이 방식은 비권장입니다.

이유:

1. 이미 생성된 프로필의 파일, 권한, 앱 데이터, 레지스트리 하이브가 복잡하게 연결되어 있습니다.
2. Store 앱, UWP/Appx, Edge WebView, 검색 인덱스 등 사용자별 구성요소가 경로 변경에 취약할 수 있습니다.
3. Windows 업데이트 또는 기능 업데이트 중 경로 불일치 문제가 발생할 수 있습니다.
4. Sysprep 호환성이 떨어지고 예측하기 어려운 오류가 발생할 수 있습니다.
5. 조직 운영 중 장애 발생 시 원인 분석이 어렵습니다.

권장 방식은 Sysprep 응답 파일에서 `ProfilesDirectory`를 지정하고, 사용자 프로필이 처음 생성될 때 올바른 위치에 만들어지게 하는 것입니다.

## 6. Administrator 정리 시 주의사항

Audit Mode에서는 Administrator 계정이 사용됩니다. 이 계정과 프로필 폴더는 템플릿 작업 흔적을 포함할 수 있습니다.

주의사항:

- Sysprep 전 Administrator 바탕 화면, 다운로드, 임시 폴더를 정리합니다.
- 운영에 필요한 파일을 Administrator 프로필에 두지 않습니다.
- Administrator 계정 사용 여부와 비밀번호 정책은 조직 기준에 따릅니다.
- 계정 비활성화 여부는 배포 후 관리 정책과 충돌하지 않도록 결정합니다.

## 7. defaultuser0 정리 시 주의사항

`defaultuser0`는 OOBE 또는 Sysprep 과정에서 임시로 생성될 수 있는 계정/프로필입니다.

주의사항:

- 정상 OOBE 완료 후 남아 있으면 정리 대상이 될 수 있습니다.
- Sysprep 전 무리하게 삭제하면 OOBE 상태나 프로필 준비 과정에 영향을 줄 수 있습니다.
- 계정과 프로필 폴더를 삭제할 때는 실제 사용자가 아닌지 확인합니다.
- 삭제가 필요한 경우 복제 VM에서 절차를 검증하고 변경 이력에 기록합니다.

## 8. Sysprep 실패 시 확인 위치

- `C:\Windows\System32\Sysprep\Panther\setuperr.log`
- `C:\Windows\System32\Sysprep\Panther\setupact.log`
- `C:\Windows\Panther\setuperr.log`
- `C:\Windows\Panther\setupact.log`

자주 확인할 항목:

- Appx 패키지 provision 상태 불일치
- 사용자가 설치한 Store 앱 잔여
- 업데이트 pending 상태
- 재부팅 필요 상태
- 응답 파일 XML 오류
- 별도 사용자 프로필 드라이브 또는 사용자 프로필 루트 폴더 접근 오류
