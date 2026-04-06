# FindKey

FindKey는 **GitHub 조직/사용자 저장소를 한 번에 조회하고, Gitleaks + TruffleHog로 비밀값 노출 여부를 검사하는 macOS AppKit 데스크탑 앱**입니다. 사용자는 GitHub 저장소 목록 URL을 입력하고, 앱은 저장소를 자동으로 나열한 뒤 각 저장소를 임시 워크스페이스에 clone하여 스캔 결과를 한 화면에서 보여줍니다.

## 어떤 문제를 해결하나요?

조직이나 개인 계정에 저장소가 많아질수록, API 키나 토큰이 커밋 히스토리에 섞여 들어갔는지 수동으로 점검하기가 어려워집니다. FindKey는 이 작업을 macOS 데스크탑 앱 워크플로우로 묶어서, 방어적 목적의 반복 점검을 더 쉽게 수행하도록 돕습니다.

## 핵심 기능

- 다음과 같은 GitHub URL 입력 지원
  - `https://github.com/orgs/bssm-oss/repositories`
  - `https://github.com/heodongun?tab=repositories`
  - `https://github.com/<owner>`
- GitHub REST API를 사용한 저장소 목록 조회
- 선택적 GitHub 토큰 지원
  - rate limit 완화
  - private repository 접근 보조
- 각 저장소를 임시 디렉터리에 clone 후 다음 도구로 검사
  - `gitleaks git`
  - `trufflehog git --json --no-verification`
- findings 표와 raw report 뷰를 함께 제공하는 AppKit UI
- 태그 푸시 시 unsigned `.dmg`를 GitHub Release에 업로드하는 워크플로우
- Homebrew Cask 제공
  - FindKey 설치 시 `gitleaks`, `trufflehog`도 Homebrew 의존성으로 함께 설치되도록 구성
- 내장 contract test 모드 제공

## 기술 스택

- Swift 6.1+
- AppKit
- Swift Package Manager
- GitHub Actions
- Homebrew Cask

## 요구 사항

- macOS 13+
- Xcode Command Line Tools 또는 Xcode 15+
- Homebrew

## 로컬 개발

### 빌드

```bash
swift build
```

### 앱 실행

```bash
swift run FindKey
```

### Contract Test 실행

```bash
swift run FindKey -- --self-test
```

이 테스트는 UI 자동화가 아니라, URL 파싱 / GitHub owner resolution / finding parser 동작 같은 핵심 로직을 반복 가능하게 검증합니다.

## 패키징

### unsigned `.app` 생성

```bash
bash scripts/build-app.sh 0.1.0
```

생성 결과:

- `dist/FindKey.app`

### unsigned `.dmg` 생성

```bash
bash scripts/build-dmg.sh 0.1.0
```

생성 결과:

- `dist/FindKey-0.1.0.dmg`
- `dist/FindKey.dmg`

`FindKey.dmg`는 Homebrew Cask가 `releases/latest/download/FindKey.dmg` 경로로 접근할 수 있도록 유지되는 stable alias입니다.

## Homebrew로 설치하기

### 이 저장소를 로컬 tap으로 검증하기

```bash
brew tap bssm-oss/findkey "$(pwd)"
brew info --cask bssm-oss/findkey/findkey
```

이 경로는 **cask 메타데이터와 tap 구성이 올바른지 확인하는 용도**입니다.

### GitHub Release가 존재할 때 실제 설치하기

```bash
brew tap bssm-oss/findkey https://github.com/bssm-oss/findkey
brew install --cask bssm-oss/findkey/findkey
```

이 설치 경로는 다음을 전제로 합니다.

1. 저장소에 usable default branch가 있어야 함
2. 첫 tagged release가 생성되어 있어야 함
3. release asset으로 `FindKey.dmg`가 게시되어 있어야 함

FindKey Cask는 다음 Homebrew formula를 의존성으로 선언합니다.

- `gitleaks`
- `trufflehog`

