# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/). While the version is `0.x`, the API and the document format may still change between releases; each change that affects saved documents is called out explicitly.

## [Unreleased]

### Added
- Floating illustration window (`Window` button) that gives the whole illustration room on screen; closing it returns the canvas to the dock.
- Document `schema_version` field (value `1`), so future format changes can be detected and migrated.
- Headless regression tests: full workflow (regions, cutouts, templates, 2D/3D/perspective exports, save and reopen), window toggling, save-folder creation, and connected walkable zones.
- Project documentation: `docs/SPECIFICATION.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/DECISIONS.md`.
- User guide with installation steps, `docs/USER_GUIDE.md`; development guide, `docs/DEVELOPMENT.md`; data format and compatibility rules, `docs/DATA_FORMAT.md`.
- Repository governance: `CONTRIBUTING.md` (including the policy for AI-assisted contributions), `CODE_OF_CONDUCT.md`, `SECURITY.md`.
- GitHub issue and pull request templates.
- Headless test workflow `.github/workflows/tests.yml`. It installs GdUnit4 6.2.2 and Godot 4.7.1 at pinned versions. It has not yet been run on GitHub.

### Changed
- Walls are no longer generated along edges shared with another walkable zone. Touching zones form a continuous walkable network without being merged.
- Save dialog opens inside the project and creates the target folder when it does not exist.
- User-facing labels in the window are in English.

### Fixed
- The save button opened an *Open* dialog instead of a *Save* dialog (wrong `file_mode`).

## [0.1.0-dev] — development snapshot

### Added
- Illustration import with pan and zoom.
- Polygon regions: create, select, move, vertex insert/remove/move, rename, duplicate, hide, delete, undo and redo.
- Flat region groups.
- Named subtractive cutouts per region (derived with Godot's clipping API).
- Scale templates in image space, persisted and exported as 3D capsules.
- Perspective calibration: camera field of view and transform, virtual floor height, known character height, and camera fit from two or more height references.
- 2D, flat 3D, and perspective scene exports with optional cameras.
- Save and reopen of IWE documents (`.tres`), copying the illustration beside the document.
- Test character with mouse and keyboard movement, walls, and path following.
