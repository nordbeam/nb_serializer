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
- 🔍 **Auto-discovery** - Automatic serializer registration and inference
- 🌊 **Stream support** - Memory-efficient streaming for large datasets
- 🔌 **Protocol-based extensibility** - Extend formatting and transformation for custom types
- ⚡ **Parallel processing** - Automatic parallelization of relationship loading
- ✅ **Compile-time validation** - Struct field validation at compile time

## Installation

Add `nb_serializer` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nb_serializer, github: "nordbeam/nb_serializer"}
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

### Auto-Registration (New in 0.2.0)

Use the `:for` option to automatically register a serializer for a struct type:

```elixir
defmodule UserSerializer do
  use NbSerializer.Serializer, for: User  # Auto-register for User struct

  schema do
    field :id, :number
    field :name, :string
    field :email, :string
  end
end

# Now you can use inferred serialization
user = %User{id: 1, name: "Alice", email: "alice@example.com"}
NbSerializer.serialize_inferred!(user)
# => %{id: 1, name: "Alice", email: "alice@example.com"}
# Automatically uses UserSerializer!
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
```

### Lists and Collections

The unified syntax supports typed lists, including lists of primitives, enums, and serializers:

```elixir
# Lists of primitives
field :tags, list: :string          # TypeScript: string[]
field :scores, list: :number        # TypeScript: number[]
field :flags, list: :boolean        # TypeScript: boolean[]

# Lists of serializers (nested objects)
field :users, list: UserSerializer  # TypeScript: User[]
field :items, list: ItemSerializer  # TypeScript: Item[]

# Lists can be optional
field :notes, list: :string, optional: true  # TypeScript: notes?: string[]
```

### Enums

Define fields with restricted values using enums:

```elixir
# Simple enum
field :status, enum: ["active", "inactive", "pending"]
# TypeScript: status: "active" | "inactive" | "pending"

# Optional enum
field :priority, enum: ["low", "medium", "high"], optional: true
# TypeScript: priority?: "low" | "medium" | "high"

# Nullable enum
field :category, enum: ["news", "blog", "update"], nullable: true
# TypeScript: category: "news" | "blog" | "update" | null

# List of enums
field :roles, list: [enum: ["admin", "user", "guest"]]
# TypeScript: roles: ("admin" | "user" | "guest")[]
```

### Complete Example with All Field Types

```elixir
defmodule ProductSerializer do
  use NbSerializer.Serializer

  schema do
    # Primitives
    field :id, :number
    field :name, :string
    field :active, :boolean

    # Lists of primitives
    field :tags, list: :string
    field :scores, list: :number

    # Enums
    field :status, enum: ["draft", "published", "archived"]
    field :priority, enum: ["low", "high"], optional: true

    # List of enums
    field :categories, list: [enum: ["electronics", "books", "clothing"]]

    # Nested serializers
    field :users, list: UserSerializer
    field :config, serializer: ConfigSerializer

    # Optional and nullable
    field :description, :string, optional: true
    field :metadata, :any, nullable: true
  end
end
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

### Serializer Auto-Discovery

The serializer registry allows automatic discovery of serializers based on struct types.

```elixir
# Register a serializer for a struct type
defmodule UserSerializer do
  use NbSerializer.Serializer, for: User  # Auto-registers at compile time

  schema do
    field :id, :number
    field :name, :string
  end
end

# Inferred serialization - no need to specify serializer
user = %User{id: 1, name: "Alice"}
{:ok, result} = NbSerializer.serialize_inferred(user)

# Works with lists too
users = [%User{id: 1}, %User{id: 2}]
NbSerializer.serialize_inferred!(users)

# Manual registration
NbSerializer.Registry.register(Post, PostSerializer)
```

### Stream Serialization

Efficiently serialize large datasets without loading everything into memory:

```elixir
# Stream from database
users_query
|> Repo.stream()
|> NbSerializer.serialize_stream(UserSerializer)
|> Stream.map(&NbSerializer.encode!/1)
|> Stream.into(File.stream!("users.jsonl"))
|> Stream.run()

# With inferred serializers
posts
|> Stream.map(&load_associations/1)
|> NbSerializer.serialize_stream_inferred(view: :detailed)
|> Enum.to_list()

# Process in chunks
large_dataset
|> NbSerializer.serialize_stream(ItemSerializer, chunk_size: 100)
|> Stream.each(&process_chunk/1)
|> Stream.run()
```

### Protocol-Based Extensibility

Extend formatting and transformation for your custom types using protocols:

```elixir
# Define a custom type
defmodule Money do
  defstruct [:amount, :currency]
end

