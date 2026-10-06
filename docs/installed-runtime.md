# 설치된 Sobaya 사용하기

v1 설치 흐름의 사용 안내입니다. 아래 `1.0.0-rc.1`과 `1.0.0-rc.2`는 명령 예시이며, 해당 버전이 공개됐다는 뜻이 아닙니다. 실제로 확보하고 신뢰한 배포 파일의 버전과 경로로 바꾸세요.

모드와 버전은 **Sobaya를 사용하는 각 작업 공간**의 `sobaya.json`과 `sobaya.lock`으로 정합니다. 같은 설치 저장소를 쓰는 다른 작업 공간의 모드·버전까지 바뀌지 않습니다. 개인 설치 경로는 이 두 공유 파일에 기록하지 않습니다.

## 1. 정확한 버전 설치

실행기에는 Bash 3.2, jq, Git, 표준 Unix 도구가 필요합니다. 설치에는 `tar`, `gzip`, `shasum`을 사용하며 다운로드할 때는 `curl`도 필요합니다. 개발 실행의 잠금에는 macOS/BSD의 `shlock` 또는 Linux의 `flock`이 필요합니다. 앱의 테스트 도구·의존성과 정책에 지정한 작업자 실행기는 별도로 준비합니다.

부트스트랩 스크립트와 릴리스 매니페스트는 별도로 신뢰할 수 있는 경로에서 확보합니다. 설치기는 매니페스트를 원격에서 자동으로 가져와 신뢰하지 않습니다.

```bash
consumer_root="/absolute/path/to/existing-consumer"
runtime_store="/absolute/path/to/sobaya-store"
bootstrap="/absolute/path/to/trusted/install-runtime.sh"
runtime_version="1.0.0-rc.1"
trusted_manifest="/absolute/path/to/sobaya-$runtime_version.json"
local_archive="/absolute/path/to/sobaya-$runtime_version.tar.gz"

/bin/bash "$bootstrap" \
  --root "$consumer_root" --install-root "$runtime_store" \
  --version "$runtime_version" --manifest "$trusted_manifest" \
  --archive "$local_archive"
```

`consumer_root`는 이미 존재하는 디렉터리여야 합니다. `runtime_store`는 그 밖에 둡니다. 이 설치 단계에는 소비 저장소의 Git 초기화나 모드 설정이 필요하지 않습니다.

`--archive`를 생략하면 설치기는 `https://github.com/team-poem/sobaya/releases/download/vVERSION/sobaya-VERSION.tar.gz` 형식의 고정 주소에서 아카이브를 받습니다. 매니페스트에 적힌 임의 URL은 사용하지 않습니다. 버전·아카이브 SHA-256·Git archive 커밋 표식·허용된 파일 구성을 검사합니다. 커밋 표식과 해시 일치는 전달받은 자료의 일관성 검사이며, 매니페스트 자체의 출처를 증명하지는 않습니다.

설치 결과는 `$runtime_store/runtimes/VERSION/runtime`에, 공통 실행기는 `$runtime_store/bin/sobaya`에 생깁니다. 같은 정상 설치를 반복해도 기존 내용을 바꾸지 않습니다. 변조되거나 불완전한 설치, 충돌하는 경로는 자동 덮어쓰기 대신 오류로 처리합니다.

## 2. 기존 작업 공간 연결

연결할 앱은 자체 Git 저장소와 기존 `AGENTS.md`, `spec.md`, `failed-test.md`를 갖춰야 합니다. `AGENTS.md`에는 실행 가능한 전체 `Test:` 명령과 필요한 `Format:`·`Lint:` 명령을 선언합니다. `init`은 이 파일을 새로 작성하거나 기존 내용을 바꾸지 않습니다.

**종속 모드**에서는 기존 프로젝트 저장소 자체가 소비 작업 공간이자 앱입니다. 기존 모노레포 디렉터리도 유지합니다.

```bash
app_path="$consumer_root"
"$runtime_store/bin/sobaya" init \
  --root "$consumer_root" --install-root "$runtime_store" \
  --mode dependency --version "$runtime_version"
```

**프로젝트 모드**에서는 소비 작업 공간 자체가 Git 저장소이고 기존 `brain/`과 `apps/` 구조가 있어야 합니다. 연결할 앱은 `apps/<name>` 바로 아래의 별도 Git 저장소여야 합니다. 앱마다 같은 명령을 실행해 연결합니다.

