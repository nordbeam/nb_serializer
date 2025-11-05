# NbSerializer

A fast and declarative JSON serialization library for Elixir, inspired by Alba for Ruby. NbSerializer provides a powerful DSL for defining serializers with compile-time optimizations, making it both developer-friendly and performant.

## Features

- 🚀 **Compile-time optimizations** - DSL compiles to efficient runtime code
- 🎯 **Declarative DSL** - Clean, readable serializer definitions
- 🔒 **Type safety** - Explicit type annotations required for all fields with compile-time validation
- 🔌 **Framework integration** - Built-in support for Phoenix, Ecto, and Plug
- 🐫 **Automatic camelization** - Convert snake_case to camelCase for JavaScript/TypeScript (configurable)
- 🔄 **Circular reference handling** - Smart detection and prevention of infinite loops
- 📊 **Metadata & Pagination** - Built-in support for API metadata
- 🏗️ **Telemetry ready** - Built-in telemetry events for performance monitoring
- 🛡️ **Error handling** - Comprehensive error management with custom exceptions

## Installation

Add `nb_serializer` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nb_serializer, "~> 0.1.0"}
  ]
end
```

## Quick Start

> **Important**: All fields must have explicit type annotations. Typeless fields will cause a compile-time error. This ensures type safety and enables TypeScript generation.

### Basic Serializer

```elixir
defmodule UserSerializer do
  use NbSerializer.Serializer

  schema do
    field :id, :number
    field :name, :string
    field :email, :string
  end
end

# Usage
user = %{id: 1, name: "John Doe", email: "john@example.com"}
{:ok, result} = NbSerializer.serialize(UserSerializer, user)
# => {:ok, %{id: 1, name: "John Doe", email: "john@example.com"}}

# Direct JSON encoding
json = NbSerializer.to_json!(UserSerializer, user)
# => "{\"id\":1,\"name\":\"John Doe\",\"email\":\"john@example.com\"}"
```

## Field Types

All fields require explicit type annotations. Available types:

| Type | Description | Example |
|------|-------------|---------|
| `:string` | Text values | `field :name, :string` |
| `:number` | Numeric values (int or float) | `field :id, :number` |
| `:integer` | Integer values only | `field :count, :integer` |
| `:boolean` | True/false values | `field :active, :boolean` |
| `:decimal` | Decimal values | `field :price, :decimal` |
| `:uuid` | UUID strings | `field :uuid, :uuid` |
| `:date` | Date values | `field :birthday, :date` |
| `:datetime` | DateTime values | `field :created_at, :datetime` |
| `:any` | Dynamic/flexible content | `field :metadata, :any` |

### Custom TypeScript Types

For advanced TypeScript type generation, use the `~TS` sigil:

```elixir
field :config, type: ~TS"Record<string, any>"
field :metadata, type: ~TS"{ enabled: boolean; count: number }"
```

### Type Modifiers

```elixir
# Nullable fields (can be null)
field :email, :string, nullable: true

# Optional fields (may be omitted from output)
field :phone, :string, optional: true

# List types
field :tags, :string, list: true
field :scores, :number, list: true
```

## Automatic CamelCase Conversion

NbSerializer automatically converts snake_case keys to camelCase to match JavaScript/TypeScript conventions (enabled by default):

```elixir
defmodule UserSerializer do
  use NbSerializer.Serializer

  schema do
    field :user_name, :string
    field :email_address, :string
    field :is_active, :boolean
    field :created_at, :datetime
  end
end

user = %{user_name: "John", email_address: "john@example.com", is_active: true, created_at: "2024-01-01"}
NbSerializer.serialize!(UserSerializer, user)
# => %{userName: "John", emailAddress: "john@example.com", isActive: true, createdAt: "2024-01-01"}
```

**Configuration:**

```elixir
# config/config.exs
config :nb_serializer,
  camelize_props: true  # Default: true
```

Override per-request:

```elixir
# Force camelCase
NbSerializer.serialize(UserSerializer, user, camelize: true)

# Keep snake_case
NbSerializer.serialize(UserSerializer, user, camelize: false)
```

## Advanced Features

### Computed Fields

```elixir
defmodule PostSerializer do
  use NbSerializer.Serializer

  schema do
    field :id, :number
    field :title, :string
    field :excerpt, :string, compute: :generate_excerpt
    field :reading_time, :number, compute: :calculate_reading_time
  end

  def generate_excerpt(%{body: body}, _opts) do
    String.slice(body, 0, 150) <> "..."
  end

  def calculate_reading_time(%{body: body}, _opts) do
    word_count = String.split(body) |> length()
    div(word_count, 200) # Assumes 200 words per minute
  end
