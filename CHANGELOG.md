# Changelog

All notable changes to this project will be documented in this file.

## [v1.5.5] - 2026-03-13

### Fixed
- **Gateway Network Configuration**: Updated `docker-entrypoint.sh` to use `lan` bind mode by default instead of `all`, respecting existing configurations while ensuring host accessibility.

## [v1.5.4] - 2026-03-13

### Fixed
- **Makefile (Environment Priority)**: Fixed `make install` to correctly respect the `OPENCLAW_IMAGE` environment variable defined in `.env` or the shell, while maintaining the ability to explicitly switch variants (e.g., `make install go`).

## [v1.5.3] - 2026-03-13

### Fixed
- **Docker Build (Go Stack)**: Replaced `rm -rf` with `go clean -modcache` to resolve permission denied errors during image construction as non-root user.

## [v1.5.2] - 2026-03-13

### Fixed
- **Tool Permissions (Non-root Access)**: 
    - Moved the `node` user creation to the base image to ensure availability across all build stages.
    - Relocated **Bun** installation to `/usr/local` (global) to ensure it is executable by the `node` user.
    - Updated **Go toolchain** installation to run under the `node` user with a correctly owned `GOPATH` (`/home/node/go`).
    - Standardized global `PATH` and installation directories for AI Agents (Claude Code, OpenCode, Pi-Mono) to guarantee non-root accessibility.

## [v1.5.1] - 2026-03-13

### Added
- **Image Update Strategy**: Clearly defined the difference between `make install` (fast/local-first) and `make rebuild` (force sync/update) in documentation and FAQ.
- **Image Update FAQ**: Added troubleshooting entries for forcing image updates to the latest remote version.

### Fixed
- **Windows Bulletproof Compatibility**: 
    - Forced UTF-8 encoding across `Makefile` and interactive `onboard` sessions to prevent mojibake/encoding issues.
    - Automated LF line-ending normalization for shell scripts via `.gitattributes` and self-healing scripts.
    - Improved shell environment detection (recommending Git Bash) and enhanced tilde expansion robustness.
    - Resolved `EACCES /Users` permission errors on Windows by switching from host-paths to container-relative paths in `.env` where necessary.
- **Container Resilience**:
    - Forced `0.0.0.0` binding for the gateway to ensure accessible networking across all environments.
    - Fixed `HOME` directory handling for the `node` user in specialized image variants.
    - Improved `onboard` target to be more resilient to non-fatal errors by restoring missing command prefixes.
- **Documentation Integrity**:
    - Audited and removed several "hallucinated" or obsolete commands (e.g., `make update`) from documentation.
    - Synchronized documentation parity between Chinese and English versions.

## [v1.5.0] - 2026-03-12

### Added
- **Pre-Start Config Migration**: Added `openclaw-init` container that runs `openclaw doctor --fix` before gateway starts, preventing "unhealthy container" errors when upgrading from old OpenClaw versions with incompatible config schema.
- **Auto-Cleanup Init Container**: The init container now automatically removes itself after successful config repair, keeping the environment clean.

### Improved
- **Config Migration UX**: Eliminated confusing "Warning: Could not fix permissions" message from entrypoint logs.
- **Startup Reliability**: Gateway now waits for config repair to complete before starting healthcheck, ensuring smooth upgrades.
- **clean-volumes**: Fixed to remove only existing volume references.

## [v1.4.0] - 2026-03-12

### Added
- **1+3 Hierarchical Docker Architecture**: Fully implemented the layered build system (`base` -> `stacks` -> `products`) for optimized cache utilization and build speed.
- **Unified Build Interface**: Refactored `Makefile` with semantic commands (`build-base`, `build-stacks`, `build-go`, etc.) and integrated version tracking.
- **Docker Workflow Guide**: Added comprehensive `docs/DOCKER_WORKFLOW.md` with artifact matrices, build arguments documentation, and troubleshooting tips.

### Improved
- **Container Setup Routine**: Enhanced `docker-setup.sh` with better permission handling and support for the new hierarchical image structure.
- **Documentation Parity**: Synchronized image variant details and artifact paths across all manuals.

## [v1.4.1] - 2026-03-12

### Changed
- **OpenClaw Installation**: Use npm to install OpenClaw CLI instead of install.sh script for better reliability.

## [v1.3.1] - 2026-03-11

### Added
- **Go Variant Documentation**: Comprehensive tool comparison tables in `IMAGE_VARIANTS.md` with runtime, AI agents, Go tools, Python libs, and variant-specific recommended scenarios.
- **Quick Selection Guide**: Added demand-to-variant mapping for easy selection (dev/go/java/office).

### Improved
- **Feishu Integration**: Merged community PR #10 with complete beginner guide in both Chinese and English, including WebSocket troubleshooting.
- **Image Variants Architecture**: Updated 1+3 DRY architecture (dev/go/java/office) with detailed feature matrix.


