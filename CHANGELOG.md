# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Field selection at call site via `:only` and `:except` options for `serialize/3`
- Registry resilience: clear error message when `NbSerializer.Registry` GenServer is not started
- Depth guard for camelization to prevent stack overflow on deeply nested structures
- Validation and warning for invalid `:within` option values
- Custom error handler documentation (`on_error: :my_handler` with `(error, data, opts)` signature)
- `CHANGELOG.md`

### Changed

- Consolidated duplicate edge case test files into a single `edge_case_test.exs`
- Updated README to reflect that telemetry events are actively emitted (not just infrastructure)
- Documented all `serialize/3` options including `:parallel_threshold`, `:relationship_timeout`, `:only`, and `:except`

### Removed

- Deprecated `NbSerializer.Inertia` module (use `nb_inertia` library instead)
- Deprecated `NbSerializer.TypeScript` module (use `nb_ts` library instead)
- Stale `inertia_test.exs.bak` backup file

## [0.1.0]

### Added

- Initial release
- Declarative DSL for defining serializers (`field`, `has_one`, `has_many`, `belongs_to`)
- Compile-time optimizations via macros
- Required type annotations for all fields
- Phoenix, Ecto, and Plug integrations
- Automatic camelization (snake_case to camelCase)
- Circular reference handling via `:within` and `:max_depth` options
- Stream serialization for large datasets
- Parallel relationship processing
- Telemetry instrumentation
- Auto-discovery via `NbSerializer.Registry`
- Protocol-based extensibility (`NbSerializer.Formatter`, `NbSerializer.Transformer`)
- 8 custom Credo checks for serializer code quality
- `preserve_case/1` for keeping map keys unchanged during camelization
- Namespace support for TypeScript file generation
- Unified field syntax for lists and enums
- Custom TypeScript types via `~TS` sigil