즉, `brew install --cask bssm-oss/findkey/findkey`를 수행하면 FindKey 앱 설치와 함께 두 스캐너도 Homebrew가 알아서 설치합니다.

## GitHub 토큰 동작 방식

- 토큰 입력은 선택 사항입니다.
- GitHub API 요청에 사용됩니다.
- clone 시에는 URL에 토큰을 박아 넣지 않고, 임시 git environment config로 Authorization 헤더를 주입합니다.
- 토큰은 디스크에 저장하지 않습니다.

## 스캔 동작 방식

1. 입력 URL을 organization / user / owner 대상으로 파싱
2. GitHub REST API로 저장소 목록 조회
3. 각 저장소를 임시 workspace에 clone
4. Gitleaks와 TruffleHog 실행
5. findings를 공통 형식으로 정규화
6. sanitized raw JSON/NDJSON을 raw report 뷰에 표시
7. 스캔 종료 후 임시 workspace 삭제 시도

## 폴더 구조

```text
.
├── .github/workflows/
├── Casks/
├── docs/
│   ├── architecture/
│   ├── changes/
│   └── testing/
├── scripts/
└── Sources/FindKey/
    ├── App/
    ├── Application/
    ├── Domain/
    ├── Infrastructure/
    ├── SelfTest/
    └── Shared/
```

## 아키텍처 개요

- **App**
  - `AppDelegate`
  - `MainWindowController`
  - `AppController`
  - `Theme`
  - `LogoMarkView`
- **Application**
  - `ScanOrchestrator`
- **Domain**
  - `GitHubTarget`
  - `RepositoryRecord`
  - `ScanFinding`
  - `RawReport`
- **Infrastructure**
  - `GitHubURLParser`
  - `GitHubRepositoryService`
  - `ExternalToolLocator`
  - `ProcessRunner`
  - `RepositoryCloneService`
  - `GitleaksRunner`
  - `TruffleHogRunner`
  - `TemporaryWorkspace`
- **SelfTest**
  - `ContractTestRunner`

더 자세한 구조는 `docs/architecture/findkey-architecture.md`에 정리되어 있습니다.

## 개발 원칙

- 기능 외 범위로 불필요하게 리팩터링하지 않기
- 비밀값을 로그나 파일에 저장하지 않기
- 가능한 경우 raw report는 redacted/sanitized 상태로만 보이게 유지하기
- 문서와 실제 동작을 항상 맞추기
- 누락된 도구나 자격 증명은 숨기지 않고 명시적으로 오류로 드러내기

## CI / Release

- `ci.yml`
  - `swift build`
  - `swift run FindKey -- --self-test`
  - unsigned `.app` 생성 검증
  - unsigned `.dmg` 생성 검증
- `release.yml`
  - `v*` 태그 푸시 시 실행
  - build + self-test 실행
  - versioned DMG와 stable alias DMG 생성
  - GitHub Release에 `dist/*.dmg` 업로드

즉, 버전 태그를 올릴 때마다 release asset이 갱신되도록 구성되어 있습니다.

## 알려진 제한 사항

- 릴리즈는 **unsigned / not notarized** 상태입니다.
- Gatekeeper 경고가 발생할 수 있습니다.
- TruffleHog는 `--no-verification` 모드로 실행됩니다.
- 현재는 저장소 git history/content만 검사합니다.
  - issue
  - PR comment
  - discussion
  - wiki
  - 삭제된 외부 표면
  등은 검사하지 않습니다.
- Homebrew 실제 설치는 첫 release asset이 게시된 뒤에만 동작합니다.

## 향후 개선 아이디어

- signed / notarized release
- richer export/report 관리 기능
- archived/forked repo 필터링
- 스캔 진행 상태 정보 강화

## 기여 방법

1. feature branch를 생성합니다.
2. `swift build`를 실행합니다.
3. `swift run FindKey -- --self-test`를 실행합니다.
4. 동작이 바뀌면 문서를 갱신합니다.
5. 검증 결과를 포함해 PR을 엽니다.
