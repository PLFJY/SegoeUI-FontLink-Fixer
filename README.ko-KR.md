# SegoeUI-FontLink-Fixer

[简体中文](README.md) / [日本語](README.ja-JP.md) / 한국어 / [English](README.en-US.md)

> [!WARNING]
> 이 프로젝트의 코드 상당 부분은 AI의 도움으로 생성되었고, 이후에도 지속적인 수작업 조정, 통합 점검, 리팩터링을 거쳤지만, 여전히 누락, 경계 조건 처리 부족, 또는 기대와 완전히 일치하지 않는 동작이 남아 있을 수 있습니다.
> 사용 중 버그, 호환성 문제, 비정상 동작, 문서 누락을 발견하면 Issue 제보를 환영합니다. 가능하면 재현 절차, 로그, 스크린샷, 운영체제 버전 정보를 함께 남겨 주세요. 큰 도움이 됩니다.

`SegoeUI-FontLink-Fixer` 는 Windows FontLink 레지스트리 매핑을 점검, 백업, 미리보기, 적용, 검증, 복원하기 위한 보수적이고 안전 우선의 PowerShell 도구입니다.

대상 레지스트리 경로:

`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink`

기본 CJK fallback 순서가 원하는 동작과 맞지 않을 때, `Segoe UI*`, `Tahoma`, `Microsoft Sans Serif` 의 fallback 우선순서를 조정하는 것이 주된 용도입니다.

## 도구 개요

이 도구는 FontLink 목록을 새로 만들지 않습니다. 대신 안정적인 재정렬 방식을 사용합니다.

- 대상 언어 글꼴만 앞으로 이동
- 관련 없는 항목의 상대 순서는 유지
- 현재 값에 없는 항목은 새로 만들지 않음

즉, 공격적인 재구성이 아니라 기존 순서 보정용 도구입니다.

## 안전 경고

이 프로젝트는 `HKLM` 아래의 시스템 레지스트리를 수정합니다. 민감한 설정입니다.

`apply` 또는 `restore` 를 사용하기 전에 스크립트와 복구 경로를 확인하세요.

현재 구현된 주요 안전 장치:

- 쓰기 전에 반드시 백업을 완료
- 백업 실패 후에는 계속 진행하지 않음
- `apply` 후 다시 읽어서 검증하고, 검증 실패 시 성공으로 표시하지 않음
- `restore` 는 백업 검증 후 복원 전 안전 백업을 추가로 만들고, 복원 후 다시 검증함
- 불완전한 백업은 명시적으로 표시되며 복원에 사용할 수 없음

위 설계는 위험을 낮추지만 제거하지는 못합니다.

## 기능

- `SystemLink` 키 전체 백업
- `.reg` 와 JSON 스냅샷 동시 저장
- 해시, 타임스탬프, 값 목록이 포함된 `manifest.json` 생성
- `Segoe UI` 로 시작하는 모든 값 자동 처리
- `Tahoma`, `Microsoft Sans Serif` 도 함께 처리
- `zh-CN`, `zh-TW`, `ja-JP`, `ko-KR` 지원
- dry-run / 미리보기 지원
- 최신 유효 백업 또는 지정 경로 백업에서 복원 가능
- 로컬 키보드 기반 TUI 제공
- UI 언어:
  `zh-CN`, `ja-JP`, `ko-KR`, `en-US`

## 요구 사항

- Windows
- PowerShell 5.1 이상
- `apply` / `restore` 에는 관리자 권한 필요

## 빠른 시작

TUI 실행:

```powershell
.\SegoeLinker.ps1
```

명시적으로 실행:

```powershell
.\SegoeLinker.ps1 tui
```

미리보기 실행:

```powershell
.\SegoeLinker.ps1 apply zh-CN --dry-run
```

수동 백업 생성:

```powershell
.\SegoeLinker.ps1 backup
```

최신 유효 백업 복원:

```powershell
.\SegoeLinker.ps1 restore --latest
```

## TUI

`.\SegoeLinker.ps1` 를 실행하면 로컬 TUI 가 열립니다.

TUI 는 사람이 사용하는 주 인터페이스로 설계되었습니다.

- 메인 메뉴는 단일 키 입력으로 동작
- 프로필 선택도 단일 키 입력
- 언어 선택도 단일 키 입력
- 백업 경로처럼 텍스트가 필요한 경우에만 입력창 사용

선택한 UI 언어는 다음 로컬 설정 파일에 저장됩니다.

- `.segoelinker.user.json`

이 파일은 프로젝트 루트에 저장되며 Git 에서 무시됩니다.

## UI 언어

TUI 안에서 변경할 수도 있고, 명령줄에서 `--lang` 를 사용할 수도 있습니다.

명령줄에 `--lang` 이 없으면, 로컬에 저장된 UI 언어 설정을 우선 사용합니다.

예시:

```powershell
.\SegoeLinker.ps1 list --lang zh-CN
.\SegoeLinker.ps1 status --lang ja-JP
.\SegoeLinker.ps1 backup --lang ko-KR
.\SegoeLinker.ps1 tui --lang en-US
```

지원 언어 ID:

- `zh-CN`
- `ja-JP`
- `ko-KR`
- `en-US`

## 명령

```powershell
.\SegoeLinker.ps1
.\SegoeLinker.ps1 tui
.\SegoeLinker.ps1 backup
.\SegoeLinker.ps1 apply zh-CN
.\SegoeLinker.ps1 apply ja-JP --dry-run
.\SegoeLinker.ps1 restore --latest
.\SegoeLinker.ps1 restore --file .\backups\20260420-120000123
.\SegoeLinker.ps1 list
.\SegoeLinker.ps1 status
.\SegoeLinker.ps1 help
```