```bash
app_path="$consumer_root/apps/calculator"
"$runtime_store/bin/sobaya" init \
  --root "$consumer_root" --install-root "$runtime_store" \
  --mode project --version "$runtime_version" --app "$app_path"
```

처음 연결하면 공유할 `sobaya.json`과 `sobaya.lock`이 생깁니다. 기존 설정이 있으면 모드·버전·릴리스 식별 정보가 일치해야 합니다. 같은 연결은 반복할 수 있지만, `init`으로 버전을 바꾸거나 모드를 자동 전환하지 않습니다. 새 작업 공간 골격을 만드는 기능도 이번 범위에 포함되지 않습니다.

연결 정보와 추가 안내는 해당 워크트리의 Git 메타데이터 아래 `sobaya/`에 저장됩니다. 기존 지침과 승인 상태는 유지하고, 작업자 프롬프트에는 선택한 설치본의 정확한 `tdd-set/AGENTS.md` 경로를 전달합니다. `init`은 사람의 테스트 승인을 대신하지 않습니다.

기존 훅 파일과 링크는 유지합니다. 로컬 `core.hooksPath`를 생성한 전달용 훅 디렉터리로 연결하고, `pre-commit`은 기존 실행 훅이 성공한 뒤 앱의 포맷·린트 검사를 실행합니다. 다른 지원 훅은 기존 인자·표준 입력·출력·종료 상태를 전달합니다. 일반 Git 커밋 훅이 전체 테스트 실행이나 승인된 체크포인트를 대신하지는 않습니다.

지원하지 않는 실행 훅이나 관리 경로 충돌이 있으면 연결을 거부합니다. 연결 후 훅 구성 변경을 `init`이 자동 병합하지는 않습니다. 연결된 워크트리가 있는 저장소는 이미 `extensions.worktreeConfig=true`로 준비돼 있어야 하며, Sobaya는 그 워크트리의 훅 설정만 바꿉니다. 공유 Git 설정의 자동 이전은 하지 않습니다.

## 3. 기존 승인 흐름 실행

생성된 두 설정 파일을 검토하고 소비 저장소에서 커밋합니다. 실행할 앱의 작업 트리와 인덱스도 깨끗해야 합니다. 아래에서는 두 모드 모두 `app_path`를 명시합니다. 종속 모드에서는 `consumer_root`와 같은 경로입니다.

```bash
"$runtime_store/bin/sobaya" config check --root "$consumer_root"

worker_policy="/absolute/path/to/reviewed-worker-policy.json"
"$runtime_store/bin/sobaya" doctor \
  --root "$consumer_root" --install-root "$runtime_store" \
  --app "$app_path" --policy "$worker_policy"

# 사람이 정확한 테스트 입력을 승인한 경우에만 승인 기준을 기록합니다.
"$runtime_store/bin/sobaya" approve \
  --root "$consumer_root" --install-root "$runtime_store" --app "$app_path"

"$runtime_store/bin/sobaya" loop \
  --root "$consumer_root" --install-root "$runtime_store" \
  --app "$app_path" --policy "$worker_policy"

"$runtime_store/bin/sobaya" status \
  --root "$consumer_root" --install-root "$runtime_store" --app "$app_path"
```

`config check`는 로컬 설정·lock 형식을 읽기만 합니다. `doctor`는 유료 작업자를 호출하지 않습니다. `loop`는 지정한 정책으로 작업자와 독립 리뷰를 실행합니다. 한 항목만 진행하려면 `step`, 최종 검증은 `gate`, 별도 리뷰는 `review`를 사용합니다. `next`와 `usage [RUN_ID]`도 같은 `--root`·`--install-root`·`--app` 방식으로 호출합니다.

일반 실행은 lock의 정확한 로컬 설치본을 검사해 사용하며 릴리스 조회·다운로드나 다른 버전으로의 자동 대체를 하지 않습니다. 승인 기준, 호출 수, 진행 중인 항목은 기존 실행기가 관리합니다. 실패 후에는 `status`와 보존된 진단을 확인하고 필요한 경우 `step` 또는 `loop`에 `--resume`을 지정합니다. 변경된 테스트의 승인을 버전 변경으로 대신할 수는 없습니다.