# Implement the Formatter protocol
defimpl NbSerializer.Formatter, for: Money do
  def format(%Money{amount: amount, currency: currency}, opts) do
    precision = Keyword.get(opts, :precision, 2)
    symbol = Keyword.get(opts, :symbol, currency)
    formatted = :erlang.float_to_binary(amount / 1.0, decimals: precision)
    "#{symbol}#{formatted}"
  end
end

# Now Money values are automatically formatted
defmodule ProductSerializer do
  use NbSerializer.Serializer

  schema do
    field :id, :number
    field :name, :string
    field :price, :any  # Will use Money's formatter when use_protocol: true
  end
end

product = %{id: 1, name: "Widget", price: %Money{amount: 19.99, currency: "USD"}}
NbSerializer.serialize!(ProductSerializer, product, use_protocol: true)
# => %{id: 1, name: "Widget", price: "$19.99"}
```

**Available Protocols:**
- `NbSerializer.Formatter` - Format values for output (DateTime, Date, Decimal, custom types)
- `NbSerializer.Transformer` - Transform values before formatting (String, List, custom types)

**Note:** Protocols are opt-in via `use_protocol: true` option to maintain backwards compatibility.

### Compile-Time Struct Validation

Validate struct fields at compile time to catch errors early:

```elixir
defmodule UserSerializer do
  use NbSerializer.Serializer, for: User  # Automatically enables validation

  schema do
    field :id, :number
    field :full_name, :string, from: :name  # Validates :name exists in User struct
    field :contact, :string, from: :email   # Validates :email exists in User struct
  end
end

# If User struct doesn't have a :name field, you'll get a compile warning:
# warning: Field `full_name` uses `from: :name` but :name does not exist in User
```

### Better Circular Reference Handling

Use the improved `within` syntax for cleaner circular reference management:

```elixir
import NbSerializer.Within

# Path-based syntax
NbSerializer.serialize(post, within: build([
  ~w(author books)a,
  ~w(author posts)a,
  ~w(comments user posts)a
]))

# Generate from serializer relationships
within_opts = Within.from_serializer(PostSerializer)
NbSerializer.serialize(post, within: within_opts)

# Merge multiple within options
within1 = [author: [books: []]]
within2 = [author: [posts: []], comments: []]
merged = Within.merge(within1, within2)
# => [author: [books: [], posts: []], comments: []]
```

### Parallel Relationship Loading

Relationships are automatically processed in parallel when there are 3 or more:

```elixir
defmodule PostSerializer do
  use NbSerializer.Serializer

  schema do
    field :id, :number
    field :title, :string

    # These 4 relationships will be loaded in parallel
    has_one :author, AuthorSerializer
    has_many :comments, CommentSerializer
    has_many :tags, TagSerializer
    has_many :categories, CategorySerializer
  end
end

# Parallel loading happens automatically
NbSerializer.serialize!(PostSerializer, post)

# Configure the threshold
NbSerializer.serialize!(PostSerializer, post,
  parallel_threshold: 2,  # Start parallel at 2 relationships
  relationship_timeout: 30_000  # Timeout per relationship
)

# Use System.schedulers_online() for max concurrency
```

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
  camelize_props: true,  # Auto-convert to camelCase (default: true)
  default_view: :public,
  max_depth: 10

# config/dev.exs
config :nb_serializer,
  # Enable compile-time struct field validation warnings
  validate_struct_fields: true  # default: true in dev/test
```

### Serialization Options

All serialization functions accept these options:

```elixir
NbSerializer.serialize(UserSerializer, user,
  # Circular reference control
  within: [author: [books: []]],
  max_depth: 5,

  # Protocol-based formatting (opt-in)
  use_protocol: true,

  # Parallel relationship loading
  parallel_threshold: 3,
  relationship_timeout: 30_000,

  # View and scope
  view: :detailed,
  current_scope: current_user,

  # Output formatting
  camelize: true,
  root: "users",
  meta: %{version: "1.0"},

  # Pagination
  page: 1,
  per_page: 20,
  total: 100
)
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
5. **Protocol-Based Extensibility** - Use Elixir protocols for custom type formatting
6. **Idiomatic Elixir** - Follows Elixir best practices (behaviours, protocols, function capturing, `with` statements)
7. **Performance-Conscious** - Automatic parallelization, streaming support, and efficient compilation

## Related Libraries

NbSerializer focuses on core serialization functionality. TypeScript and Inertia.js integrations have been extracted into separate libraries:

### nb_ts - TypeScript Type Generation

Automatic TypeScript interface generation from NbSerializer schemas:

```elixir
# mix.exs
def deps do
  [
    {:nb_ts, github: "nordbeam/nb_ts"}
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
    {:nb_inertia, github: "nordbeam/nb_inertia"}
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
