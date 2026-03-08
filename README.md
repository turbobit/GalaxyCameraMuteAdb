# GalaxyCameraMuteAdb

<details open>
<summary><strong>English</strong></summary>

GalaxyCameraMuteAdb is a small Go CLI that lists USB-connected Android devices and sends only this ADB command to the selected device:

```bash
adb shell settings put system csc_pref_camera_forced_shuttersound_key 0
```

At runtime, the tool applies the command to the selected device by using `-s <serial>`.

## Requirements

- Go 1.25+
- Android Platform Tools
- USB debugging enabled on the phone

ADB lookup order:

1. `adb` from PATH
2. `ADB_PATH` environment variable
3. `platform-tools\adb.exe` inside the project folder
4. Common Windows Android SDK locations

Official download:

```text
https://developer.android.com/tools/releases/platform-tools
```

## Run

```bat
run.cmd
```

You can also run:

```bash
go run .
```

The current version is read from the root `VERSION` file and shown at startup.

Flow:

1. Run `adb devices -l`
2. Keep only devices in `device` state
3. Let the user choose a device
4. Read the current setting value
5. Send the `settings put` command
6. Read the setting again and print success/failure

Patch flow:

```mermaid
flowchart TD
    A[GalaxyCameraMuteAdb Go CLI] -->|1. Find adb| B[adb.exe]
    B -->|PATH / ADB_PATH / local platform-tools| C[adb devices -l]
    C -->|2. Filter device state| D[USB connected device]
    D -->|3. Select device| E[settings get system<br/>csc_pref_camera_forced_shuttersound_key]
    E -->|4. Print current value| F[adb shell settings put system<br/>csc_pref_camera_forced_shuttersound_key 0]
    F -->|5. Check command result| G[settings get system<br/>csc_pref_camera_forced_shuttersound_key]
    G -->|6. Verify final value| H[Result output<br/>- command success/failure<br/>- before/after value<br/>- state change]
```

You can also place ADB directly in the project folder:

```text
platform-tools\adb.exe
```

## Build

```bat
build.cmd
```

`build.cmd` creates the `release` folder and outputs a versioned executable like this:

```text
release\GalaxyCameraMuteAdb_v0.1.0.exe
```

## Release

```bat
release.cmd
```

Release flow:

1. Remove existing files in the `release` folder
2. Build a fresh executable with `build.cmd`
3. Stage all changes with `git add -A`
4. Commit with message `release: v<version>`
5. Push the current branch to `origin`
6. Create the version tag if missing, or force-update it to current `HEAD`
7. Generate release notes from the previous tag to the current commit
8. Create or update the GitHub Release
9. Upload `release\GalaxyCameraMuteAdb_v<version>.exe`

Local dry run without remote publish:

```bat
release.cmd -SkipPublish
```

## Notes

- If `adb` is not found, the app prints download/setup guidance.
- Devices in `offline` or `unauthorized` state are not selectable.
- If no usable device is found, the app prints guidance for Developer Mode and USB debugging.

</details>

<details>
<summary><strong>한국어</strong></summary>

GalaxyCameraMuteAdb는 USB로 연결된 Android 장비를 조회하고, 선택한 장비에 아래 ADB 명령만 실행하는 간단한 Go CLI입니다.

```bash
adb shell settings put system csc_pref_camera_forced_shuttersound_key 0
```

실행 시에는 `-s <serial>` 옵션을 사용해서 선택한 장비에만 적용합니다.

## 요구 사항

- Go 1.25+
- Android Platform Tools
- 휴대폰에서 USB 디버깅 활성화

ADB 탐색 순서:

1. PATH의 `adb`
2. `ADB_PATH` 환경변수
3. 프로젝트 폴더 내부 `platform-tools\adb.exe`
4. Windows의 일반적인 Android SDK 경로

공식 다운로드:

```text
https://developer.android.com/tools/releases/platform-tools
```

## 실행

```bat
run.cmd
```

또는:

```bash
go run .
```

현재 버전은 루트의 `VERSION` 파일에서 읽어 시작 시 출력합니다.

동작 흐름:

1. `adb devices -l` 실행
2. `device` 상태 장비만 필터링
3. 사용자에게 장비 선택 받음
4. 현재 설정값 조회
5. `settings put` 명령 전송
6. 다시 설정값을 읽어 성공/실패 출력

패치 구조:

```mermaid
flowchart TD
    A[GalaxyCameraMuteAdb Go CLI] -->|1. adb 탐색| B[adb.exe]
    B -->|PATH / ADB_PATH / local platform-tools| C[adb devices -l]
    C -->|2. device 상태만 필터| D[USB 연결 장비]
    D -->|3. 장비 선택| E[settings get system<br/>csc_pref_camera_forced_shuttersound_key]
    E -->|4. 현재 값 출력| F[adb shell settings put system<br/>csc_pref_camera_forced_shuttersound_key 0]
    F -->|5. 명령 결과 확인| G[settings get system<br/>csc_pref_camera_forced_shuttersound_key]
    G -->|6. 최종 값 검증| H[결과 출력<br/>- 명령 성공/실패<br/>- 전/후 값<br/>- 상태 변화]
```

프로젝트 폴더에 ADB를 직접 둘 수도 있습니다.

```text
platform-tools\adb.exe
```

## 빌드

```bat
build.cmd
```

`build.cmd`는 `release` 폴더를 만들고, 아래처럼 버전이 포함된 실행 파일을 생성합니다.

```text
release\GalaxyCameraMuteAdb_v0.1.0.exe
```

## 릴리즈

```bat
release.cmd
```

릴리즈 흐름:

1. `release` 폴더의 기존 파일 삭제
2. `build.cmd`로 새 실행 파일 빌드
3. 변경 파일 전체를 `git add -A`
4. `release: v<version>` 메시지로 커밋
5. 현재 브랜치를 `origin`에 푸시
6. 버전 태그가 없으면 생성하고, 있으면 현재 `HEAD`로 강제 업데이트
7. 이전 태그부터 현재 커밋까지 릴리즈 노트 생성
8. GitHub Release 생성 또는 업데이트
9. `release\GalaxyCameraMuteAdb_v<version>.exe` 업로드

원격 반영 없이 로컬에서만 확인하려면:

```bat
release.cmd -SkipPublish
```

## 참고

- `adb`를 찾지 못하면 다운로드/설치 안내를 출력합니다.
- `offline`, `unauthorized` 상태 장비는 선택 목록에서 제외됩니다.
- 사용 가능한 장비가 없으면 개발자 모드와 USB 디버깅 확인 안내를 출력합니다.

</details>
