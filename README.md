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

Complete CI/CD for Rust projects: change detection, build, clippy, test, Docker, and releases.

**Inputs:**
| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `code-paths` | string | src/**, Cargo.*, Dockerfile, tests/** | Newline-separated glob patterns for code files |
| `rust-version` | string | `stable` | Rust toolchain version |
| `enable-docker` | boolean | `true` | Build and push Docker image |
| `enable-release` | boolean | `true` | Create GitHub release on tags |

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
| `model` | string | `claude-sonnet-4-6` | Claude model to use for review |
| `max-turns` | number | `10` | Maximum conversation turns (controls cost) |
| `timeout-minutes` | number | `15` | Maximum runtime in minutes |
| `runner` | string | `ubuntu-latest` | GitHub Actions runner to use |
| `review-extra` | string | `''` | Additional review instructions appended to the default prompt |

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

### `code-paths:` Fast Lane Convention

JCT TECH reusable workflows accept an optional `code-paths:` input that gates the body of the workflow on a path filter. This is the standardised docs-only fast-lane shared across the meta package — a PR that doesn't touch the relevant code paths sees the job appear in the checks list, run for ~10 s, and exit green.

**Behaviour:**

- **Empty default** (`code-paths: ''`) — always run; the gate is a pass-through.
- **Multi-line glob list** — on `pull_request` events, the workflow runs [`dorny/paths-filter@v4`](https://github.com/dorny/paths-filter) against the input. If nothing matches, every subsequent step is skipped (`if: steps.gate.outputs.should-run == 'true'`) and the job exits green in <30 s with no toolchain or build steps in the log.
- **Push events** (e.g. push-to-main) always run regardless of the filter — the gate is bypassed for non-PR events so main-branch CI stays comprehensive.

**Currently supported:**

| Workflow | `code-paths:` support |
|---|---|
| `rust-pipeline.yml` | yes (since pre-existing) |
| `openapi-drift.yml` | yes |
| `leptos-web-build.yml` | yes |
| `rust-database-tests.yml` | yes — opt-in once `@v2` is cut (Spec [jcttech/trading#185](https://github.com/jcttech/trading/issues/185) Story B) |

**Reference scaffolding:** see `.github/workflows/openapi-drift.yml` for the canonical implementation. The two-step gate (`Compute should-run from code-paths` → `Decide should-run`) is intentionally byte-identical across siblings so callers and reviewers can recognise the pattern at a glance.

**Convention for new reusable workflows:** any workflow added to this meta package SHOULD adopt `code-paths:` as an input by default. Copy the scaffolding verbatim from `openapi-drift.yml` or `leptos-web-build.yml`. The motivation is documented in Spec [jcttech/trading#185](https://github.com/jcttech/trading/issues/185) §D1; the goal is that downstream callers get docs-only-skip behaviour for free without each workflow author re-inventing the gate.

**Caller example:**

```yaml
jobs:
  web-build:
    uses: jcttech/.github/.github/workflows/leptos-web-build.yml@v2
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

This repo uses two long-lived tags consumers can pin to:

| Tag | Tip points at |
|---|---|
| `@v1` | the latest commit considered backwards-compatible with the original `@v1` API. Force-moved forward as additive sibling workflows land. |
| `@v2` | (cut once Spec [jcttech/trading#185](https://github.com/jcttech/trading/issues/185) Story B's `rust-database-tests.yml` extension lands) the recognisable opt-in moment for the multi-step `rust-database-tests.yml` capability. |

**`@v1 → @v2` is zero-diff for existing callers.** All new inputs added in the `@v2`-cut series are guarded with `if: inputs.<name> != ''` and default to the empty/no-op state, so a caller pinned to `@v1` (`init-sql:` + `test-command:` only on `rust-database-tests.yml`, for example) sees identical behaviour after switching the pin to `@v2`. The `@v2` tag exists primarily as a recognisable opt-in moment, not a breaking change.

**Operations:**

- **Force-moving `@v1` forward** — used when a sibling workflow is added that doesn't touch any existing file. Existing callers don't reference the new files, so the move is invisible to them and unlocks the new sibling for `@v1`-pinned consumers who choose to adopt it. Run `git tag -f -a v1 -m "..." && git push --force origin v1`.
- **Cutting a new `@vN`** — used when a substantive opt-in capability lands (e.g. multi-step DB-tests). Run `git tag -a vN -m "..." && git push origin vN`. The new tag points at the same commit as the moved-forward `@v(N-1)` at the moment of the cut; they diverge as further changes accumulate.
- **Don't accumulate diverging changes between operations.** If something else lands on `main` between a force-move and the next tag cut, re-do the force-move first so both tags stay aligned at the same commit.

### Permissions

Reusable workflows require the calling workflow to grant permissions that nested jobs need:

| Workflow | Required Permissions |
|----------|---------------------|
| `rust-pipeline.yml` | `contents: write` (releases), `packages: write` (Docker) |
| `python-pipeline.yml` | `contents: write` (releases), `packages: write` (Docker) |
| `claude-review.yml` | `contents: read`, `pull-requests: write`, `issues: write`, `id-token: write` |
| `claude.yml` | `contents: write`, `pull-requests: write`, `issues: write`, `id-token: write`, `actions: read` |
| `cleanup-docker.yml` | `packages: write` |

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
