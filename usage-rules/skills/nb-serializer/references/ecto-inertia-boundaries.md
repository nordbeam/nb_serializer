# Ecto, Inertia, and contract boundaries

Read this reference when an `nb_serializer` task crosses an Ecto association,
an Inertia prop, or generated TypeScript metadata. The examples use the current
package contracts; inspect the target release's source and lockfile before
copying them into an application.

## Verified core contracts

These contracts are verified in the current `nb_serializer` source and tests:

- `NbSerializer.serialize/2` and `/3` (implemented as
  `NbSerializer.serialize(serializer, data, opts \\ [])`) return
  `{:ok, serialized}` or `{:error, %NbSerializer.SerializationError{}}`.
  `serialize!/3` unwraps the success value or raises.
- Camelization is enabled by default by the package configuration. Passing
  `camelize: true` makes snake-case output keys such as `author_id` and
  `primary_reviewer` become `authorId` and `primaryReviewer`, including nested
  maps. Pass the option explicitly in contract tests so the intended wire shape
  is visible even when a test helper changes global configuration.
- A computed field or relationship callback is a named function with the
  signature `compute_name(data, opts)` (arity 2). The compiler validates that
  arity and passes the serializer options through.
- `use NbSerializer.Ecto` normalizes Ecto structs before the compiled serializer
  runs and removes `__meta__`. A relationship with `on_missing: :null` maps a
  nil or `Ecto.Association.NotLoaded` one-to-one value to `nil`; `nullable: true`
  records that wire shape in the serializer type metadata.

## Concrete Ecto serializer

This example keeps a computed nullable association separate from the stored
`author_id` field. The output relationship is intentionally named
`primary_reviewer` so its camelized wire key is easy to spot.

```elixir
defmodule MyApp.Blog.Author do
  use Ecto.Schema

  schema "authors" do
    field :name, :string
  end
end

defmodule MyApp.Blog.Post do
  use Ecto.Schema

  schema "posts" do
    field :title, :string
    belongs_to :author, MyApp.Blog.Author
  end
end

defmodule MyApp.Blog.AuthorSerializer do
  use NbSerializer.Serializer
  use NbSerializer.Ecto

  schema do
    field :id, :integer
    field :name, :string
    field :display_name, :string, compute: :display_name
  end

  def display_name(%{name: name}, _opts), do: name
end

defmodule MyApp.Blog.PostSerializer do
  use NbSerializer.Serializer
  use NbSerializer.Ecto

  schema do
    field :id, :integer
    field :title, :string
    field :author_id, :integer

    has_one :primary_reviewer,
      serializer: MyApp.Blog.AuthorSerializer,
      compute: :primary_reviewer,
      nullable: true,
      on_missing: :null
  end

  def primary_reviewer(%{author: author}, _opts), do: author
end
```

The corresponding focused assertions should check both the result envelope and
the wire keys:

```elixir
author = %MyApp.Blog.Author{id: 10, name: "Ada"}
post = %MyApp.Blog.Post{id: 1, title: "Typed JSON", author_id: 10, author: author}

assert {:ok, result} =
         NbSerializer.serialize(MyApp.Blog.PostSerializer, post, camelize: true)

assert result == %{
         id: 1,
         title: "Typed JSON",
         authorId: 10,
         primaryReviewer: %{id: 10, name: "Ada", displayName: "Ada"}
       }

unloaded = %MyApp.Blog.Post{id: 2, title: "No reviewer"}
assert {:ok, %{primaryReviewer: nil}} =
         NbSerializer.serialize(MyApp.Blog.PostSerializer, unloaded, camelize: true)
```

The callback may use the second argument for options, for example
`def display_name(data, opts)` and `Keyword.get(opts, :locale)`. Do not change
it to a one-argument callback; that fails the compile-time contract.

## Explicit NbInertia boundary and typed props

For a controller/page task, route to the `nb-inertia` skill for page DSL,
rendering, and prop lifecycle details. Its explicit serializer boundary looks
like this:

```elixir
defmodule MyAppWeb.PostController do
  use MyAppWeb, :controller
  use NbInertia.Controller

  inertia_page :index do
    prop :posts, list_of(ref(MyApp.Blog.PostSerializer))
    prop :featured_post, nullable(ref(MyApp.Blog.PostSerializer))
  end

  def index(conn, _params) do
    render_inertia(conn, :index,
      posts: serialize(MyApp.Blog.PostSerializer, Posts.list()),
      featured_post: serialize(MyApp.Blog.PostSerializer, Posts.featured())
    )
  end
end
```

`NbInertia.Controller.serialize/2` returns `{Serializer, value}` (and
`{Serializer, value, opts}` when options are supplied). NbInertia's prop
materializer then delegates to the serializer and handles its
`{:ok, serialized}` result. Do not pass that result tuple directly as the page
prop and do not manually pre-serialize it when using this boundary. For
TypeScript discovery, generated types, or validation, route to the `nb-ts`
skill and inspect the generated output rather than hand-editing it.

## Recovery when global generation is noisy

If `mix compile` or a global NbTs generation command fails in unrelated modules,
keep the original failure visible and report the affected module. Use a focused
serializer module/test or the target generator to isolate the contract under
change, then fix the causal source. Do not disable warnings-as-errors or type
validation, delete unrelated generated files, or swallow errors merely to make
the overall command pass.
