---
name: nb-serializer
description: "Implement, configure, upgrade, diagnose, and verify nb_serializer declarative JSON serializers, type metadata, Phoenix/Ecto integrations, and performance features."
---

# NbSerializer

Use this skill for `nb_serializer` schemas, nested relationships, computed/conditional fields, camelization, custom protocols, streams, Ecto/Phoenix/Plug integration, TypeScript metadata, and serialization errors or performance.

## Discover the target release

- Inspect the target app's `mix.exs`, `mix.lock`, `config/config.exs`, serializer modules, Ecto schemas, Phoenix JSON views/controllers, and any `nb_ts`/frontend output. Read the selected README, installer task, DSL/compiler/config source, and package changelog; the documented feature set and defaults evolve.
- Keep Ecto, Phoenix/Plug, Jason, Igniter, and NbTs optional as the target package defines them. Do not add `nb_ts` or Phoenix merely to use core serialization.

## Install

- Prefer `mix igniter.install nb_serializer` and pass only task-supported flags such as `--with-ecto`, `--with-phoenix`, `--with-typescript`, `--camelize-props`, and `--yes`. If installing manually, add the chosen package source/version, run `mix deps.get`, and configure the namespace from the selected source.
- Review generated config and example serializer. Companion installation may compose `nb_ts`; verify that dependency and output path instead of assuming it succeeded.

## Implement and configure

- Define serializers with `use NbSerializer.Serializer` and explicit field types. Confirm the target DSL spelling for primitives, lists, enums, nested serializers, optional/nullable fields, computed fields, relationships, root/meta data, and field selection before copying examples.
- Treat camelization as an API contract: inspect `:nb_serializer` config and per-call options, and use `preserve_case/1` only where case-sensitive external keys require it. Keep serializer type names/namespaces aligned with generated TypeScript imports.
- Use auto-registration/inferred serialization, `NbSerializer.Phoenix`, Ecto handling, Plug middleware, `within` relationship controls, streams, protocols, parallel relationship loading, and telemetry only when the installed release exports those modules/functions. Prefer explicit serializer calls at integration boundaries.
- Never hide a data-shape error with `:any`; model the contract accurately and choose documented error behavior (`null`, default, skip, or re-raise) deliberately.

## Upgrade or migrate

- Compare locked versions, DSL/compiler output, config defaults, generated TypeScript, Phoenix/Ecto/Jason versions, and release notes before upgrading. Re-run representative serializers and inspect key casing, null/optional behavior, nested relationships, and error handling.
- Migrate generated or inferred registrations carefully: duplicate serializer names, changed module namespaces, and changed field types can break consumers even when Elixir compiles. Preserve app-owned serializers and regenerate dependent types through the current task.
- For performance changes, benchmark representative list/relationship workloads before and after; do not infer a speedup from compile output alone.

## Diagnose and verify

- For compile failures, inspect explicit field types, nested serializer declarations, `from:` fields against the source struct, optional/nullable modifiers, and custom protocol implementations. For runtime errors, inspect the actual struct/map shape, loaded Ecto associations, circular `within` options, and serializer runtime opts.
- For unexpected JSON, check camelization/preserved keys, root/meta configuration, Phoenix view shape, and whether `serialize` returns a tuple that the caller materializes correctly. For slow or memory-heavy output, test streams, relationship loading, and telemetry with production-like data.
- Verify with `mix deps.get`, `mix compile`, `mix test`, serializer unit tests for representative structs/lists/errors/casing, JSON encoding, Phoenix/Ecto integration when enabled, and `mix nb_ts.gen --validate` when type metadata is configured.
- If “latest” is requested, consult current HexDocs/GitHub source for the package and official Phoenix/Ecto/Jason documentation; state the date checked and compare with `mix.lock`.
