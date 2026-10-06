<div align="center">

<img src="logo.svg" alt="Sobaya" width="180">

### Sobaya

실패하는 테스트가 먼저, 에이전트는 그다음.

[English](README.md) · **한국어** · [가이드](docs/guide.md) · [런타임 레퍼런스](tdd-set/README.md) · [계약](AGENTS.md) · [검증 기록](docs/harness-validation.md)

</div>

Sobaya는 사람이 승인한 테스트를 중심으로 동작하는 개발 워크스페이스입니다.
사람이 명세를 소유하고 테스트 초안을 검토합니다. 하네스는 승인한 기준을
고정하고, 테스트 하나를 스위트에 넣어 RED를 확인하고, 구현을 위임한 다음
GREEN을 검증해야 진행 상황을 커밋합니다. 프로젝트는 `apps/<name>`의 독립
Git 저장소에 놓입니다.

하네스 런타임과 테스트는 Bash 3.2·jq·Git·표준 Unix 도구를 사용합니다.
앱 테스트 러너(Go·Node·로컬 Vitest)는 별도 의존성입니다. 전체 하네스 검사는
`bash tests/run.sh`로 실행하며 Python 인터프리터 사용과 저장소에 있는
Python 하네스 소스를 차단합니다.

## 작업 흐름

```mermaid
flowchart LR
    S[사람의 명세] --> D[테스트 초안과 probe]
    D --> A[사람의 검토와 기준 승인]
    A --> R[하네스가 테스트 하나 추가하고 RED 확인]
    R --> W[워커가 구현]
    W --> V[하네스가 무결성과 전체 스위트 검증]
    V --> C[하네스가 항목 체크하고 커밋]
    C --> N{남은 항목?}
    N -- 있음 --> R
    N -- 없음 --> G[최종 게이트와 독립 리뷰]
```

1. 앱 계약을 설치하고 `spec.md`에 의도한 동작을 적습니다.
2. `failed-test.md` 초안을 만들고 후보 테스트를 probe하여 기대값을 검토합니다.
   처음 초안과 변경 초안은 전체 원본 코드를 보여준 뒤, 필요한 공통 코드까지
   모든 줄의 설계 근거를 한국어로 설명합니다.
   플랜과 TDD 실행에는 정확히 같은 실행용 원본을 사용합니다.
   에이전트가 만든 테스트는 사람이 승인하기 전까지 초안입니다.
3. 검토한 입력을 커밋하고 `approve.sh`로 승인을 기록합니다.
4. `step.sh`로 한 항목, `loop.sh`로 연속 실행합니다. 워커는 소스를 구현하고,
   하네스가 테스트 삽입·검증·체크박스·커밋을 담당합니다.
5. 최종 게이트와 독립 리뷰를 마치고 배운 점을 기록합니다. 루프에는 별도 리뷰
   호출이 포함되며 지적 사항이 남으면 완료로 처리하지 않습니다. 구조 리팩터링은
   별도 작업으로 요청합니다.

```sh
bash scripts/setup.sh .
tdd-set/bin/install.sh apps/example
# 사람이 spec.md와 테스트 플랜을 검토한 뒤 해당 입력을 커밋합니다.
tdd-set/bin/approve.sh apps/example
tdd-set/bin/doctor.sh apps/example
tdd-set/bin/loop.sh apps/example 20
tdd-set/bin/status.sh apps/example
tdd-set/bin/gate.sh apps/example
```

명령은 워크스페이스 루트에서 실행합니다. 특정 제공자의 슬래시 명령은 필요하지
않습니다. [가이드](docs/guide.md)는 설치·테스트 변경·실패 복구를 설명합니다.

이미 통과하는 항목은 워커 호출 없이 테스트를 검증하고 커밋합니다. Go의 미정의
심볼을 RED로 허용하는 명시적 승인 옵션은 런타임 레퍼런스를 참조하세요.
[`economy.example.json`](tdd-set/policies/economy.example.json)은 Sol로 구현하고
진단 인계가 있을 때 Astra로 전환하며, 최종 리뷰는 Astra가 맡는 예제입니다.

## 버전별 설치 (v1 개발 중)

`bin/sobaya config check --root PATH`는 작업 공간의 `sobaya.json`과 JSON
형식의 `sobaya.lock`을 읽습니다. 명시한 `project`/`dependency` 모드, 정확한
버전과 lock 필드를 검사하고 JSON 객체 하나를 출력합니다. 입력 오류는 종료
코드 2와 stderr 진단으로 보고하며 stdout은 비워 둡니다. 작업 공간을 보존하고
배포 파일 검증이나 설치는 수행하지 않습니다.

