# Changelog

All notable changes to slipway are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- **`make slipway-check` ignores `.DS_Store`**: the file Finder leaves in a folder it has shown is no longer reported as an addition to the copy.

## [0.1.1] — 2026-11-01

- **`make slipway-update` is quiet**: git's detached-HEAD notice and its warning about the annotated tag no longer bury the result; they show only when the fetch fails.

## [0.1.0] — 2026-11-01

The first version, gathered from the release lanes of the projects that used to carry their own copy.

- **Any mix of iOS, macOS and watchOS**, from `slipway.yml`: the build targets, the release scope and the help follow the platforms a project declares. A watch app ships inside the iOS app.
- **The release lane**, with every fix the copies had between them: retried GitHub calls and a dropped CI watch that doesn't count as a failure, tags mirrored from origin, the version heading written on a version bump (in the project's own heading style), the version asked on every release, a prompt before releasing code without notes, and an opaque-icon check.
- **Export options written at export time**, with the team from `project.yml`, instead of a per-project plist.
- **A pinned per-project copy**: `install.sh`, `make slipway-update` and `make slipway-check`.
- **`make help` merges the project's targets** with slipway's by section, and lists only the targets for platforms the project builds.
