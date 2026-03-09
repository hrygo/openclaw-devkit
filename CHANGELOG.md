# Changelog

All notable changes to this project will be documented in this file.

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