로컬 배포 묶음은 `bash scripts/package-release.sh`에 `--source`, `--version`,
`--commit`, `--output`을 명시해 만듭니다. 일치하는 로컬 버전 태그가 필요하며,
원본 밖의 새 디렉터리에 런타임 압축 파일과 SHA-256 매니페스트를 생성합니다.
[승인한 명령과 파일 범위](docs/plans/sobaya-v1-release-review.md)를 참고하세요.
원본과 기존 출력 경로를 보존하며 게시나 설치는 수행하지 않습니다.

`bash tdd-set/lib/install-runtime.sh`는 별도로 신뢰한 매니페스트와 배포 파일을
검증해 소비 작업 공간 밖에 버전별로 설치합니다. 설치된 `bin/sobaya`는 `init`,
`sync`, 기존 실행 명령, 명시적 `bump`를 지원하며 각각 `--root`와
`--install-root`를 받습니다. 프로젝트 모드는 기존 `apps/<name>` 저장소를,
종속 모드는 소비 저장소 자체를 연결합니다. 모드와 고정 버전은 작업 공간별입니다.

`bump`는 연결된 모든 앱의 전체 테스트와 포맷·린트 검사로 후보 버전을 검증하고,
승인·사용량 기록을 보존합니다. 성공하면 설정 두 파일을 검토용 변경으로 남기고,
검증 실패 시 복구하며, 진행 중인 항목이 있으면 거부합니다. 기존 지침과 지원하는
Git 훅도 보존합니다. 명령과 제약은 [설치 안내](docs/installed-runtime.md)에
있습니다. 위의 소스 체크아웃 방식도 계속 사용할 수 있습니다. v1은 아직
출시하지 않았으며 실제 v0.9 왕복 호환성·소비 측 시험·성능 비교는 출시 전
검증으로 남습니다.

## 보호하는 경계

| 경계 | 계약 |
|---|---|
| 사람의 승인 | 명세·플랜·앱 검증 명령을 커밋된 기준에 고정 |
| 테스트 무결성 | 승인한 테스트 본문·헤더와 기존 테스트·헬퍼·픽스처 보존 |
| 진행 | 검증된 항목 하나씩 전진; 워커 보고나 체크박스만으로는 승인 불가 |
| 결과 판정 | 전체 테스트 스위트와 필수 정리 검사; 최종 게이트로 완료 검증 |
| 실행 | 허용 워커·최대 호출 수·시간 제한 명시; 설정 없는 모델 승급 금지 |
| 동시성 | 체크아웃당 작성자 한 명; 병렬 변경은 독립 워크트리 사용 |

기본 워커는 Codex의 Astra입니다. 명시적 정책으로 다른 워커나 사용자 명령
어댑터를 고를 수 있으며, 판정 기준은 모두 같습니다. `selected`·`quality`·
`economy` 모드는 설정에 등록한 워커 선택에만 영향을 줍니다. 호출 수와 시간은
제한하지만, 사용량 기록이 통화 기준 예산 상한을 보장하지는 않습니다. 안전한
기본값은 새 세션이며, 항목별 검증 경계가 테스트당 세션 하나를 아키텍처로
강제하는 것은 아닙니다.

## 구성과 검증

- `AGENTS.md`: 간결한 공통 계약. 모델 이름이 아닌 작업 권한으로 유지보수합니다.
- `tdd-set/`: 승인·워커 실행·중간 검증·게이트·스택 스킬.
- `.agents/skills/`: 오케스트레이션·회고·볼트 관리.
- `brain/`: 관련 내용만 읽는 영속 지식.
- `docs/`: [사용 가이드](docs/guide.md)와 [출처 대응표](docs/from-noodle.ko.md).

하네스 테스트는 로컬 픽스처와 가짜 워커를 사용하며 유료 모델 세션을 실행하지
않습니다. 테스트 통과는 하네스에 대한 근거이며, 앱 테스트 플랜이 의도한 모든
동작을 포괄한다는 증명은 아닙니다. 명령과 정책 예시는
[런타임 레퍼런스](tdd-set/README.md)에 있습니다.

## 출처

TDD와 Tidy First는 Kent Beck의 BPlusTree3·TCRSkill 작업을 바탕으로 조정했습니다.
초기 개발 규칙의 역사적 출처는 BPlusTree3의 `rust/docs/CLAUDE.md`, 커밋
`e1f539e`이며 현재 규칙은 원문 그대로가 아닙니다. 워크스페이스 메모리·격리·
리뷰 방식은 [noodle](docs/from-noodle.ko.md)에서 영감을 받았습니다.
