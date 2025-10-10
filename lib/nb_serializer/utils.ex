defmodule NbSerializer.Utils do
  @moduledoc """
  Utility functions for NbSerializer serialization.
  """

  # Type definitions
  @type data :: map() | struct() | list(map() | struct()) | nil
  @type cardinality :: :one | :many

  @doc """
  Safely accesses map fields with both atom and string keys.

  This function tries to access the value using the provided key,
  and if not found, tries the alternate form (atom <-> string).

  ## Examples

      iex> NbSerializer.Utils.safe_key_access(%{name: "John"}, :name)
      "John"

      iex> NbSerializer.Utils.safe_key_access(%{"name" => "John"}, :name)
      "John"

      iex> NbSerializer.Utils.safe_key_access(%{name: "John"}, "name")
      "John"
  """
  @spec safe_key_access(map(), atom() | binary()) :: any()
  def safe_key_access(data, key) when is_map(data) do
    case Map.fetch(data, key) do
      {:ok, value} ->
        value

      :error ->
        safe_alternate_key_access(data, key)
    end
  end

  defp safe_alternate_key_access(data, key) when is_atom(key) do
    Map.get(data, Atom.to_string(key))
  end

  defp safe_alternate_key_access(data, key) when is_binary(key) do
    # Try to find existing atom without creating new ones
    try do
      atom = String.to_existing_atom(key)
      Map.get(data, atom)
    rescue
      ArgumentError -> nil
    end
  end

  @doc """
  Handles nil and empty values based on cardinality.

  ## Examples

      iex> NbSerializer.Utils.handle_nil_or_empty(nil, :many)
      []

      iex> NbSerializer.Utils.handle_nil_or_empty(nil, :one)
      nil

      iex> NbSerializer.Utils.handle_nil_or_empty([], :many)
      []

      iex> NbSerializer.Utils.handle_nil_or_empty([1, 2, 3], :many)
      [1, 2, 3]
  """
  @spec handle_nil_or_empty(data(), cardinality()) :: data()
  def handle_nil_or_empty(nil, :many), do: []
  def handle_nil_or_empty(nil, :one), do: nil
  def handle_nil_or_empty([], :many), do: []
  def handle_nil_or_empty(%Ecto.Association.NotLoaded{}, :many), do: []
  def handle_nil_or_empty(%Ecto.Association.NotLoaded{}, :one), do: nil
  def handle_nil_or_empty(data, _cardinality), do: data

  @doc """
  Formats error messages with field name interpolation.

  ## Examples

      iex> NbSerializer.Utils.format_error_message("can't be blank", "email")
      "email can't be blank"

      iex> NbSerializer.Utils.format_error_message("%{field} is required", "name")
      "name is required"
  """
  @spec format_error_message(binary(), any()) :: binary()
  def format_error_message(message, nil) when is_binary(message), do: message
  def format_error_message(message, "") when is_binary(message), do: message

  def format_error_message(message, field) when is_binary(message) and is_binary(field) do
    if String.contains?(message, "%{field}") do
      String.replace(message, "%{field}", to_string(field))
    else
      "#{field} #{message}"
    end
  end

  def format_error_message(message, opts) when is_list(opts) and is_binary(message) do
    Enum.reduce(opts, message, fn
      {key, value}, acc when is_atom(key) ->
        String.replace(acc, "%{#{key}}", to_string(value))

      _, acc ->
        acc
    end)
  end

  def format_error_message(message, _), do: to_string(message)
end
