# Security Policy

## Supported versions

IWE is pre-release software (`0.x`). Only the latest release and the `main` branch receive fixes.

## Reporting a vulnerability

Please do not open a public issue for security problems.

Report them privately with GitHub's *Security → Report a vulnerability* feature on the repository. Include:

- The IWE version or commit.
- Godot version and operating system.
- Steps to reproduce, and the expected impact.

You can expect an acknowledgement within a reasonable time. Fixes are released with a changelog entry, and the reporter is credited unless they prefer not to be.

## Scope

IWE runs as an editor plugin and reads and writes Godot resource files (`.tres`) and scene files (`.tscn`) inside the project. Reports about loading untrusted resource files are welcome.