## 4. lock에 맞춰 설치 복원

`sync`는 검토된 `sobaya.json`·`sobaya.lock`의 정확한 버전을 설치 저장소에 준비합니다. 최신 버전을 찾거나 설정을 다시 고정하지 않으며, 소비 저장소의 훅과 연결 정보도 바꾸지 않습니다.

```bash
# 이미 사용 가능한 신뢰한 CLI: 기존 설치 저장소 또는 소스 체크아웃의 bin/sobaya
available_cli="/absolute/path/to/available/bin/sobaya"
"$available_cli" sync \
  --root "$consumer_root" --install-root "$runtime_store" \
  --archive "$local_archive"
```

`--archive`를 생략하면 lock의 해시를 기준으로 해당 버전의 GitHub 아카이브를 받아 검증합니다. 설치 저장소 전체가 없는 환경에서는 그 저장소 안의 실행기를 먼저 호출할 수 없으므로 별도로 확보한 CLI를 사용합니다. 새 clone은 `sync` 뒤 기존 모드와 버전으로 `init` 연결도 필요합니다. 기존 연결을 다른 설치 경로로 자동 이전하는 명령은 아닙니다.

## 5. 검증 후 버전 변경

`bump`는 후보 버전과 별도로 신뢰한 매니페스트를 명시합니다. 먼저 소비 저장소와 연결된 앱들의 변경 사항을 정리하고, 실행 중이거나 중단 후 재개를 기다리는 항목이 없는지 확인합니다.

```bash
candidate_version="1.0.0-rc.2"
candidate_manifest="/absolute/path/to/sobaya-$candidate_version.json"
candidate_archive="/absolute/path/to/sobaya-$candidate_version.tar.gz"

"$runtime_store/bin/sobaya" bump \
  --root "$consumer_root" --install-root "$runtime_store" \
  --version "$candidate_version" --manifest "$candidate_manifest" \
  --archive "$candidate_archive"

git -C "$consumer_root" diff -- sobaya.json sobaya.lock
```

후보를 검증·설치한 다음 후보 설정을 임시로 노출하고, **후보 런타임으로 전체 선언 테스트와 포맷·린트 검사**를 수행합니다. 프로젝트 모드는 `init`으로 연결한 모든 앱을 검사합니다. 연결하지 않은 다른 디렉터리까지 자동으로 앱으로 취급하지 않습니다.

성공하면 `sobaya.json`과 `sobaya.lock` 변경을 검토용으로 남깁니다. 기존 사용자 설정 필드, 훅, 승인 기준, 호출 수와 리뷰 기록은 유지합니다. 자동 커밋·푸시·재승인은 하지 않으므로 변경을 검토한 뒤 직접 커밋합니다. 이어서 개발 실행을 하려면 깨끗한 앱 상태가 필요합니다.

검증에 실패하면 두 설정 문서를 원래 내용과 권한으로 복원합니다. 검증 명령이 승인 메타데이터나 Git 훅 설정을 변경한 경우도 거부하고 복구합니다. 앱 소스에 남은 변경은 진단을 위해 보존합니다. 취소 시에는 검증 프로세스가 종료된 뒤 복구하고 잠금을 해제합니다. 진행 중인 항목이 있으면 버전 변경을 거부합니다. 실행 중인 설치 파일을 직접 바꾸지 말고, 오류 원인과 검증 명령이 남긴 변경을 확인하세요.

## 남은 출시 검증

현재 설치 흐름의 로컬 검증을 실제 `v0.9 → v1 → v0.9`의 승인·상태·훅 호환성 증명으로 보지 않습니다. 실제 공개 GitHub 배포 자산을 사용하는 소비 환경 확인, 실제 모델을 포함한 성능·비용 비교도 남아 있습니다. 로컬 테스트는 실제 Git·앱 테스트 실행과 결정적인 작업자 대역을 사용합니다.

현재 검증 호스트는 macOS이며 Linux의 실제 `flock` 분기는 실행하지 못했습니다. 전원 장애나 강제 종료 중 두 설정 파일을 완전히 원자적으로 복구하는 기능, 복잡한 모든 훅 프로토콜, 새 작업 공간 생성과 자동 모드 전환도 보장 범위에 포함되지 않습니다. 정상 검증 실패의 복원과 이러한 미검증 상황을 구분합니다.
