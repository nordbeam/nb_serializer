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
    * `:include` - List of associations to include
    * `:exclude` - List of fields to exclude
    * `:root` - Root key to wrap the serialized data
    * `:meta` - Metadata to include in the response
    * `:page` - Current page number (adds pagination metadata)
    * `:per_page` - Items per page (adds pagination metadata)
    * `:total` - Total items count (adds pagination metadata)
    * `:within` - Control which associations to serialize (see Circular References below)
    * `:max_depth` - Maximum nesting depth to prevent infinite recursion (default: 10)
    * `:camelize` - Convert keys to camelCase (default: uses config, falls back to `true`)

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

  # Camelization support

  defp maybe_camelize(serialized, opts) do
    should_camelize =
      case Keyword.get(opts, :camelize) do
        nil -> NbSerializer.Config.camelize_props?()
        value -> value
      end

    if should_camelize do
      camelize_keys(serialized)
    else
      serialized
    end
  end

  defp camelize_keys(data) when is_map(data) do
    data
    |> Enum.map(fn {key, value} ->
      {camelize_key(key), camelize_keys(value)}
    end)
    |> Map.new()
  end

  defp camelize_keys(data) when is_list(data) do
    Enum.map(data, &camelize_keys/1)
  end

  defp camelize_keys(data), do: data

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
    |> Enum.map_join(fn
      # First word stays lowercase
      {word, 0} -> word
      # Rest are capitalized
      {word, _} -> String.capitalize(word)
    end)
  end
end
