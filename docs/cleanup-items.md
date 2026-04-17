# 정리 대상 항목 목록

이 문서는 Windows 11 VM 마스터 템플릿 종료 전 정리할 수 있는 주요 경로와 주의사항을 정리합니다. 모든 항목은 조직 정책과 감사 요구사항을 우선하여 적용해야 합니다.

| 경로/항목 | 역할 | 삭제 가능 여부 | 주의사항 |
| --- | --- | --- | --- |
| `C:\Windows\Temp` | 시스템 전체 임시 파일 저장 위치 | 일반적으로 가능 | 실행 중인 설치 프로그램이나 업데이트 작업이 있으면 일부 파일 삭제 실패 가능 |
| `%TEMP%`, `%TMP%` | 현재 사용자 임시 파일 | 가능 | Audit Mode Administrator 세션 기준 임시 파일만 정리될 수 있음 |
| `C:\Users\*\AppData\Local\Temp` | 사용자별 임시 파일 | 가능 | 실제 사용자 프로필이 생성된 뒤에는 사용자별 앱 세션 파일이 포함될 수 있음 |
| `C:\Windows\SoftwareDistribution\Download` | Windows Update 다운로드 캐시 | 가능 | 업데이트 설치 중에는 삭제 금지. `wuauserv`, `bits` 중지 후 정리 권장 |
| `C:\Windows\SoftwareDistribution\DataStore\Logs` | Windows Update 데이터 저장소 로그 | 제한적 가능 | 업데이트 문제 분석이 필요한 경우 보존 필요 |
| `C:\Windows\Panther` | Windows 설치 및 Sysprep 로그 | 조건부 가능 | Sysprep 실패 분석에 필요하므로 최종 성공 확인 전 삭제 금지 |
| `C:\Windows\System32\Sysprep\Panther` | Sysprep 실행 로그 | 조건부 가능 | Sysprep 실패 원인 분석의 핵심 위치. 최종 템플릿 전 보존 여부 결정 필요 |
| `C:\Windows\Logs\DISM` | DISM 작업 로그 | 조건부 가능 | DISM cleanup 실패 분석이 필요하면 보존 |
| `C:\Windows\Logs\CBS` | Component Based Servicing 로그 | 조건부 가능 | Windows Update/구성요소 문제 분석이 필요하면 보존 |
| `C:\ProgramData\Microsoft\Windows Defender\Scans\History` | Defender 검사 기록 | 가능 | 보안 감사상 검사 이력 보존이 필요한 단계에서는 삭제 시점 기록 필요 |
| `C:\ProgramData\Microsoft\Windows\WER` | Windows Error Reporting 자료 | 가능 | 장애 분석이 끝난 뒤 정리 권장 |
| `C:\Users\*\AppData\Local\Microsoft\Windows\INetCache` | 웹/인터넷 캐시 | 가능 | Edge/IE 모드 테스트 흔적이 포함될 수 있음 |
| `C:\Users\*\AppData\Local\Microsoft\Windows\WebCache` | 웹 캐시 데이터베이스 | 가능 | 실행 중인 브라우저/웹뷰 프로세스가 있으면 잠김 가능 |
| `C:\Users\*\AppData\Local\CrashDumps` | 사용자별 크래시 덤프 | 가능 | 장애 분석이 끝난 뒤 삭제 |
| `C:\Windows\Minidump` | 시스템 미니덤프 | 가능 | BSOD 분석이 필요한 경우 보존 |
| `C:\Windows\Memory.dmp` | 전체 메모리 덤프 | 가능 | 대용량 파일. 장애 분석 완료 후 삭제 |
| 이벤트 로그 | 시스템/응용 프로그램/보안 이벤트 저장소 | 조건부 가능 | 감사 대응상 보존 필요 여부 확인. 마스터 템플릿 최종화 직전에만 초기화 권장 |
| 휴지통 | 삭제된 파일 임시 보관 | 가능 | 모든 드라이브의 휴지통을 정리해야 용량 감소 효과가 있음 |
| `hiberfil.sys` | 최대 절전 파일 | 가능 | `powercfg /hibernate off`로 제거. Fast Startup 영향 검토 필요 |
| `pagefile.sys` | 페이지 파일 | 비권장/옵션 | 장애 덤프 및 메모리 압박 대응에 필요할 수 있어 기본 비활성화 금지 |
| `C:\Windows\Prefetch` | 실행 파일 프리페치 캐시 | 조건부 가능 | 성능 최적화 캐시이므로 무조건 삭제는 권장하지 않음 |
| `C:\ProgramData\Package Cache` | 설치 패키지 캐시 | 비권장 | MSI/Visual Studio/런타임 복구에 필요할 수 있음 |

## 운영 원칙

1. 정리 작업은 Sysprep 직전 1회 수행을 원칙으로 합니다.
2. 업데이트, 드라이버 설치, 보안 제품 설치가 진행 중일 때는 캐시를 삭제하지 않습니다.
3. 감사 또는 장애 분석에 필요한 로그는 삭제 전에 보존 여부를 결정합니다.
4. 스크립트로 삭제 실패가 발생해도 전체 작업이 중단되지 않도록 설계합니다.
5. 삭제 항목과 실행 시점을 변경 이력에 기록합니다.
