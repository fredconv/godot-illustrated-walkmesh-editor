# Contributing to IWE

Thank you for helping. IWE is an early-stage Godot 4 editor plugin, so the most useful contributions right now are clear bug reports, reproducible steps, and small, tested changes.

## Before you start

- Read [`docs/SPECIFICATION.md`](docs/SPECIFICATION.md) to see what is implemented, partially implemented, and planned.
- Check [`docs/ROADMAP.md`](docs/ROADMAP.md) before proposing a feature. Features in the roadmap are planned in a specific order; please discuss larger changes in an issue first.
- Set up a local environment with [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md).

## Reporting bugs

Use the bug report template. Include:

- Godot version and operating system.
- The exact steps, and what you expected versus what happened.
- A screenshot or short recording when the problem is visual.
- The output panel messages (IWE errors start with `IWE:`).

## Proposing features

Use the feature request template. Explain the problem first, then the proposed behaviour. Say whether it changes saved documents; those changes need a schema version note (see `docs/DATA_FORMAT.md`).

## Pull requests

1. Create a branch from `develop`.
2. Keep each pull request focused on one change.
3. Add or update tests in `tests/` for any behaviour change. Headless tests must pass (see `docs/DEVELOPMENT.md`).
4. For UI changes that cannot run headless, describe the manual check you performed in the pull request.
5. Update `CHANGELOG.md` under `[Unreleased]`.
6. Update the documentation that your change affects. Do not describe a feature as available until it is implemented and tested.
7. Use the pull request template.

## AI-assisted contributions

AI-assisted contributions are welcome. The project itself is developed with the help of an AI coding assistant (Claude Code), so this is not a barrier to contributing.

If you used an AI tool to write or change code, documentation, or tests:

- **You are responsible for the result.** Read every line you submit and be able to explain it.
- **Test it.** Run the headless test suite and, for interface changes, check the behaviour in the Godot editor. Describe the manual check in the pull request.
- **Verify the claims.** Do not submit documentation that describes a feature as available unless you have run it.
- **Keep changes focused.** Large generated changes without review are hard to maintain; please split them.
- **Mention it in the pull request** if AI tools did a substantial part of the work. This helps reviewers know where to look more carefully.

Pull requests that show no evidence of review or testing may be asked for changes before they are considered.

## Code style

- GDScript follows the standard Godot style guide; use tabs for indentation, as the existing code does.
- Keep geometry and data code free of editor APIs where possible, so it can run headless.
- Write comments in English.
- Do not add dependencies without discussing them first. Check the licence of any third-party code before using it.

## Licence

By contributing, you agree that your contribution is licensed under the MIT Licence of this project.
