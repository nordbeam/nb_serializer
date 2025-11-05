# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NbSerializer is a JSON serialization library for Elixir, inspired by the Alba Ruby gem. It provides a declarative DSL for defining serializers with support for computed fields, conditional inclusion, nested associations, and field transformations.

## Key Commands

```bash
# Run tests
mix test

# Run specific test file
mix test test/nb_serializer_test.exs

# Run tests with coverage
mix coveralls

# Format code
mix format

# Install dependencies
mix deps.get

# Run benchmarks
mix run bench/serialization_bench.exs
mix run bench/quick_bench.exs

# Generate documentation
mix docs

# Compile project
mix compile
```

## Architecture

### Core Modules

- **NbSerializer** (`lib/nb_serializer.ex`): Main entry point, provides `serialize/3` and `serialize!/3` functions, handles JSON encoding and response wrapping (root keys, metadata, pagination)

- **NbSerializer.Serializer** (`lib/nb_serializer/serializer.ex`): Provides the DSL macro system via `use NbSerializer.Serializer`, registers module attributes for fields and relationships

- **NbSerializer.Compiler** (`lib/nb_serializer/compiler.ex`): Compiles DSL into efficient runtime functions using `__before_compile__` macro, generates the `__nb_serializer_serialize__/2` function at compile time

- **NbSerializer.DSL** (`lib/nb_serializer/dsl.ex`): Implements DSL macros (`field/2`, `fields/1`, `has_one/2`, `has_many/2`, `schema/1`)

### Integration Modules

- **NbSerializer.Ecto** (`lib/nb_serializer/ecto.ex`): Ecto-specific helpers for handling associations and schemas
- **NbSerializer.Phoenix** (`lib/nb_serializer/phoenix.ex`): Phoenix framework integration for automatic JSON rendering
- **NbSerializer.Plug** (`lib/nb_serializer/plug.ex`): Plug middleware for HTTP serialization

### Support Modules

- **NbSerializer.Formatters** (`lib/nb_serializer/formatters.ex`): Field transformation utilities
- **NbSerializer.ErrorSerializer** (`lib/nb_serializer/error_serializer.ex`): Error response formatting
- **NbSerializer.SerializationError** (`lib/nb_serializer/serialization_error.ex`): Custom exception types

## Design Principles

1. **No Anonymous Functions in DSL**: All functions must be named module functions for compile-time safety
2. **Compile-Time Optimization**: DSL compiles to efficient runtime code via macros
3. **Explicit Field Definition**: Serializers must explicitly define included fields
4. **Required Type Annotations**: All serializer fields MUST have explicit types for TypeScript generation and type safety
5. **Ecto-First Design**: Built-in handling for Ecto associations and schemas

## Type Requirements

**IMPORTANT**: All fields must specify an explicit type. Typeless field definitions will cause a compile-time error.

```elixir
# ❌ WRONG - Will not compile
field :id

# ✅ CORRECT - Explicit type required
field :id, :number
field :name, :string
field :active, :boolean
```

Available types:
- `:string`, `:number`, `:integer`, `:boolean`
- `:decimal`, `:uuid`, `:date`, `:datetime`
- `:any` (for dynamic/flexible content)
- Custom TypeScript types using `~TS` sigil: `type: ~TS"Record<string, any>"`

## Testing Structure

Tests are organized in `test/nb_serializer/` with files for each module. Main test file is `test/nb_serializer_test.exs`.

## Dependencies

- **jason** (~> 1.4): JSON encoding (optional but recommended)
- **ecto** (~> 3.10): Database schema support (optional)
- **phoenix** (~> 1.7): Web framework integration (optional)
- **benchee** (~> 1.3): Performance benchmarking (dev only)
- **excoveralls** (~> 0.18): Test coverage (test only)