end
```

### Relationships

```elixir
defmodule BlogSerializer do
  use NbSerializer.Serializer

  schema do
    field :id, :number
    field :title, :string
    field :body, :string

    has_one :author, serializer: AuthorSerializer
    has_many :comments, serializer: CommentSerializer
    has_many :tags, serializer: TagSerializer, if: :include_tags?
  end

  def include_tags?(_data, opts) do
    opts[:include_tags] == true
  end
end
```

### Conditional Fields

```elixir
defmodule UserDetailSerializer do
  use NbSerializer.Serializer

  schema do
    field :id, :number
    field :name, :string
    field :email, :string, if: :show_email?
    field :admin_notes, :string, if: :is_admin?
    field :private_data, :string, unless: :is_public_view?
  end

  def show_email?(_user, opts) do
    opts[:current_scope] && opts[:current_scope].id == user.id
  end

  def is_admin?(_user, opts) do
    opts[:current_scope] && opts[:current_scope].role == "admin"
  end

  def is_public_view?(_user, opts) do
    opts[:view] == :public
  end
end
```

### Field Transformations

```elixir
defmodule ProductSerializer do
  use NbSerializer.Serializer

  schema do
    field :id, :number
    field :name, :string, transform: :titleize
    field :price, :number, format: :currency
    field :created_at, :datetime, format: :iso8601
    field :sku, :string, transform: :upcase_sku
  end

  def titleize(value) do
    value
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  def upcase_sku(value) do
    String.upcase(value)
  end
end
```

### Circular Reference Handling

```elixir
# Prevent infinite recursion in circular references
NbSerializer.serialize(BookSerializer, book,
  within: [
    author: [books: []],  # Serialize author and their books, but stop there
    comments: [user: []],  # Serialize comments and users, but not user's comments
    tags: []              # Serialize tags with no nested associations
  ]
)

# Set maximum nesting depth
NbSerializer.serialize(PostSerializer, post, max_depth: 3)
```

### Root Keys and Metadata

```elixir
# Add root key
NbSerializer.serialize(UserSerializer, users, root: "users")
# => {:ok, %{"users" => [...]}}

# Add metadata
NbSerializer.serialize(UserSerializer, users,
  root: "users",
  meta: %{version: "1.0", generated_at: DateTime.utc_now()}
)
# => {:ok, %{"users" => [...], "meta" => %{...}}}

# Pagination metadata
NbSerializer.serialize(UserSerializer, users,
  page: 2,
  per_page: 20,
  total: 100
)
# => {:ok, %{data: [...], meta: %{pagination: %{page: 2, per_page: 20, total: 100, total_pages: 5}}}}
```

## Phoenix Integration

### In Phoenix JSON Views (Phoenix 1.7+)

```elixir
defmodule MyAppWeb.UserJSON do
  use NbSerializer.Phoenix

  alias MyApp.Serializers.UserSerializer

  def index(%{users: users}) do
    %{users: render_many(users, UserSerializer)}
  end

  def show(%{user: user}) do
    %{user: render_one(user, UserSerializer)}
  end

  def create(%{user: user}) do
    %{user: render_one(user, UserSerializer, view: :detailed)}
  end

  def error(%{changeset: changeset}) do
    render_errors(changeset)
  end
end
```

### Controller Usage

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    users = Users.list_users()
    render(conn, :index, users: users)
  end

  def show(conn, %{"id" => id}) do
    user = Users.get_user!(id)
    render(conn, :show, user: user)
  end
end
```

## Plug Middleware

Automatically serialize controller assigns:

```elixir
# In your router or controller
plug NbSerializer.Plug,
  serializers: %{
    user: UserSerializer,
    users: UserSerializer,
    post: PostSerializer,
    posts: PostSerializer
  },
  meta: %{api_version: "1.0"},
  cache: true,
  cache_ttl: 300
```

## Ecto Integration

NbSerializer automatically handles Ecto schemas and associations:

```elixir
defmodule PostWithEctoSerializer do
  use NbSerializer.Serializer

  schema do
    field :id, :number
    field :title, :string
    field :body, :string

    # Only serialize if association is loaded
    has_one :author, serializer: AuthorSerializer, if: :author_loaded?
    has_many :comments, serializer: CommentSerializer
  end

  def author_loaded?(post, _opts) do
    # Check if Ecto association is loaded
    NbSerializer.Ecto.loaded?(post.author)
  end
end
```

