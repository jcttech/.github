# .github

Community Health Files and Reusable CI/CD for JCT TECH Projects

## Reusable Workflows

This repository provides reusable GitHub Actions workflows and composite actions for consistent CI/CD across all JCT TECH projects.

### Quick Start

#### Rust Projects

```yaml
# .github/workflows/build.yml
name: Build

on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:

jobs:
  ci:
    uses: jcttech/.github/.github/workflows/rust-pipeline.yml@v1
    permissions:
      contents: write   # For releases
      packages: write   # For Docker
    secrets: inherit
```

#### Python Projects

```yaml
# .github/workflows/build.yml
name: Build

on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:

jobs:
  ci:
    uses: jcttech/.github/.github/workflows/python-pipeline.yml@v1
    permissions:
      contents: write   # For releases
      packages: write   # For Docker
    secrets: inherit
```

### Workflows

#### `rust-pipeline.yml`

Complete CI/CD for Rust projects: change detection, build, clippy, test, Docker, and releases. Optionally folds in three sibling reusable workflows as opt-in sub-jobs (`database-tests`, `openapi-drift`, `web-build`) so a single `uses:` call can replace several standalone jobs in a consumer's `ci.yml`.

**Top-level inputs:**

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `code-paths` | string | src/**, Cargo.*, Dockerfile, tests/** | Newline-separated glob patterns for code files |
| `rust-version` | string | `stable` | Rust toolchain version |
| `enable-build` | boolean | `true` | Run build, clippy, and test job |
| `enable-docker` | boolean | `true` | Build and push Docker image |
| `enable-release` | boolean | `true` | Create GitHub release on tags |
| `enable-docs` | boolean | `false` | Generate rustdoc and documentation coverage |
| `enable-rustdoc` | boolean | `true` | When `enable-docs` is true, also generate rustdoc HTML |
| `serialize-jobs` | boolean | `false` | Fail-fast cascading between `database-tests → openapi-drift → web-build` chain links. When `false`, failures don't cascade between chain links. The `needs:` chain itself is always static (GitHub Actions doesn't support dynamic `needs:`); this flag controls failure propagation, not literal parallelism. `docker` and `release` always cascade chain-link failures via `!failure()`. |
| `runner` | string | `github-arc-github-arc-runner-set` | Runner label for build/test jobs |
| `container-image` | string | `ghcr.io/jcttech/devcontainer-rust:latest` | Container image for build/docker/release pods (empty string for non-ARC GHA runners) |

**Database-tests sub-job (forwards to `rust-database-tests.yml`):**

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `enable-database-tests` | boolean | `false` | Opt into the database-tests sub-job |
| `database-test-command` | string | `cargo test --test database_tests -- --nocapture` | Forwarded as `test-command` |
| `postgres-image` | string | `postgres:18` | PostgreSQL service image |
| `init-sql` | string | `''` | Path to SQL init script run via psql before tests |
| `database-tests-pre-test-script` | string | `''` | Caller-relative bash script (e.g. `make schema-apply` + sqlx migrator), forwarded as `pre-test-script` |
| `database-tests-survey-script` | string | `''` | Caller-relative bash script that emits a schema survey to stdout, forwarded as `survey-script` |
| `database-tests-post-survey-issue` | string | `''` | Issue/PR number for idempotent survey-comment posting, forwarded as `post-survey-issue` |
| `database-tests-survey-marker` | string | `''` | HTML-comment marker for the survey-comment idempotency check, forwarded as `survey-marker` |
| `database-tests-code-paths` | string | `''` | D1 fast-lane glob list, forwarded as `code-paths` |

**OpenAPI-drift sub-job (forwards to `openapi-drift.yml`):**

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `enable-openapi-drift` | boolean | `false` | Opt into the OpenAPI drift sub-job |
| `openapi-drift-print-command` | string | `''` | Required when enabled — command run inside `openapi-drift-working-directory` that prints the live OpenAPI spec to stdout |
| `openapi-drift-committed-spec-path` | string | `''` | Required when enabled — repo-root-relative path to the committed spec |
| `openapi-drift-working-directory` | string | `.` | Directory in which `openapi-drift-print-command` runs |
| `openapi-drift-container-image` | string | `ghcr.io/jcttech/devcontainer-rust-leptos:latest` | Container image for the openapi-drift job pod |
| `openapi-drift-code-paths` | string | `''` | D1 fast-lane glob list |

**Web-build sub-job (forwards to `leptos-web-build.yml`):**

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `enable-web-build` | boolean | `false` | Opt into the Leptos web-build + size-gate sub-job |
| `web-build-working-directory` | string | `.` | Directory in which build/bindings/wall commands run |
| `web-build-web-package` | string | `web` | Leptos hydrate-side crate name (e.g. `jtrader-web`) |
| `web-build-build-command` | string | `make web-build` | Release build + size-gate command |
| `web-build-bindings-command` | string | `make web-check-bindings` | OpenAPI ⇄ client drift-check command (pass `''` to skip) |
| `web-build-wall-script` | string | `''` | Opt-in path to a project-specific lint/wall gate script |
| `web-build-wasm-size-artifact` | string | `''` | Repo-root-relative path of a single file to upload as the `wasm-size` artefact |
| `web-build-container-image` | string | `ghcr.io/jcttech/devcontainer-rust-leptos:latest` | Container image for the web-build job pod (must carry the WASM toolchain) |
| `web-build-code-paths` | string | `''` | D1 fast-lane glob list |

**Cargo-tests sub-job (`cargo-tests.yml`, matrix; build once, run everywhere since `@v3`):**

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `enable-cargo-tests` | boolean | `false` | Opt into the matrix of test lanes (one status check per lane: `cargo-tests (<name>) / <name>`) |
| `cargo-tests` | string | `[]` | JSON array of lanes (fields below) |
| `cargo-tests-build-once` | boolean | `true` | Build the triggered structured lanes' test binaries once (`cargo-tests-archive` job, `cargo nextest archive`) and run every lane from the archive. `false`: every lane builds itself (v2 behaviour) |
| `cargo-tests-manifest-path` | string | `Cargo.toml` | Repo-root-relative workspace manifest the structured lanes build from |
| `cargo-tests-build-jobs` | string | `1` | `CARGO_BUILD_JOBS` for the archive build and for structured lanes that build themselves (`''` = unset). Conservative on purpose; raise it on measured memory headroom |
| `cargo-tests-build-env` | string | `''` | `KEY=VALUE` lines exported for every build the pipeline composes (not for a free-form `command`) |
| `cargo-tests-build-wrapper` | string | `''` | Prefix the archive build runs under (e.g. a memory probe) |
| `cargo-tests-feature-check` | string | `report` | `report` / `strict` / `off` — Cargo unifies features across one build's packages; `report` lists the workspace crates whose features differ from a lane-alone build, `strict` builds such lanes on their own |
| `cargo-tests-archive-warn-mib` | number | `2048` | Warn when one run's test archives exceed this many MiB (they're uploaded before any lane starts) |
| `cargo-tests-archive-retention-days` | number | `1` | Retention of the archive artifacts; a lane re-run after expiry builds itself |
| `cargo-tests-archive-dir` | string | `''` | A directory on a shared cache volume (K8s NFS, like `rust-setup`'s `shared-cache`), e.g. `/cache/cargo-tests-archive`: the archives go there instead of GitHub artifacts (see below). Empty: artifacts |
| `cargo-tests-archive-cleanup` | boolean | `true` | Delete the run's archives once every lane passed (`cargo-tests-archive-cleanup` job); keep them for "Re-run failed jobs" when a lane failed or the run was cancelled. Needs `actions: write` granted by the **caller** (see below); without it the job leaves a notice and passes |

Lane fields: `name` (required), `command`, `with-postgres`, `postgres-image`, `pre-test-script`, `init-sql`, `code-paths`, `working-directory` (as in v2), and the structured fields `packages` (the `-p` list; makes the lane eligible for the archive), `features`, `profile`, `filter` (nextest filterset, ANDed with the packages), `nextest-args`, `doctests` (`'true'`/`'false'`), `setup` (shell before the tests, same step), `test-wrapper`, `build-once` (`'false'` = always build itself), `build-jobs`.

How a run goes: the `changes` job evaluates every lane's `code-paths` (pull requests only, fail-open) and plans each triggered lane as *archive* or *per-lane*. A lane builds itself when the pipeline opts out (`cargo-tests-build-once: false`), the lane opts out, it has no `packages` (a free-form `command` can't be shared), the image lacks `cargo-nextest`, fewer than two triggered lanes qualify, or `cargo-tests-feature-check: strict` moves it off. With two or more archive lanes, `cargo-tests-archive` builds the union of **their** packages and features once, writes one archive per lane (only that lane's packages' binaries), uploads each as an artifact, and runs `cargo test --doc` once against the same build (nextest archives carry no doc tests); each lane downloads its own archive, runs `cargo nextest run -E '(package(=…) | …) & (<filter>)'` from it, and fails on its own packages' doc-test result. A re-run of a failed lane reuses the archive. If the archive job fails, every archive lane fails with a pointer to it.

Archive size is what decides whether this pays: every test binary statically links the whole dependency graph, the archives are uploaded before any lane starts, and the job summaries report sizes and transfer times every run. Fewer, larger test binaries (one integration-test binary per area) keep the archives small; `CARGO_PROFILE_TEST_STRIP=debuginfo` in `cargo-tests-build-env` cuts about a quarter at the cost of line numbers in backtraces (the panic's own `file:line` is kept). **Archive storage and cleanup.** The archives are Actions artifacts and count against the organisation's Actions storage. jcttech/trading's five lanes come to about 2.5 GB per run. With `cargo-tests-archive-cleanup` (the default) and `actions: write` granted, a green run deletes them as its last job, after about 20 minutes of storage. A failed or cancelled run keeps them for re-runs until `cargo-tests-archive-retention-days` (1 day) removes them. Without the grant every run keeps them for the day: about 2.5 GB-days per run. A called workflow can't raise its caller's token permissions, so the grant goes on the caller's job:

```yaml
jobs:
  ci:
    uses: jcttech/.github/.github/workflows/rust-pipeline.yml@v3
    permissions:
      contents: read
      actions: write   # lets cargo-tests-archive-cleanup delete the run's test archives
    secrets: inherit
```

(If the workflow sets `permissions:` at the top, add `actions: write` there or on the calling job; nested jobs only ever get what the caller's job has.)

**Shared archive directory (`cargo-tests-archive-dir`).** On self-hosted runners whose job containers mount a shared volume, as jcttech's ARC runners mount `/cache` for sccache, set `cargo-tests-archive-dir: /cache/cargo-tests-archive`. It has these effects:
- The archive job writes each lane's archive to `<dir>/<owner>/<repo>/<run_id>/cargo-tests-archive-<hash>/lane-<n>.tar.zst`. It writes to a temporary name, puts the SHA-256 beside the file, then renames it, so a lane never sees a partial file.
- Each lane verifies the checksum and reads its archive in place. There is no artifact upload or download, nothing counts against Actions storage, and no `actions: write` is needed.
- The directory is keyed on the run id, not the attempt, so "Re-run failed jobs" finds the files.
- Cleanup (`cargo-tests-archive-cleanup`) deletes the pipeline's run directory when every lane passed.
- Each archive job sweeps run directories older than `cargo-tests-archive-retention-days` under `<dir>/<owner>/<repo>`.
- Every delete is guarded: it refuses an empty path, `/`, `.` or `..` segments, symlinks, `SCCACHE_DIR` or anything inside it, and anything that isn't a run directory under `<dir>/<owner>/<repo>`.
- If the directory isn't on a mounted volume or isn't writable in the archive job, the run uses artifacts with a notice. A lane that can't find or verify its archive builds its own test binaries, with a warning.
- The job summaries report sizes, write and read times, and the volume's free space, and warn below four times the run's archive size.
- **Trust model:** any job on those runners can read and write the volume, as with sccache. A job could replace an archive, but the checksum only catches corruption, not a hostile job on the same runners. Use it only where the runners are yours and run only your repositories' jobs.

A nextest archive carries the tested packages' build-script outputs but not a dependency's: a test that reads a dependency's `OUT_DIR` at run time (rust-embed in debug builds, e.g. utoipa-swagger-ui's Swagger UI) needs the dependency to embed it (`debug-embed`) or nextest's `[profile.default.archive] include`. The archive build runs at `CARGO_BUILD_JOBS=1` unless raised: it links one binary at a time, so its memory peak is one heavy link (4.5 GiB of anonymous memory on jcttech/trading's largest workspace).

```yaml
      enable-cargo-tests: true
      cargo-tests-manifest-path: app/Cargo.toml
      cargo-tests-build-env: |
        CARGO_PROFILE_DEV_DEBUG=line-tables-only
      cargo-tests: |
        [
          {"name": "Unit", "packages": "core util", "profile": "ci", "doctests": "true",
           "code-paths": "app/crates/core/**\napp/crates/util/**"},
          {"name": "Integration", "packages": "server", "profile": "ci", "filter": "not group(slow)",
           "with-postgres": "true", "pre-test-script": "./scripts/ci/db.sh",
           "setup": "bash scripts/ci/redis-up.sh && export REDIS_URL=redis://127.0.0.1:6379"}
        ]

**Example with custom options:**
```yaml
jobs:
  ci:
    uses: jcttech/.github/.github/workflows/rust-pipeline.yml@v1
    with:
      rust-version: '1.93'
      code-paths: |
        src/**
        lib/**
        Cargo.*
    permissions:
      contents: write
      packages: write
    secrets: inherit
```

**Example folding three sibling jobs into one call (Leptos + DB + OpenAPI):**
```yaml
jobs:
  ci:
    uses: jcttech/.github/.github/workflows/rust-pipeline.yml@v1
    permissions:
      contents: write
      packages: write
      issues: write       # for database-tests survey-comment posting
    secrets: inherit
    with:
      enable-build: false
      enable-docker: false
      enable-release: false
      serialize-jobs: true   # fail-fast cascading on ARC OOM-prone runners

      enable-database-tests: true
      container-image: ghcr.io/jcttech/devcontainer-rust-leptos:latest
      database-tests-pre-test-script: ./scripts/ci/db-pretest.sh
      database-tests-survey-script: ./scripts/survey-schema.sh
      database-tests-post-survey-issue: '18'
      database-tests-survey-marker: '<!-- schema-survey -->'
      database-test-command: cargo test --workspace

      enable-openapi-drift: true
      openapi-drift-working-directory: app
      openapi-drift-print-command: cargo run -p server -- --print-openapi
      openapi-drift-committed-spec-path: .docs/openapi.yaml

      enable-web-build: true
      web-build-working-directory: app
      web-build-web-package: app-web
      web-build-wall-script: ./scripts/check-wall.sh
      web-build-wasm-size-artifact: app/target/site/pkg/app_web.wasm.gz.size
```

#### `python-pipeline.yml`

Complete CI/CD for Python projects: change detection, pytest, ruff, Docker, and releases.

**Inputs:**
| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `code-paths` | string | src/**, pyproject.toml, requirements*.txt, Dockerfile | Newline-separated glob patterns |
| `python-version` | string | `3.12` | Python version |
| `enable-docker` | boolean | `true` | Build and push Docker image |
| `enable-release` | boolean | `true` | Create GitHub release on tags |

#### `claude-review.yml`

Automated multi-angle PR review powered by Claude. Reviews every PR for code quality, security, bugs, performance, and test coverage.

**Inputs:**
| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `model` | string | `claude-opus-5-5` | Claude model to use for review |
| `max-turns` | number | `50` | Maximum conversation turns (controls cost) |
| `timeout-minutes` | number | `20` | Maximum runtime in minutes (the Claude step stops a few minutes earlier, so the check after it still runs) |
| `runner` | string | `ubuntu-latest` | GitHub Actions runner to use |
| `review-extra` | string | `''` | Additional review instructions appended to the default prompt |
| `fail-on-missing-review` | boolean | `true` | Fail the job when Claude ends without posting a review on the head commit. `false` only warns |

**Outputs:** `review-posted` (`true`/`false`), `review-state` (`APPROVED`, `CHANGES_REQUESTED`, `COMMENTED` or empty), `review-outcome` (`posted`, `salvaged`, `no-new-findings`, `superseded` or `missing`) and `review-failure-reason` (one line).

**Large PRs.** Before Claude runs, the workflow splits the PR's diff into one annotated file per changed file (parts of at most ~40 KB, every line with its new and old line number) plus an index, and Claude reads those with the Read tool. One `gh pr diff` call returns only the start of a large diff, and the commands that page through shell output aren't allowed. When GitHub refuses the diff (over 20,000 lines or 300 files), the workflow builds it from git instead.

**When no review is posted.** A run that ends without a review on the head commit is reported as a failure, not as success. If Claude wrote a draft but didn't post it, the workflow posts the draft as an incomplete review (an `APPROVE` draft is posted as a `COMMENT`). Without a draft, it comments "Claude Review could not complete" on the PR with the reason (out of turns, timed out, an API error, or stopped early, plus any refused tool calls). Either way the job fails, unless `fail-on-missing-review` is `false`. A re-review whose findings are all open threads already posts no review on purpose and is not a failure.

**Review perspectives (built-in):**
1. Code quality and maintainability
2. Security (OWASP Top 10, credential exposure, input validation)
3. Bug detection (logic errors, race conditions, resource leaks)
4. Performance (N+1 queries, blocking async, unbounded collections)
5. Test coverage and quality

#### `claude.yml`

Interactive Claude assistant that responds to `@claude` mentions on PRs and issues. Can read code, suggest fixes, and push commits when asked.

**Inputs:**
| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `model` | string | `claude-sonnet-4-6` | Claude model to use |
| `max-turns` | number | `30` | Maximum conversation turns |
| `timeout-minutes` | number | `30` | Maximum runtime in minutes |
| `runner` | string | `ubuntu-latest` | GitHub Actions runner to use |

**Example caller workflow (add to each repo):**
```yaml
# .github/workflows/claude.yml
name: Claude

on:
  pull_request:
    types: [opened, synchronize, ready_for_review, reopened]
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
  pull_request_review:
    types: [submitted]

jobs:
  review:
    if: github.event_name == 'pull_request'
    uses: jcttech/.github/.github/workflows/claude-review.yml@v1
    permissions:
      contents: read
      pull-requests: write
      issues: write
      id-token: write
    secrets: inherit

  interactive:
    if: |
      (github.event_name == 'issue_comment' && contains(github.event.comment.body, '@claude')) ||
      (github.event_name == 'pull_request_review_comment' && contains(github.event.comment.body, '@claude')) ||
      (github.event_name == 'pull_request_review' && contains(github.event.review.body, '@claude'))
    uses: jcttech/.github/.github/workflows/claude.yml@v1
    permissions:
      contents: write
      pull-requests: write
      issues: write
      id-token: write
      actions: read
    secrets: inherit
```

**Setup:** Requires one of these org-level secrets (Settings > Secrets and variables > Actions):

| Secret | Source | Billing |
|--------|--------|---------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Run `claude setup-token` locally | Uses Max/Pro subscription quota |
| `ANTHROPIC_API_KEY` | console.anthropic.com | Pay-per-token API billing |

**Per-repo customisation:** Add a `CLAUDE.md` file to any repository root with project-specific standards, coding conventions, and review criteria. Claude reads this automatically and applies it on top of the org-wide review prompt.

#### `cleanup-docker.yml`

Scheduled cleanup of old Docker images from GitHub Container Registry.

**Inputs:**
| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `image-name` | string | *required* | Image name to clean up |
| `keep-recent` | number | `10` | Number of recent images to keep |
| `cut-off` | string | `2 weeks ago UTC` | Delete images older than this |

**Example:**
```yaml
# .github/workflows/cleanup.yml
name: Cleanup

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday
  workflow_dispatch:

jobs:
  cleanup:
    uses: jcttech/.github/.github/workflows/cleanup-docker.yml@v1
    with:
      image-name: my-project
    permissions:
      packages: write
    secrets: inherit
```

#### `release.yml`

Cuts a release by bumping the project version across **every manifest in lockstep** (`Cargo.toml`/`Cargo.lock`, `.claude-plugin/plugin.json` + `marketplace.json`, `pyproject.toml`, `package.json`), committing `Release vX.Y.Z`, and creating + pushing the `vX.Y.Z` tag. The mechanical bump is the deterministic, locally-testable [`version-bump`](#version-bump) composite action; this workflow adds the commit/tag/push. Building and publishing the artifacts stays with the consumer's existing tag-triggered pipeline (e.g. `rust-pipeline.yml` with `enable-release`).

**Inputs:**
| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `bump` | string | `patch` | `patch` \| `minor` \| `major`, or an explicit `X.Y.Z` |
| `runner` | string | `ubuntu-latest` | Runner label for the release job |
| `committer-name` | string | `github-actions[bot]` | Name for the release commit |
| `committer-email` | string | `41898282+github-actions[bot]@users.noreply.github.com` | Email for the release commit |

**Secrets:**
| Secret | Required | Description |
|--------|----------|-------------|
| `RELEASE_TOKEN` | no | PAT or GitHub App token used to checkout/push. Falls back to `GITHUB_TOKEN`. |

**Outputs:** `version` (`X.Y.Z`) and `tag` (`vX.Y.Z`).

> **Re-trigger note:** a tag pushed with the default `GITHUB_TOKEN` does **not** start further workflow runs (GitHub loop-prevention), so the consumer's tag-triggered build won't fire automatically. To fully automate, pass a PAT/App token as `RELEASE_TOKEN` (via `secrets: inherit`). Without it, the tag is still created — trigger the build manually, e.g. `gh workflow run ci.yml -f enable-release=true --ref vX.Y.Z`. Also ensure the default branch permits the release identity to push (allowlist it, or run releases off an unprotected branch).

**Example caller (add to each repo):**
```yaml
# .github/workflows/release.yml
name: Release

on:
  workflow_dispatch:
    inputs:
      bump:
        description: 'patch | minor | major | X.Y.Z'
        type: string
        default: patch

jobs:
  release:
    uses: jcttech/.github/.github/workflows/release.yml@v1
    with:
      bump: ${{ inputs.bump }}
    permissions:
      contents: write
    secrets: inherit
```

Then cut a release with `gh workflow run release.yml -f bump=minor` (or from the Actions tab).

### Composite Actions

These can be used standalone in custom workflows.

#### `rust-setup`

```yaml
- uses: jcttech/.github/.github/actions/rust-setup@v1
  with:
    rust-version: 'stable'  # optional
    components: 'clippy'    # optional
```

#### `python-setup`

```yaml
- uses: jcttech/.github/.github/actions/python-setup@v1
  with:
    python-version: '3.12'  # optional
```

#### `docker-build`

```yaml
- uses: jcttech/.github/.github/actions/docker-build@v1
  with:
    sha: ${{ github.sha }}
    registry: 'ghcr.io'     # optional
    image-name: 'my-image'  # optional, defaults to repo name
    push: 'true'            # optional
```

#### `version-bump`

Deterministically bumps the project version across every manifest present in the repo — `Cargo.toml`/`Cargo.lock`, `.claude-plugin/plugin.json` + `marketplace.json`, `pyproject.toml`, `package.json` — in lockstep, with minimal (version-line-only) diffs. Edits are value-agnostic and key-targeted, so a manifest that has drifted out of sync is healed to the target version. The version source of truth is the latest `v*` git tag (checkout with `fetch-depth: 0`). Backs [`release.yml`](#releaseyml); usable standalone.

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0
- id: bump
  uses: jcttech/.github/.github/actions/version-bump@v1
  with:
    bump: minor        # patch | minor | major | X.Y.Z  (default: patch)
    dry-run: 'false'   # optional: compute + print without writing
# steps.bump.outputs.version -> 1.3.0 ; steps.bump.outputs.tag -> v1.3.0
```

The underlying `bump.sh` is pure bash (only `git`, `sed`, `awk`) and can be run locally: `bump.sh <patch|minor|major|X.Y.Z> [--dry-run]`.

### `code-paths:` Fast Lane Convention

JCT TECH reusable workflows accept an optional `code-paths:` input that gates the body of the workflow on a path filter. This is the standardised docs-only fast-lane shared across the meta package — a PR that doesn't touch the relevant code paths sees the job appear in the checks list, run for ~10 s, and exit green.

**Behaviour:**

- **Empty default** (`code-paths: ''`) — always run; the gate is a pass-through.
- **Multi-line glob list** — on `pull_request` events, the workflow runs [`dorny/paths-filter@v4`](https://github.com/dorny/paths-filter) against the input. If nothing matches, every subsequent step is skipped (`if: steps.gate.outputs.should-run == 'true'`) and the job exits green in <30 s with no toolchain or build steps in the log.
- **Push events** (e.g. push-to-main) always run regardless of the filter — the gate is bypassed for non-PR events so main-branch CI stays comprehensive. A push to the repository's **default branch** is treated as the canonical ground-truth build: the fast-lane is bypassed both at the reusable's step gate *and* at `rust-pipeline.yml`'s job-level `if:`, so the real build/test always executes there ([jcttech/trading#200](https://github.com/jcttech/trading/issues/200)).
- **Fail-open** — if the path filter reaches no verdict (its step was skipped, the action errored, or the shell mangled the comparison), the gate runs the real work rather than reporting a silent green. Two production incidents came from the opposite default: `jcttech/trading#200` (push-event skip that concealed Bug #198 for months) and PR #20 (`[[` under `sh` on the ARC images, which silently skipped 135 database tests in `jcttech/claude-membank`).
- **Skips are never silent** — when the gate does legitimately skip on a PR, a `Report path-gated skip` step writes the reason to `$GITHUB_STEP_SUMMARY`, so a path-gated skip is always distinguishable in the UI from a real build.

**Currently supported:**

| Workflow | `code-paths:` support |
|---|---|
| `rust-pipeline.yml` | yes (top-level `code-paths` gates `build`/`docker`/`release`; the `database-tests`, `openapi-drift`, and `web-build` sub-jobs each accept their own `<sub-job>-code-paths` that's forwarded to the underlying sibling) |
| `openapi-drift.yml` | yes |
| `leptos-web-build.yml` | yes |
| `rust-database-tests.yml` | yes (added in follow-up to Spec [jcttech/trading#185](https://github.com/jcttech/trading/issues/185) — see `jcttech/trading#195`; closes the §D1 fast-lane gap noted at end of Story G) |

**Reference scaffolding:** see `.github/workflows/openapi-drift.yml` for the canonical implementation. The two-step gate (`Compute should-run from code-paths` → `Decide should-run`) is intentionally byte-identical across siblings so callers and reviewers can recognise the pattern at a glance.

**Convention for new reusable workflows:** any workflow added to this meta package SHOULD adopt `code-paths:` as an input by default. Copy the scaffolding verbatim from `openapi-drift.yml` or `leptos-web-build.yml`. The motivation is documented in Spec [jcttech/trading#185](https://github.com/jcttech/trading/issues/185) §D1; the goal is that downstream callers get docs-only-skip behaviour for free without each workflow author re-inventing the gate.

**Caller example:**

```yaml
jobs:
  web-build:
    uses: jcttech/.github/.github/workflows/leptos-web-build.yml@v1
    with:
      working-directory: jtrader
      web-package: jtrader-web
      code-paths: |
        jtrader/jtrader-web/**
        jtrader/jtrader-shared/**
        jtrader/Cargo.toml
        jtrader/Cargo.lock
        jtrader/Makefile
```

A PR that touches only `.docs/**` sees `web-build` exit green in <30 s. A PR touching `jtrader/jtrader-web/**` runs the full build.

### Versioning

This repo uses a **single major-rolling tag** convention. Consumers normally pin to `@v1`; downstream callers needing immutable behaviour across rolling updates use commit-SHA pins.

| Tag | Tip points at |
|---|---|
| `@v1` | the latest commit on `main` considered backwards-compatible with the original `@v1` API. Force-moved forward as additive sibling workflows and additive optional inputs land. |
| `@v2` | `rust-pipeline.yml` with the matrix-driven `cargo-tests` sub-job (the `enable-database-tests` path removed). Each lane builds its own test binaries. |
| `@v3` | `rust-pipeline.yml` / `cargo-tests.yml` with build once, run everywhere as the default for structured lanes (jcttech/trading#1160). Lane checks are `cargo-tests (<name>) / <name>`; new check `cargo-tests-archive`. |

**Why a single rolling tag (rather than cutting `@v2` for every additive opt-in moment)?**

Every change that has landed on these reusable workflows so far has been backwards-compatible — net-new sibling workflow files (e.g. `openapi-drift.yml`, `leptos-web-build.yml`), or new optional inputs guarded by `if: inputs.<name> != ''`. None of them break a caller that doesn't opt in. Cutting a new tag for each additive change creates a maintenance treadmill (every consumer eventually has to bump pins for behaviour they don't use) without buying any genuine isolation benefit.

`@v1` therefore force-moves forward whenever an additive change lands. A future `@v2` is reserved for a *real* breaking change — a removed input, a renamed step output, a changed default, or an incompatible behaviour shift. Until that day, `@v1` is the only contract worth pinning to, and consumers needing snapshot stability use commit SHAs.

**Operations:**

- **Force-moving `@v1` forward** (the default for any additive change) — used when a sibling workflow is added, or when an existing workflow gains a new optional input. Existing callers don't reference the new files / inputs, so the move is invisible to them and unlocks the new capability for `@v1`-pinned consumers who choose to adopt it. Run `git tag -f -a v1 -m "..." && git push --force origin v1`.
- **Commit-SHA pinning** (the escape hatch for callers needing immutability) — when a downstream caller needs guaranteed-stable behaviour across rolling `@v1` updates (e.g. a long-lived release branch, a reproducibility-sensitive build), pin to a specific commit SHA: `uses: jcttech/.github/.github/workflows/<workflow>.yml@<full-sha>`. This bypasses the rolling-major contract entirely and is the documented alternative to per-feature opt-in tags.
- **Cutting `@v2` (or higher)** — reserved for a true breaking change. Run `git tag -a v2 -m "..." && git push origin v2` at the SHA that introduces the break. At that moment `@v2` and `@v1` diverge; `@v1` either stays at the prior commit or is retired depending on the migration story for that release.

### Permissions

Reusable workflows require the calling workflow to grant permissions that nested jobs need:

| Workflow | Required Permissions |
|----------|---------------------|
| `rust-pipeline.yml` | `contents: write` (releases), `packages: write` (Docker) |
| `python-pipeline.yml` | `contents: write` (releases), `packages: write` (Docker) |
| `claude-review.yml` | `contents: read`, `pull-requests: write`, `issues: write`, `id-token: write` |
| `claude.yml` | `contents: write`, `pull-requests: write`, `issues: write`, `id-token: write`, `actions: read` |
| `cleanup-docker.yml` | `packages: write` |
| `release.yml` | `contents: write` (release commit + tag) |

### Features

- **Change detection**: Skips builds when only non-code files change
- **SHA-based Docker caching**: Skips rebuild if image for commit SHA already exists
- **Semantic versioning**: Docker tags include `latest`, semver tags (`1.2.3`, `1.2`, `1`)
- **Cargo caching**: Fast rebuilds with cached dependencies
- **uv for Python**: Fast dependency installation with built-in caching
- **Claude PR review**: Automated multi-angle code review on every PR
- **Claude interactive**: `@claude` mentions for on-demand assistance in PRs and issues

## Issue Templates

This repository also provides issue templates for:
- Bug reports
- Feature specs
- Epics
- Stories
- Tasks