## 지원 프로필

- `zh-CN`: `Microsoft YaHei UI`, `Microsoft YaHei`
- `zh-TW`: `Microsoft JhengHei UI`, `Microsoft JhengHei`
- `ja-JP`: `Yu Gothic UI`, `Yu Gothic`, `Meiryo UI`, `Meiryo`
- `ko-KR`: `Malgun Gothic`

동작은 의도적으로 보수적입니다.

- 현재 값에 이미 존재하는 대상 항목만 이동
- 관련 없는 항목의 상대 순서는 유지
- 없는 글꼴 항목은 자동 추가하지 않음

추가 설명:

- `Segoe UI*`, `Tahoma`, `Microsoft Sans Serif` 는 모두 같은 안정 재정렬 모델을 사용합니다
- 현재 값에 있는 항목만 앞으로 이동합니다
- `,128,96` 이 없는 값에 대해 `,128,96` 항목을 새로 만들지 않습니다

## 백업 형식

각 백업은 [backups](./backups) 아래의 타임스탬프 디렉터리에 저장됩니다.

완전한 백업에는 다음이 포함됩니다.

- `SystemLink.reg`
  수동 점검과 수동 가져오기를 위한 전체 `reg.exe export`
- `SystemLink.snapshot.json`
  정확한 복원 로직을 위한 구조화된 스냅샷
- `manifest.json`
  schema 버전, 타임스탬프, 해시, 레지스트리 경로, 값 목록

백업 진행 중에는 `backup.incomplete.txt` 가 생성됩니다. 중간에 실패한 백업은 의도적으로 복원 불가 상태로 남깁니다.

## 복원 모델

`restore` 는 명확하고 보수적이며 검증 가능한 흐름을 목표로 합니다.

처리 순서:

1. `--latest` 또는 `--file` 로 대상 백업 선택
2. manifest, 필수 파일, schema 버전, 대상 레지스트리, 해시 검증
3. 현재 상태의 안전 백업 추가 생성
4. `SystemLink` 전체 스냅샷을 정확히 복원
5. 복원 후 상태를 다시 읽어 일치 여부 검증

복원은 `SystemLink` 키 전체 단위의 정확 복원입니다.

- 백업에 있는 값은 복원
- 현재는 있지만 백업에는 없는 값은 삭제

이 용도에서는 부분 병합 복원이 더 위험할 수 있으므로 이 방식을 사용합니다.

## 권한 상승

`apply` 와 `restore` 는 `HKLM` 에 쓰기 때문에 관리자 권한이 필요합니다.

쓰기 전에 권한 상태를 확인하고, 필요하면 관리자 권한으로 다시 실행한 뒤 실제 쓰기 작업으로 들어갑니다.

권한 상승 시 인자 전달은 취약한 문자열 이어붙이기가 아니라 인코딩된 payload 를 사용하므로, 공백 경로, 따옴표, Unicode 인자에 더 안전합니다.

기본적으로 강제 상승하지 않는 명령:

- `backup`
- `list`
- `status`
- `apply --dry-run`
- `tui`

TUI 안의 쓰기 작업도 같은 안전 경로를 사용합니다.

## 출력 및 검증

도구는 다음 정보를 명확하게 표시합니다.

- 권한 상태
- 백업 위치
- 관리 대상 값
- 변경 전/후 순서 차이
- 복원 시 선택된 백업
- 검증 성공 / 실패
- 로그오프 / 재부팅 필요 가능성

`apply` 또는 `restore` 의 최종 검증이 실패하면 성공으로 표시하지 않습니다.

## 실행 중단 조건 예시

- 잘못된 프로필 ID
- `--file` 경로 누락
- 잘못된 백업 선택
- 불완전 백업 마커 존재
- manifest, snapshot, `.reg` 파일 누락
- 백업 해시 불일치
- 백업 대상 레지스트리 불일치
- 복원 스냅샷에 지원하지 않는 값 형식 포함
- 대상 값이 `MultiString` 이 아님
- 쓰기 후 검증 불일치

## 참고

- `status` 는 `Segoe UI*`, `Tahoma`, `Microsoft Sans Serif` 와 최신 유효 백업을 보여줍니다
- `list` 는 지원 프로필과 우선 글꼴을 보여줍니다
- TUI 는 선택한 UI 언어를 `.segoelinker.user.json` 에 저장합니다
- 변경 사항 적용에는 로그오프, 재부팅 또는 관련 앱 재시작이 필요할 수 있습니다
- `backups/` 는 `.gitkeep` 를 제외하고 Git 에서 무시됩니다
- `.segoelinker.user.json` 은 Git 에서 무시됩니다

## 제한 사항

- 기존 항목의 순서만 조정하며, 누락된 FontLink 데이터는 생성하지 않습니다
- `apply` 가 중간에 실패해도 사전 백업은 남지만, 롤백은 별도 작업입니다
- TUI 는 로컬 대화형 콘솔용이며 무인 자동화용이 아닙니다
- 즉시 키 입력을 지원하지 않는 환경에서는 줄 입력 호환 모드로 전환됩니다

## 면책

이 프로젝트는 최대한 신중하게 설계되었지만, 여전히 민감한 시스템 레지스트리를 수정합니다. 코드와 복구 절차를 이해한 뒤 사용하세요.
