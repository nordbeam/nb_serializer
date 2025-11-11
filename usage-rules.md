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

### Auto-Registration (New in 0.2.0)
```elixir
# Register serializer for a struct type
defmodule UserSerializer do
  use NbSerializer.Serializer, for: User  # Auto-registers at compile time

  schema do
    field :id, :number
    field :name, :string
  end
end

# Now use inferred serialization
user = %User{id: 1, name: "Alice"}
NbSerializer.serialize_inferred!(user)  # Finds UserSerializer automatically
```

### Serialize Data
```elixir
user = %{id: 1, name: "John Doe", email: "john@example.com"}

# Standard serialization
{:ok, result} = NbSerializer.serialize(UserSerializer, user)
result = NbSerializer.serialize!(UserSerializer, user)

# Inferred serialization (with :for option)
{:ok, result} = NbSerializer.serialize_inferred(user)
result = NbSerializer.serialize_inferred!(user)

# JSON encoding
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

# Relationships with 3+ are automatically parallelized for better performance
```

### Field Transformations
```elixir
field :name, :string, transform: :upcase_name
field :created_at, :datetime, format: :iso8601

def upcase_name(value), do: String.upcase(value)
```

### Compile-Time Validation
```elixir
# Validate struct fields at compile time
defmodule UserSerializer do
  use NbSerializer.Serializer, for: User

  schema do
    field :full_name, :string, from: :name  # Warns if :name doesn't exist in User
  end
end
```

### Stream Serialization
```elixir
# Memory-efficient streaming for large datasets
users_query
|> Repo.stream()
|> NbSerializer.serialize_stream(UserSerializer)
|> Stream.into(File.stream!("users.jsonl"))
|> Stream.run()

# With inferred serializers
posts |> NbSerializer.serialize_stream_inferred() |> Enum.to_list()
```

### Protocol-Based Extensibility
```elixir
# Extend formatting for custom types
defimpl NbSerializer.Formatter, for: Money do
  def format(%Money{amount: amt, currency: cur}, _opts) do
    "#{cur}#{:erlang.float_to_binary(amt / 1.0, decimals: 2)}"
  end
end

# Use with use_protocol: true
NbSerializer.serialize!(ProductSerializer, product, use_protocol: true)
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
  # Output formatting
  camelize: false,          # Override camelCase setting
  root: "users",            # Wrap in root key
  meta: %{version: "1.0"},  # Add metadata

  # View and authorization
  view: :detailed,          # View context
  current_scope: user,      # Authorization scope

  # Pagination
  page: 1,
  per_page: 20,
  total: 100,

  # Circular reference control
  within: [author: [books: []]],  # Or use NbSerializer.Within helpers
  max_depth: 5,

  # Performance options
  use_protocol: true,       # Enable protocol-based formatting
  parallel_threshold: 3,    # Parallelize when ≥3 relationships
  relationship_timeout: 30_000
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

## Advanced Features

### Better Circular Reference Handling
```elixir
import NbSerializer.Within

# Path-based syntax
NbSerializer.serialize(post, within: build([
  ~w(author books)a,
  ~w(comments user)a
]))

# Generate from serializer
within_opts = Within.from_serializer(PostSerializer)
```

### Parallel Relationship Loading
```elixir
# Automatically parallelizes when ≥3 relationships
defmodule PostSerializer do
  use NbSerializer.Serializer

  schema do
    field :id, :number
    has_one :author, AuthorSerializer
    has_many :comments, CommentSerializer
    has_many :tags, TagSerializer
    has_many :categories, CategorySerializer  # Triggers parallel processing
  end
end

# Configure threshold
NbSerializer.serialize!(PostSerializer, post, parallel_threshold: 2)
```

## Key Principles
- **Explicit fields only**: Must define each field to include
- **Named functions**: Use module functions, not anonymous functions
- **Compile-time**: DSL compiles to efficient runtime code with validation
- **CamelCase default**: Keys auto-convert to camelCase for JavaScript/TypeScript
- **Protocol-based**: Extend formatting/transformation via Elixir protocols
- **Performance-conscious**: Automatic parallelization and streaming support
