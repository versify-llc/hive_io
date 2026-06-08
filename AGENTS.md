# AGENTS.md

Guide for AI agents working on this repository. Read this before scanning the full codebase.

## Project overview

This is a **maintenance fork** of the abandoned [Hive](https://pub.dev/packages/hive) key-value database for Dart/Flutter. The goal is compatibility with current Dart and Flutter versions — **not new feature development**.

- Published as three separate packages on pub.dev under the [versify-llc/hive_io](https://github.com/versify-llc/hive_io) org
- **No web support** (removed from upstream fork)
- Dart SDK: `^3.8.0`
- Linter: [`package:lint`](https://pub.dev/packages/lint) via each package's `analysis_options.yaml`

## Repository layout

This is a **multi-package monorepo** with no root `pubspec.yaml`. Each package is independent and published separately.

| Package             | Path                 | Role                                                          |
| ------------------- | -------------------- | ------------------------------------------------------------- |
| `hive_io`           | `hive_io/`           | Core key-value store (pure Dart, no Flutter)                  |
| `hive_generator_io` | `hive_generator_io/` | `build_runner` code generator for `@HiveType` adapters        |
| `hive_flutter_io`   | `hive_flutter_io/`   | Flutter helpers (`initFlutter`, `listenable`, extra adapters) |

**Dependency order:** `hive_io` → `hive_generator_io` and `hive_flutter_io` (both depend on `hive_io`).

For local development, `hive_generator_io/pubspec_overrides.yaml` and `hive_flutter_io/pubspec_overrides.yaml` point `hive_io` at `../hive_io`. These files are excluded from publish and only affect local resolution.

## Architecture (`hive_io`)

Start here for most changes:

```
hive_io/lib/
├── hive_io.dart              # Public library entry; exports + `Hive` singleton
└── src/
    ├── hive.dart / hive_impl.dart     # HiveInterface + implementation
    ├── box/                           # Box, LazyBox, Keystore, compaction
    ├── binary/                        # Frame serialization, BinaryReader/Writer
    ├── backend/
    │   ├── storage_backend.dart       # Abstract disk/memory backend
    │   ├── storage_backend_memory.dart
    │   └── vm/                        # VM/desktop/mobile file I/O
    ├── registry/                      # TypeAdapter registration
    ├── crypto/                        # AES-256 encryption (HiveAesCipher)
    ├── adapters/                      # Built-in adapters (DateTime, BigInt)
    ├── object/                        # HiveObject / HiveObjectMixin
    ├── annotations/                   # @HiveType, @HiveField (part files)
    └── io/                            # Buffered file reader/writer
```

**Data flow:** User calls on `Box` → `Keystore` (in-memory index backed by `IndexableSkipList`) → `StorageBackend` persists `Frame` records to `.hive` files on disk.

**Key internal types** (marked "Not part of public API" in source):

- `Frame` — on-disk record (key, value, deleted/lazy flags, byte offset)
- `Keystore` — manages transactions, auto-increment keys, change notifications
- `StorageBackend` / `StorageBackendVm` — file persistence, compaction, crash recovery
- `HiveImpl` — singleton behind the global `Hive` constant

**Platform support:** VM/desktop/mobile only via `backend/vm/`. There is a `backend/stub/` for conditional imports but no web backend.

## Architecture (`hive_generator_io`)

```
hive_generator_io/lib/
├── hive_generator_io.dart    # exports getBuilder()
└── src/
    ├── type_adapter_generator.dart
    ├── builders/             # class_builder, enum_builder
    └── helpers/              # element_helper, type_helper
```

- Registered in `build.yaml` as builder `hive_generator_io`, auto-applied to dependents
- Generates `*.hive_generator_io.g.part` files combined by `source_gen`
- Tests use `build_test` (`test/generator_integration_test.dart`) — not full `build_runner` runs

## Architecture (`hive_flutter_io`)

Thin Flutter layer re-exporting `hive_io` plus:

- `Hive.initFlutter()` — resolves app documents dir via `path_provider`
- `Box.listenable()` — `ValueListenable` for reactive UI
- Optional adapters: `ColorAdapter`, `TimeAdapter` in `lib/adapters.dart`

**Regenerate test fixtures in hive_io** (when frame test data changes):

```bash
cd hive_io && dart run build_runner build --delete-conflicting-outputs
```

Generated test files live in `hive_io/test/generated/*.g.dart`.

## Testing conventions

### `hive_io`

Two test tiers:

1. **Unit tests** — `hive_io/test/tests/` — mirror source layout (`box/`, `binary/`, `crypto/`, etc.)
2. **Integration tests** — `hive_io/test/integration/` — end-to-end box operations, recovery, large payloads

Shared helpers:

- `hive_io/test/tests/common.dart` — temp dirs/files, asset copying, `throwsHiveError` matcher
- `hive_io/test/integration/integration.dart` — `createHive()`, `openBox()` helpers
- `hive_io/test/tests/frames.dart` — binary frame fixtures for recovery/integration tests
- `hive_io/test/assets/` — pre-built `.hive` / `.hivec` files for regression tests

Integration tests use `@TestOn('vm')` and often disable crash recovery (`crashRecovery: false`) for deterministic behavior.

**Mocking:** `mocktail` in `hive_io`; `mockito` in `hive_flutter_io`.

### `hive_generator_io`

- `test/generator_integration_test.dart` — full builder output via `build_test`
- `test/type_adapter_generator_test.dart`, `test/type_helper_test.dart` — unit tests

## Code conventions

- **Public API** is exported from `hive_io.dart` / `hive_flutter_io.dart`. Internal code lives under `src/` and uses `@visibleForTesting` where needed.
- **`part` / `part of`** pattern: annotations and several public-facing types are `part` files of the main library.
- **Match existing style** — minimal diffs, no unnecessary abstractions, comments only for non-obvious logic.
- **Do not commit** generated `.g.dart` files unless they are intentional test fixtures in `hive_io/test/generated/`.
- **Breaking changes** require CHANGELOG entries under `### X.Y.Z` headings and coordinated version bumps across packages.

## Hive domain invariants (do not break)

These are user-facing compatibility constraints:

- `@HiveType(typeId: N)` — type IDs must be unique per app, range **0–223**
- `@HiveField(N)` indices are persisted — never reuse or renumber after data exists; use `defaultValue` for new fields
- Adapters must be `Hive.registerAdapter(...)` **before** opening a box that uses them
- On-disk format (`.hive` files) must remain readable by existing user databases

## Release process

Publish order matters: **`hive_io` first**, then `hive_generator_io` and `hive_flutter_io` after the new `hive_io` version is on pub.dev.

Use the interactive script:

```bash
bash scripts/release.sh
```

It reads versions from each package's `CHANGELOG.md` (`### X.Y.Z`), updates `pubspec.yaml`, README install pins, and dependent `hive_io:` constraints. See `docs/RELEASE.md` for manual steps.

## Guidance for agents

- As agents make changes to this project, they should add or extend tests in the matching tier (unit vs integration) and run the relevant package's test suite before finishing.
- As agents learn more about this project and make changes, they should update this document to be relevant for themselves and other agents in the future.
