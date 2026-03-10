# Changelog

All notable changes to this project will be documented in this file.

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
