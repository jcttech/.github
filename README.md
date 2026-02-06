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

### Permissions

Reusable workflows require the calling workflow to grant permissions that nested jobs need:

| Workflow | Required Permissions |
|----------|---------------------|
| `rust-pipeline.yml` | `contents: write` (releases), `packages: write` (Docker) |
| `python-pipeline.yml` | `contents: write` (releases), `packages: write` (Docker) |
| `cleanup-docker.yml` | `packages: write` |

### Features

- **Change detection**: Skips builds when only non-code files change
- **SHA-based Docker caching**: Skips rebuild if image for commit SHA already exists
- **Semantic versioning**: Docker tags include `latest`, semver tags (`1.2.3`, `1.2`, `1`)
- **Cargo caching**: Fast rebuilds with cached dependencies
- **uv for Python**: Fast dependency installation with built-in caching

## Issue Templates

This repository also provides issue templates for:
- Bug reports
- Feature specs
- Epics
- Stories
- Tasks