## Error Handling

NbSerializer provides comprehensive error handling:

```elixir
defmodule SafeSerializer do
  use NbSerializer.Serializer

  schema do
    field :id, :number
    field :name, :string
    # Handle errors gracefully
    field :risky_field, :string, compute: :compute_risky, on_error: :null  # Returns nil on error
    field :important_field, :string, compute: :compute_important, on_error: {:default, "N/A"}  # Returns default value
    field :skippable_field, :string, compute: :compute_skippable, on_error: :skip  # Omits field from output
    field :critical_field, :string, compute: :compute_critical, on_error: :reraise  # Raises SerializationError with context
  end

  def compute_risky(_data, _opts) do
    # This might fail
    raise "Something went wrong"
  end
end
```

## Performance Features

### Performance Monitoring

NbSerializer includes a telemetry module for future performance monitoring integration. While telemetry events are not currently emitted during serialization, the module structure is in place for adding instrumentation.

### Compile-Time Optimizations

The DSL compiles to efficient runtime code:
- No anonymous functions in hot paths
- Optimized field access patterns
- Minimal runtime overhead

## Configuration

```elixir
# config/config.exs
config :nb_serializer,
  encoder: Jason,  # JSON encoder (defaults to Jason if available)
  default_view: :public,
  max_depth: 10
```

## Testing

```bash
# Run tests
mix test

# Run tests with coverage
mix coveralls

# Run benchmarks
mix run bench/serialization_bench.exs
mix run bench/quick_bench.exs
```

## Development

### Project Structure

```
lib/
├── nb_serializer.ex              # Main entry point
├── nb_serializer/
│   ├── serializer.ex       # Core serializer module
│   ├── compiler.ex         # DSL compiler
│   ├── dsl.ex             # DSL macros
│   ├── ecto.ex            # Ecto integration
│   ├── phoenix.ex         # Phoenix integration
│   ├── plug.ex            # Plug middleware
│   ├── formatters.ex      # Built-in formatters
│   ├── telemetry.ex       # Telemetry events
│   └── utils.ex           # Utility functions
```

### Design Principles

1. **No Anonymous Functions in DSL** - All functions must be named module functions for compile-time safety
2. **Compile-Time Optimization** - DSL compiles to efficient runtime code via macros
3. **Explicit Field Definition** - Serializers must explicitly define included fields
4. **Ecto-First Design** - Built-in handling for Ecto associations and schemas

## Related Libraries

NbSerializer focuses on core serialization functionality. TypeScript and Inertia.js integrations have been extracted into separate libraries:

### nb_ts - TypeScript Type Generation

Automatic TypeScript interface generation from NbSerializer schemas:

```elixir
# mix.exs
def deps do
  [
    {:nb_ts, "~> 0.1.0"}
  ]
end
```

Features:
- Generate TypeScript interfaces from serializers
- Support for nullable, arrays, enums, and custom types
- Automatic camelCase conversion
- Runtime type validation with OXC
- Real-time type regeneration during development (via compile hooks)

When nb_ts is installed, serializers automatically trigger TypeScript type regeneration
when recompiled during development. This provides real-time type updates without
manually running `mix nb_ts.gen.types`.

Configure automatic generation in `config/dev.exs`:

```elixir
config :nb_ts,
  output_dir: "assets/js/types",
  auto_generate: true  # Enable real-time type updates (default in dev)
```

See: [github.com/nordbeam/nb_ts](https://github.com/nordbeam/nb_ts)

### nb_inertia - Inertia.js Integration

Seamless Inertia.js integration with automatic serialization:

```elixir
# mix.exs
def deps do
  [
    {:nb_inertia, "~> 0.1.0"}
  ]
end
```

Features:
- Controller helpers for Inertia responses
- Lazy, deferred, and merge props support
- Shared props management
- TypeScript prop type generation
- Automatic camelCase conversion

See: [github.com/nordbeam/nb_inertia](https://github.com/nordbeam/nb_inertia)

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`mix test`)
5. Check code formatting (`mix format`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by [Alba](https://github.com/okuramasafumi/alba) for Ruby
- Built with love for the Elixir community

## Links

- [Documentation](https://hexdocs.pm/nb_serializer)
- [GitHub Repository](https://github.com/yourusername/nb_serializer)
- [Hex Package](https://hex.pm/packages/nb_serializer)