## [v1.3.0] - 2026-03-11

### Added
- **1+3 Hierarchical Architecture**: Refactored Docker build system into a base image (`Dockerfile.base`) and three specialized variant stacks (Node, Java, Office) to reduce redundancy and improve build speed.
- **Go Variant**: Introduced a dedicated Go language variant (`Dockerfile.go`) integrated into the hierarchical build system.
- **Variant Selection Guide**: Added `docs/IMAGE_VARIANTS.md` for detailed feature comparison between image variants.

### Changed
- **README Refresh**: Updated core features and installation guide to reflect the new hierarchical architecture and Go support.
- **Build System**: Unified variant builds using `make build-<variant>` pattern with automatic base image dependency tracking.

## [v1.2.4] - 2026-03-11

### Added
- **Slack Advanced Setup**: Supplemented the Slack Integration manual and `.env.example` templates with advanced configuration options, including Admin Binding, Mention Mode (`groupPolicy`), and Channel Allowed Lists.

## [v1.2.3] - 2026-03-11

### Fixed
- **Slack Setup Guide**: Fixed hallucinations and outdated manifest configurations in both English and Chinese beginner guides. Removed standalone `slack-manifest.json` as it's now integrated directly into the guides.
- **Deployment Strategy**: Removed deprecated `DEPLOYMENT_STRATEGY.md` document.

## [v1.2.2] - 2026-03-11

### Fixed
- **Docker Permission Fix (macOS)**: Combined `user: "0:0"` (root) with entrypoint `chown` to resolve host-mounted volume permission issues (PR #4).
- **Onboarding Logic**: Updated automatic initialization to use the new `onboard --accept-risk` command flag.

### Improved
- **Smart CI Pipeline**: Enhanced GitHub Actions with path filtering and image-existence checks to skip unnecessary builds.
- **CI Reliability**: Standardized lowercased image names and added concurrency management to prevent redundant workflow runs.
- **Workflow Auditing**: Applied GitHub Actions best practices including Token protection and least-privilege permissions.

## [v1.2.1] - 2026-03-10

### Added
- **Official Onboarding Wizard**: Added `make onboard` command for interactive configuration of LLM, Feishu, and channels.
- **Zero-Config Bootstrap**: The container automatically initializes if configuration is missing on first run.
- **Domestic Mirror Support**: Support for APT (USTC), NPM (Alibaba), and Python (Tsinghua) mirrors via `.env`.
- **Docker Hub Mirroring**: Introduced `DOCKER_MIRROR` variable to handle Docker Hub pull issues in China.
- **Build Quality**: Added Apt retries and fixed Dockerfile multi-stage `ARG` inheritance.

### Fixed
- **Permission Management**: Fixed outdated documentation regarding root permissions; container now runs safely as `node` user (UID 1000).
- **Documentation Parity**: Synchronized technical details and comparison tables between Chinese and English manuals (`README`, `REFERENCE`).

### Changed
- **Feature Highlights**: Updated README with more concise "Out-of-the-Box" and "Secure Isolation" features.

## [v1.1.0] - 2026-03-10

### Added
- **Volume Strategy Documentation**: Comprehensive guide on Named Volumes vs. Bind Mounts, including real-time visibility, permission handling, and performance best practices. Added to `README.md` and `REFERENCE.md`.
- **Environment Configuration**: Added `OPENCLAW_CONFIG_DIR` to `.env.example` for configurable CLI seed paths.

### Changed
- **CLI Service Simplification**: Refactored `openclaw-cli-viking` in `docker-compose.yml` to minimize redundant mounts and utilize unified state volumes.

## [v1.0.7] - 2026-03-09

### Fixed
- **CI/CD Reliability**: Corrected syntax errors in GitHub Actions workflow (`docker-publish.yml`) that prevented CI triggers.
- **Git Hygiene**: Added `openclaw*.json*` to `.gitignore` to prevent accidental tracking of local configuration backups.

## [v1.0.6] - 2026-03-09

### Added
- **GitHub Actions CI/CD**: Added automated multi-architecture Docker build and publish workflow (`amd64`, `arm64`).
- **Multi-Arch Support**: Official support for both Intel/AMD and Apple Silicon (M1/M2/M3) deployments.

### Fixed
- **Infrastructure Consistency**: Fixed Dockerfile naming mismatches between `docker-compose.yml`, `update-source.sh`, and filesystem.
- **Build Robustness**: Enhanced GitHub Actions to explicitly prepare build context by synchronizing DevKit Dockerfiles with source.

### Changed
- **README Update**: Added documentation for multi-architecture distribution and GHCR usage.

## [v1.0.5] - 2026-03-09
- Initial release with integrated toolchain (Node 22, Go 1.26, Python 3.13).
- Added OCR and PDF processing capabilities for Office variant.
