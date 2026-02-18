defmodule NbSerializer do
  @moduledoc """
  NbSerializer is a fast and simple JSON serializer for Elixir inspired by Alba for Ruby.

  ## Basic Usage

      defmodule UserSerializer do
        use NbSerializer.Serializer

        schema do
          field :id, :number
          field :name, :string
          field :email, :string
        end
      end

      user = %{id: 1, name: "John Doe", email: "john@example.com"}
      NbSerializer.serialize(UserSerializer, user)
      # => {:ok, %{id: 1, name: "John Doe", email: "john@example.com"}}

      NbSerializer.serialize!(UserSerializer, user)
      # => %{id: 1, name: "John Doe", email: "john@example.com"}

  ## Testing

  NbSerializer provides test helpers to make testing serializers straightforward.
  Import `NbSerializer.TestHelpers` in your test files:

      defmodule MyApp.UserSerializerTest do
        use ExUnit.Case

        import NbSerializer.TestHelpers

        test "serializes user" do
          user = build(:user, name: "Alice", email: "alice@example.com")
          json = serialize!(UserSerializer, user)

          assert_serialized_fields(json, [:id, :name, :email])
          assert_serialized_field(json, :name, "Alice")
          refute_serialized_field(json, :password)
        end

        test "validates nested structure" do
          post = build(:post, title: "Hello", user: build(:user))
          json = serialize!(PostSerializer, post)

          assert_serialized_structure(json, %{
            id: 1,
            title: "Hello",
            user: %{
              id: 1,
              name: "Alice"
            }
          })
        end
      end

  Available test helpers:

  - `serialize!/3` - Serialize data in tests (raises on error)
  - `assert_serialized_fields/2` - Assert specific fields are present
  - `assert_serialized_field/3` - Assert a field has a specific value
  - `refute_serialized_field/2` - Assert a field is not present
  - `assert_serialized_structure/2` - Deep structure assertion

  See `NbSerializer.TestHelpers` for full documentation.
  """

  # Type definitions
  @type serializer :: module()
  @type data :: map() | struct() | list(map() | struct())
  @type opts :: keyword()
  @type serialized :: map()
  @type json_string :: binary()

  @doc """
  Serializes data using the given serializer module.

  Returns a map representation of the data.

  ## Options

    * `:view` - The view context for conditional serialization
    * `:current_scope` - The authorization scope for permission checks (user, organization, API client, etc.)
    * `:only` - List of field names to include (e.g., `only: [:id, :name]`). Mutually exclusive with `:except`
    * `:except` - List of field names to exclude (e.g., `except: [:email]`). Mutually exclusive with `:only`
    * `:include` - List of associations to include
    * `:exclude` - List of associations to exclude
    * `:root` - Root key to wrap the serialized data
    * `:meta` - Metadata to include in the response
    * `:page` - Current page number (adds pagination metadata)
    * `:per_page` - Items per page (adds pagination metadata)
    * `:total` - Total items count (adds pagination metadata)
    * `:within` - Control which associations to serialize (see Circular References below)
    * `:max_depth` - Maximum nesting depth to prevent infinite recursion (default: 10)
    * `:camelize` - Convert keys to camelCase (default: uses config, falls back to `true`)
    * `:parallel_threshold` - Minimum number of relationships to trigger parallel processing (default: 3)
    * `:relationship_timeout` - Timeout in ms for parallel relationship processing (default: 30,000)

  ## Circular References

  Use the `:within` option to control which associations are serialized, preventing
  infinite recursion in circular references. Uses Elixir keyword lists:

      # Serialize author and their books, but stop there
      NbSerializer.serialize(BookSerializer, book, within: [author: [books: []]])

      # Multiple associations with different depths
      NbSerializer.serialize(PostSerializer, post, within: [
        author: [posts: []],
        comments: [user: []],
        tags: []
      ])

      # Mixed syntax: plain atoms mean "serialize with no nested associations"
      NbSerializer.serialize(PostSerializer, post, within: [:author, comments: [:user]])

  ## Examples

      NbSerializer.serialize(UserSerializer, user)
      NbSerializer.serialize(UserSerializer, users, view: :detailed)
      NbSerializer.serialize(UserSerializer, users, root: "users", meta: %{version: "1.0"})
  """
  @spec serialize(serializer(), data(), opts()) :: {:ok, serialized()} | {:error, term()}
  def serialize(serializer, data, opts \\ []) do
    NbSerializer.Telemetry.execute_serialize(serializer, data, opts, fn ->
      try do
        serialized = serializer.serialize(data, opts)

        # Apply camelization if configured
        serialized = maybe_camelize(serialized, opts)

        result = wrap_response(serialized, data, opts)
        {:ok, result}
      rescue
        e in NbSerializer.SerializationError ->
          {:error, e}

        e ->
          {:error,
           %NbSerializer.SerializationError{message: Exception.message(e), original_error: e}}
      end
    end)
  end

  @doc """
  Serializes data using the given serializer module (bang version).

  Returns a map representation or raises on error.

  ## Examples

      NbSerializer.serialize!(UserSerializer, user)
      # => %{id: 1, name: "John Doe"}
  """
  @spec serialize!(serializer(), data(), opts()) :: serialized() | no_return()
  def serialize!(serializer, data, opts \\ []) do
    case serialize(serializer, data, opts) do
      {:ok, result} -> result
      {:error, %NbSerializer.SerializationError{} = error} -> raise error
      {:error, reason} -> raise NbSerializer.SerializationError, message: inspect(reason)
    end
  end

  @doc """
  Serializes data and encodes it to JSON.

  Returns {:ok, json_string} or {:error, reason}.

  ## Examples

      NbSerializer.to_json(UserSerializer, user)
      # => {:ok, "{\"id\":1,\"name\":\"John Doe\"}"}
  """
  @spec to_json(serializer(), data(), opts()) :: {:ok, json_string()} | {:error, term()}
  def to_json(serializer, data, opts \\ []) do
    case serialize(serializer, data, opts) do
      {:ok, serialized} -> encode(serialized)
      error -> error
    end
  end

  @doc """
  Serializes data and encodes it to JSON (bang version).

  Returns a JSON string or raises on error.

  ## Examples

      NbSerializer.to_json!(UserSerializer, user)
      # => "{\"id\":1,\"name\":\"John Doe\"}"
  """
  @spec to_json!(serializer(), data(), opts()) :: json_string() | no_return()
  def to_json!(serializer, data, opts \\ []) do
    case to_json(serializer, data, opts) do
      {:ok, json} -> json
      {:error, %NbSerializer.SerializationError{} = error} -> raise error
      {:error, reason} -> raise NbSerializer.SerializationError, message: inspect(reason)
    end
  end

  @doc """
  Encodes a map to JSON using the configured encoder.

  Returns {:ok, json_string} or {:error, reason}.
  """
  @spec encode(serialized()) :: {:ok, json_string()} | {:error, term()}
  def encode(data) do
    try do
      {:ok, encoder().encode!(data)}
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Encodes a map to JSON using the configured encoder (bang version).

  Returns a JSON string or raises on error.
  """
  @spec encode!(serialized()) :: json_string() | no_return()
  def encode!(data) do
    encoder().encode!(data)
  end

  @doc """
  Serializes data using an inferred serializer from the registry.

  Looks up the appropriate serializer based on the struct type and uses it
  for serialization. The serializer must be registered using the `:for` option
  or manually via `NbSerializer.Registry.register/2`.

  Returns `{:ok, serialized}` or `{:error, reason}`.

  ## Examples

      defmodule UserSerializer do
        use NbSerializer.Serializer, for: User

        schema do
          field :id, :number
          field :name, :string
        end
      end

      user = %User{id: 1, name: "Alice"}
      NbSerializer.serialize_inferred(user)
      # => {:ok, %{id: 1, name: "Alice"}}

  """
  @spec serialize_inferred(struct(), opts()) :: {:ok, serialized()} | {:error, term()}
  def serialize_inferred(data, opts \\ [])

  def serialize_inferred(data, opts) when is_struct(data) do
    case NbSerializer.Registry.lookup(data) do
      {:ok, serializer} ->
        serialize(serializer, data, opts)

      {:error, :registry_not_started} ->
        {:error,
         %NbSerializer.SerializationError{
           message:
             "NbSerializer.Registry is not started. " <>
               "Add NbSerializer.Registry to your application supervision tree:\n\n" <>
               "    children = [\n" <>
               "      NbSerializer.Registry,\n" <>
               "      # ... other children\n" <>
               "    ]"
         }}

      {:error, :not_found} ->
        {:error,
         %NbSerializer.SerializationError{
           message:
             "No serializer registered for #{inspect(data.__struct__)}. " <>
               "Use `use NbSerializer.Serializer, for: #{inspect(data.__struct__)}` " <>
               "or register manually with NbSerializer.Registry.register/2"
         }}
    end
  end

  def serialize_inferred(data, _opts) when not is_struct(data) do
    {:error,
     %NbSerializer.SerializationError{
       message: "serialize_inferred/2 requires a struct, got: #{inspect(data)}"
     }}
  end

  @doc """
  Serializes data using an inferred serializer from the registry (bang version).

  Like `serialize_inferred/2` but raises on error.

  ## Examples

      user = %User{id: 1, name: "Alice"}
      NbSerializer.serialize_inferred!(user)
      # => %{id: 1, name: "Alice"}

  """
  @spec serialize_inferred!(struct(), opts()) :: serialized() | no_return()
  def serialize_inferred!(data, opts \\ []) do
    case serialize_inferred(data, opts) do
      {:ok, result} -> result
      {:error, %NbSerializer.SerializationError{} = error} -> raise error
      {:error, reason} -> raise NbSerializer.SerializationError, message: inspect(reason)
    end
  end

  @doc """
  Creates a stream that serializes items lazily.

  This is useful for serializing large collections without loading everything
  into memory at once. The stream can be piped to other Stream functions or
  enumerated as needed.

  ## Options

  Same options as `serialize/3`, plus:

    * `:chunk_size` - Number of items to serialize per chunk (default: 100)

  ## Examples

      # Serialize a stream of users
      users_query
      |> Repo.stream()
      |> NbSerializer.serialize_stream(UserSerializer)
      |> Stream.map(&encode_to_json/1)
      |> Stream.into(File.stream!("users.jsonl"))
      |> Stream.run()

      # With options
      posts
      |> Stream.map(&load_associations/1)
      |> NbSerializer.serialize_stream(PostSerializer, view: :detailed)
      |> Enum.to_list()

  """
  @spec serialize_stream(serializer(), Enumerable.t(), opts()) :: Enumerable.t()
  def serialize_stream(serializer, stream, opts \\ []) do
    Stream.map(stream, &serialize!(serializer, &1, opts))
  end

  @doc """
  Creates a stream that serializes items lazily using inferred serializers.

  Like `serialize_stream/3` but automatically infers the serializer from
  each struct's type.

  ## Examples

      users
      |> NbSerializer.serialize_stream_inferred()
      |> Enum.to_list()

  """
  @spec serialize_stream_inferred(Enumerable.t(), opts()) :: Enumerable.t()
  def serialize_stream_inferred(stream, opts \\ []) do
    Stream.map(stream, &serialize_inferred!(&1, opts))
  end

  @doc """
  Returns the configured JSON encoder module.
  """
  @spec encoder() :: module()
  def encoder do
    Application.get_env(:nb_serializer, :encoder) || default_encoder()
  end

  defp default_encoder do
    cond do
      Code.ensure_loaded?(Jason) -> Jason
      Code.ensure_loaded?(Poison) -> Poison
      true -> raise "No JSON encoder found. Please add :jason to your dependencies."
    end
  end

  @doc false
  @spec wrap_response(serialized(), data(), opts()) :: serialized()
  def wrap_response(serialized, original_data, opts) do
    # Build the response structure step by step
    opts = build_metadata(opts, original_data)

    cond do
      # If we have both root and meta, structure them at same level
      opts[:root] && opts[:meta] ->
        %{
          to_key(opts[:root]) => serialized,
          to_key("meta") => opts[:meta]
        }

      # If we only have root
      opts[:root] ->
        %{to_key(opts[:root]) => serialized}

      # If we only have meta (no root)
      opts[:meta] ->
        %{data: serialized, meta: opts[:meta]}

      # No wrapping needed
      true ->
        serialized
    end
  end

  defp build_metadata(opts, original_data) do
    opts
    |> add_pagination_metadata()
    |> resolve_meta_function(original_data)
  end

  defp add_pagination_metadata(opts) do
    if opts[:page] && opts[:per_page] do
      pagination = build_pagination_map(opts)
      meta = Map.merge(opts[:meta] || %{}, %{pagination: pagination})
      Keyword.put(opts, :meta, meta)
    else
      opts
    end
  end

  defp build_pagination_map(opts) do
    base = %{
      page: opts[:page],
      per_page: opts[:per_page]
    }

    if opts[:total] do
      Map.merge(base, %{
        total: opts[:total],
        total_pages: div(opts[:total] - 1, opts[:per_page]) + 1
      })
    else
      base
    end
  end

  defp resolve_meta_function(opts, original_data) do
    case opts[:meta] do
      meta when is_function(meta, 2) ->
        Keyword.put(opts, :meta, meta.(original_data, opts))

      _ ->
        opts
    end
  end

  defp to_key(key) when is_atom(key), do: key
  defp to_key(key) when is_binary(key), do: key
  defp to_key(key), do: to_string(key)

  @doc """
  Wraps a key to preserve its case during camelization.

  When serializing maps, keys are normally converted from snake_case to camelCase.
  Use this function to prevent camelization of specific keys - useful for identifiers
  like airport codes (RTM, BRU), currency codes (USD, EUR), or other literal string keys.

  ## Examples

      # In a custom serializer that handles a map of airports by code:
      defmodule AirportsSerializer do
        import NbSerializer, only: [preserve_case: 1]

        def serialize(airports, opts) when is_map(airports) do
          Map.new(airports, fn {code, airport} ->
            {preserve_case(code), AirportSerializer.serialize(airport, opts)}
          end)
        end
      end

      # Results in:
      %{
        "RTM" => %{code: "RTM", name: "Rotterdam..."},  # Key preserved
        "BRU" => %{code: "BRU", name: "Brussels..."}    # Key preserved
      }

      # Without preserve_case, keys would be camelized:
      %{
        "rTM" => ...,  # Incorrectly camelized
        "bRU" => ...   # Incorrectly camelized
      }
  """
  @spec preserve_case(atom() | String.t()) :: {:preserve, atom() | String.t()}
  def preserve_case(key) when is_atom(key) or is_binary(key) do
    {:preserve, key}
  end

  # Camelization support

  @camelize_max_depth 64

  defp maybe_camelize(serialized, opts) do
    should_camelize =
      case Keyword.get(opts, :camelize) do
        nil -> NbSerializer.Config.camelize_props?()
        value -> value
      end

    if should_camelize do
      camelize_keys(serialized, 0)
    else
      serialized
    end
  end

  defp camelize_keys(data, depth) when is_map(data) and depth < @camelize_max_depth do
    data
    |> Enum.map(fn {key, value} ->
      {camelize_key(key), camelize_keys(value, depth + 1)}
    end)
    |> Map.new()
  end

  defp camelize_keys(data, depth) when is_list(data) and depth < @camelize_max_depth do
    Enum.map(data, &camelize_keys(&1, depth + 1))
  end

  defp camelize_keys(data, _depth), do: data

  # Handle {:preserve, key} - unwrap and keep key as-is
  defp camelize_key({:preserve, key}), do: key

  defp camelize_key(key) when is_atom(key) do
    key
    |> Atom.to_string()
    |> camelize_string()
    |> String.to_atom()
  end

  defp camelize_key(key) when is_binary(key) do
    camelize_string(key)
  end

  defp camelize_key(key), do: key

  defp camelize_string(string) do
    string
    |> String.split("_")
    |> Enum.with_index()
    |> Enum.map_join(&camelize_word/1)
  end

  # First word stays lowercase
  defp camelize_word({word, 0}), do: word
  # Rest are capitalized
  defp camelize_word({word, _}), do: String.capitalize(word)
end
