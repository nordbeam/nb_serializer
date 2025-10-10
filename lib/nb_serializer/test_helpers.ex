defmodule NbSerializer.TestHelpers do
  @moduledoc """
  Test helpers for testing NbSerializer serializers.

  This module provides convenient functions for serializing data in tests and making
  assertions about the serialized output.

  ## Usage

  Import this module in your test files or test support modules:

      # In test/serializers/post_serializer_test.exs
      defmodule MyApp.PostSerializerTest do
        use ExUnit.Case

        import NbSerializer.TestHelpers

        test "serializes post" do
          post = build(:post, title: "Hello World", body: "Content here")
          json = serialize!(PostSerializer, post)

          assert_serialized_fields(json, [:id, :title, :excerpt])
          assert_serialized_field(json, :title, "Hello World")
          refute_serialized_field(json, :body)
        end
      end

  ## Helper Functions

  - `serialize!/3` - Serialize data in tests (raises on error)
  - `assert_serialized_fields/2` - Assert that specific fields are present
  - `assert_serialized_field/3` - Assert a specific field value
  - `refute_serialized_field/2` - Assert a field is not present
  - `assert_serialized_structure/2` - Deep structure assertion with nested fields

  ## Examples

      # Basic serialization
      json = serialize!(UserSerializer, user)

      # With options
      json = serialize!(UserSerializer, user, view: :detailed)

      # Assert fields present
      assert_serialized_fields(json, [:id, :name, :email])

      # Assert specific values
      assert_serialized_field(json, :name, "John Doe")
      assert_serialized_field(json, :email, "john@example.com")

      # Assert field not present (e.g., password)
      refute_serialized_field(json, :password)

      # Assert deep structure
      assert_serialized_structure(json, %{
        id: 1,
        name: "John Doe",
        profile: %{
          bio: "Developer",
          location: "NYC"
        }
      })
  """

  import ExUnit.Assertions

  @doc """
  Serializes data using the given serializer (raises on error).

  This is a convenience wrapper around `NbSerializer.serialize!/3` that's
  optimized for testing.

  ## Examples

      json = serialize!(UserSerializer, user)
      json = serialize!(PostSerializer, posts, view: :detailed)
  """
  @spec serialize!(module(), any(), keyword()) :: map() | list(map())
  def serialize!(serializer, data, opts \\ []) do
    NbSerializer.serialize!(serializer, data, opts)
  end

  @doc """
  Asserts that specific fields are present in the serialized output.

  This checks that the keys exist but doesn't validate their values. Works with
  both atom and string keys, and handles camelCase/snake_case conversions.

  ## Examples

      assert_serialized_fields(json, [:id, :title, :excerpt])
      assert_serialized_fields(json, ["id", "title", "excerpt"])
      assert_serialized_fields(json, [:userId, :totalCount])  # camelCase
  """
  @spec assert_serialized_fields(map(), list(atom() | String.t())) :: true
  def assert_serialized_fields(serialized, expected_fields) when is_map(serialized) do
    serialized_keys = Map.keys(serialized) |> Enum.map(&to_field_key/1) |> MapSet.new()
    expected_keys = Enum.map(expected_fields, &to_field_key/1)

    missing_keys =
      expected_keys
      |> Enum.reject(fn key ->
        MapSet.member?(serialized_keys, key) || find_alternate_field_key(serialized, key) != nil
      end)

    assert Enum.empty?(missing_keys),
           """
           Expected fields #{inspect(expected_fields)} to be present, but missing: #{inspect(missing_keys)}.

           Available fields: #{inspect(Map.keys(serialized))}
           """

    true
  end

  def assert_serialized_fields(serialized, _expected_fields) when is_list(serialized) do
    flunk("""
    assert_serialized_fields/2 expects a map, but got a list.

    If you serialized a list of items, use Enum.each or test individual items:

        json = serialize!(MySerializer, items)
        Enum.each(json, fn item ->
          assert_serialized_fields(item, [:id, :name])
        end)
    """)
  end

  @doc """
  Asserts that a specific field has the expected value.

  Works with both atom and string keys, and handles camelCase/snake_case conversions.

  ## Examples

      assert_serialized_field(json, :title, "Hello World")
      assert_serialized_field(json, :user_id, 42)
      assert_serialized_field(json, :userId, 42)  # camelCase also works
  """
  @spec assert_serialized_field(map(), atom() | String.t(), any()) :: true
  def assert_serialized_field(serialized, field_key, expected_value)
      when is_map(serialized) do
    field_key = to_field_key(field_key)

    actual_value =
      case Map.fetch(serialized, field_key) do
        {:ok, value} ->
          value

        :error ->
          # Try the other case (atom vs string or camelCase vs snake_case)
          alternate_key = find_alternate_field_key(serialized, field_key)

          case alternate_key do
            nil ->
              flunk("""
              Field #{inspect(field_key)} not found in serialized output.

              Available fields: #{inspect(Map.keys(serialized))}
              """)

            key ->
              Map.fetch!(serialized, key)
          end
      end

    assert actual_value == expected_value,
           """
           Expected field #{inspect(field_key)} to equal #{inspect(expected_value)}, but got #{inspect(actual_value)}.
           """

    true
  end

  def assert_serialized_field(serialized, _field_key, _expected_value)
      when is_list(serialized) do
    flunk("""
    assert_serialized_field/3 expects a map, but got a list.

    If you serialized a list of items, access individual items first:

        json = serialize!(MySerializer, items)
        assert_serialized_field(List.first(json), :id, 1)
    """)
  end

  @doc """
  Asserts that a specific field is NOT present in the serialized output.

  Useful for ensuring sensitive data (like passwords) or internal fields
  are not included in the serialization.

  ## Examples

      refute_serialized_field(json, :password)
      refute_serialized_field(json, :internal_notes)
  """
  @spec refute_serialized_field(map(), atom() | String.t()) :: true
  def refute_serialized_field(serialized, field_key) when is_map(serialized) do
    field_key = to_field_key(field_key)

    has_field =
      Map.has_key?(serialized, field_key) ||
        find_alternate_field_key(serialized, field_key) != nil

    refute has_field,
           """
           Expected field #{inspect(field_key)} to NOT be present, but it was found.

           Serialized: #{inspect(serialized)}
           """

    true
  end

  def refute_serialized_field(serialized, _field_key) when is_list(serialized) do
    flunk("""
    refute_serialized_field/2 expects a map, but got a list.

    If you serialized a list of items, test individual items:

        json = serialize!(MySerializer, items)
        Enum.each(json, fn item ->
          refute_serialized_field(item, :password)
        end)
    """)
  end

  @doc """
  Asserts that the serialized output matches the expected structure.

  This performs a deep comparison and is useful for testing nested serializers
  and complex data structures.

  ## Examples

      assert_serialized_structure(json, %{
        id: 1,
        name: "John Doe",
        email: "john@example.com"
      })

      # Nested structures
      assert_serialized_structure(json, %{
        id: 1,
        name: "John",
        profile: %{
          bio: "Developer",
          location: "NYC"
        },
        posts: [
          %{id: 1, title: "First Post"},
          %{id: 2, title: "Second Post"}
        ]
      })

      # Partial matching - only checks specified fields
      assert_serialized_structure(json, %{
        id: 1,
        name: "John"
      })
      # Other fields in json are ignored
  """
  @spec assert_serialized_structure(map() | list(), map() | list()) :: true
  def assert_serialized_structure(serialized, expected)
      when is_map(serialized) and is_map(expected) do
    Enum.each(expected, fn {key, expected_value} ->
      key = to_field_key(key)

      actual_value =
        case Map.fetch(serialized, key) do
          {:ok, value} ->
            value

          :error ->
            alternate_key = find_alternate_field_key(serialized, key)

            case alternate_key do
              nil ->
                flunk("""
                Field #{inspect(key)} not found in serialized output.

                Available fields: #{inspect(Map.keys(serialized))}
                """)

              alt_key ->
                Map.fetch!(serialized, alt_key)
            end
        end

      case {actual_value, expected_value} do
        {actual, expected} when is_map(actual) and is_map(expected) ->
          assert_serialized_structure(actual, expected)

        {actual, expected} when is_list(actual) and is_list(expected) ->
          assert_serialized_structure(actual, expected)

        {actual, expected} ->
          assert actual == expected,
                 """
                 Expected field #{inspect(key)} to equal #{inspect(expected)}, but got #{inspect(actual)}.
                 """
      end
    end)

    true
  end

  def assert_serialized_structure(serialized, expected)
      when is_list(serialized) and is_list(expected) do
    assert length(serialized) == length(expected),
           """
           Expected list to have #{length(expected)} items, but got #{length(serialized)}.
           """

    Enum.zip(serialized, expected)
    |> Enum.with_index()
    |> Enum.each(fn {{actual_item, expected_item}, index} ->
      try do
        assert_serialized_structure(actual_item, expected_item)
      rescue
        e in ExUnit.AssertionError ->
          flunk("""
          Assertion failed at list index #{index}:

          #{Exception.message(e)}
          """)
      end
    end)

    true
  end

  def assert_serialized_structure(serialized, expected) do
    assert serialized == expected,
           """
           Expected serialized output to match structure, but got different values.

           Expected: #{inspect(expected)}
           Got: #{inspect(serialized)}
           """

    true
  end

  # Private helpers

  defp to_field_key(key) when is_atom(key), do: key
  defp to_field_key(key) when is_binary(key), do: key
  defp to_field_key(key), do: to_string(key)

  # Try to find the field key in alternate forms (atom/string, camelCase/snake_case)
  defp find_alternate_field_key(serialized, field_key) when is_atom(field_key) do
    string_key = Atom.to_string(field_key)
    snake_key = camel_to_snake(string_key)
    camel_key = snake_to_camel(string_key)

    cond do
      Map.has_key?(serialized, string_key) ->
        string_key

      Map.has_key?(serialized, camel_key) ->
        camel_key

      Map.has_key?(serialized, String.to_atom(camel_key)) ->
        String.to_atom(camel_key)

      Map.has_key?(serialized, snake_key) ->
        snake_key

      Map.has_key?(serialized, String.to_atom(snake_key)) ->
        String.to_atom(snake_key)

      true ->
        nil
    end
  end

  defp find_alternate_field_key(serialized, field_key) when is_binary(field_key) do
    atom_key =
      try do
        String.to_existing_atom(field_key)
      rescue
        ArgumentError -> nil
      end

    snake_key = camel_to_snake(field_key)

    cond do
      atom_key && Map.has_key?(serialized, atom_key) ->
        atom_key

      Map.has_key?(serialized, snake_key) ->
        snake_key

      true ->
        nil
    end
  end

  defp snake_to_camel(string) do
    string
    |> String.split("_")
    |> Enum.with_index()
    |> Enum.map_join(fn
      {word, 0} -> word
      {word, _} -> String.capitalize(word)
    end)
  end

  defp camel_to_snake(string) do
    string
    |> String.replace(~r/([A-Z])/, "_\\1")
    |> String.downcase()
    |> String.trim_leading("_")
  end
end
