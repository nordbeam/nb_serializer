# NbSerializer Usage Guide

## What It Does
NbSerializer is a fast JSON serialization library for Elixir with a declarative DSL. It converts Elixir data structures (maps, structs, Ecto schemas) to JSON with compile-time optimizations, automatic camelCase conversion, computed fields, conditional fields, and relationship handling.

## Installation

Add to `mix.exs`:
```elixir
def deps do
  [
    {:nb_serializer, "~> 0.1.0"},
    {:jason, "~> 1.4"}  # JSON encoder (required)
  ]
end
```

## Basic Usage

### Define a Serializer
```elixir
defmodule UserSerializer do
  use NbSerializer.Serializer

  schema do
    field :id, :number
    field :name, :string
    field :email, :string
  end
end
```

### Serialize Data
```elixir
user = %{id: 1, name: "John Doe", email: "john@example.com"}

# Returns {:ok, map}
{:ok, result} = NbSerializer.serialize(UserSerializer, user)

# Returns map or raises
result = NbSerializer.serialize!(UserSerializer, user)

# Returns JSON string
json = NbSerializer.to_json!(UserSerializer, user)
```

## Core Features

### Computed Fields
```elixir
schema do
  field :id, :number
  field :full_name, :string, compute: :build_full_name
end

def build_full_name(%{first: first, last: last}, _opts), do: "#{first} #{last}"
```

### Conditional Fields
```elixir
field :email, :string, if: :show_email?
field :private_data, :string, unless: :is_public?

def show_email?(_data, opts), do: opts[:current_user] != nil
```

### Relationships
```elixir
has_one :author, serializer: AuthorSerializer
has_many :comments, serializer: CommentSerializer, if: :include_comments?
```

### Field Transformations
```elixir
field :name, :string, transform: :upcase_name
field :created_at, :datetime, format: :iso8601

def upcase_name(value), do: String.upcase(value)
```

## Configuration

Global config in `config/config.exs`:
```elixir
config :nb_serializer,
  encoder: Jason,           # JSON encoder
  camelize_props: true      # Auto-convert to camelCase (default: true)
```

Per-request options:
```elixir
NbSerializer.serialize(UserSerializer, user,
  camelize: false,          # Override camelCase setting
  view: :detailed,          # View context
  current_scope: user,      # Authorization scope
  root: "users",            # Wrap in root key
  meta: %{version: "1.0"},  # Add metadata
  page: 1,                  # Pagination
  per_page: 20,
  total: 100,
  max_depth: 5              # Prevent infinite loops
)
```

## Phoenix Integration

```elixir
defmodule MyAppWeb.UserJSON do
  use NbSerializer.Phoenix

  def index(%{users: users}) do
    %{users: render_many(users, UserSerializer)}
  end

  def show(%{user: user}) do
    %{user: render_one(user, UserSerializer)}
  end
end
```

## Key Principles
- **Explicit fields only**: Must define each field to include
- **Named functions**: Use module functions, not anonymous functions
- **Compile-time**: DSL compiles to efficient runtime code
- **CamelCase default**: Keys auto-convert to camelCase for JavaScript/TypeScript
