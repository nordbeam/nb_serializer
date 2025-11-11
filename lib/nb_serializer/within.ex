defmodule NbSerializer.Within do
  @moduledoc """
  Helper module for building `within` options with improved syntax.

  The `within` option controls which associations are serialized to prevent
  circular references and infinite recursion. This module provides helpers
  to build `within` options more ergonomically.

  ## Traditional Syntax

  The traditional way uses nested keyword lists:

      NbSerializer.serialize(post, within: [
        author: [books: [], posts: []],
        comments: [user: [posts: []]]
      ])

  ## Path-Based Syntax

  This module provides a cleaner path-based syntax:

      import NbSerializer.Within

      NbSerializer.serialize(post, within: build([
        path([:author, :books]),
        path([:author, :posts]),
        path([:comments, :user, :posts])
      ]))

  ## Using Sigil

  For even more concise syntax, use the `~W` sigil:

      import NbSerializer.Within

      NbSerializer.serialize(post, within: build([
        ~w(author books)a,
        ~w(author posts)a,
        ~w(comments user posts)a
      ]))

  ## All Associations

  To serialize all top-level associations without nesting:

      within: build(:all)
      # Same as: within: [author: [], posts: [], comments: []]

  ## Depth Limiting

  To serialize up to a certain depth:

      within: build(depth: 2)

  """

  @doc """
  Builds a `within` option from a list of paths or special keywords.

  ## Examples

      iex> NbSerializer.Within.build([[:author, :books], [:comments, :user]])
      [author: [books: []], comments: [user: []]]

      iex> NbSerializer.Within.build([~w(author posts)a])
      [author: [posts: []]]

      iex> NbSerializer.Within.build(:all)
      :all

      iex> NbSerializer.Within.build(depth: 3)
      [depth: 3]

  """
  @spec build([list(atom())] | atom() | keyword()) :: keyword() | atom()
  def build(:all), do: :all

  def build(depth: depth) when is_integer(depth) and depth > 0 do
    [depth: depth]
  end

  def build(paths) when is_list(paths) do
    paths
    |> Enum.map(&normalize_path/1)
    |> Enum.reduce([], &merge_path/2)
  end

  @doc """
  Creates a path from a list of association names.

  ## Examples

      iex> NbSerializer.Within.path([:author, :books])
      [:author, :books]

      iex> NbSerializer.Within.path(~w(comments user)a)
      [:comments, :user]

  """
  @spec path(list(atom())) :: list(atom())
  def path(associations) when is_list(associations) do
    associations
  end

  # Private functions

  defp normalize_path(path) when is_list(path) and length(path) > 0 do
    path
  end

  defp normalize_path(path) do
    raise ArgumentError,
          "Path must be a non-empty list of atoms, got: #{inspect(path)}"
  end

  defp merge_path([head | []], acc) do
    # Last element in path, add empty list if not exists
    case Keyword.get(acc, head) do
      nil -> Keyword.put(acc, head, [])
      existing when is_list(existing) -> acc
      _ -> Keyword.put(acc, head, [])
    end
  end

  defp merge_path([head | tail], acc) do
    existing = Keyword.get(acc, head, [])

    nested =
      if is_list(existing) do
        merge_path(tail, existing)
      else
        merge_path(tail, [])
      end

    Keyword.put(acc, head, nested)
  end

  defp merge_path([], acc), do: acc

  @doc """
  Converts a serializer module's associations to a `within` keyword list
  that allows one level of nesting.

  Useful for automatically generating `within` options based on a serializer's
  defined relationships.

  ## Examples

      iex> NbSerializer.Within.from_serializer(PostSerializer)
      [author: [], comments: [], tags: []]

  """
  @spec from_serializer(module()) :: keyword()
  def from_serializer(serializer) when is_atom(serializer) do
    if function_exported?(serializer, :__nb_serializer_relationships__, 0) do
      serializer.__nb_serializer_relationships__()
      |> Enum.map(fn {_type, name, _opts} -> {name, []} end)
    else
      []
    end
  end

  @doc """
  Merges multiple `within` options into a single combined option.

  Useful when you need to combine `within` options from different sources.

  ## Examples

      iex> NbSerializer.Within.merge(
      ...>   [author: [books: []]],
      ...>   [author: [posts: []], comments: []]
      ...> )
      [author: [books: [], posts: []], comments: []]

  """
  @spec merge(keyword(), keyword()) :: keyword()
  def merge(within1, within2) when is_list(within1) and is_list(within2) do
    Keyword.merge(within1, within2, fn _key, v1, v2 ->
      cond do
        is_list(v1) and is_list(v2) -> merge(v1, v2)
        is_list(v1) -> v1
        is_list(v2) -> v2
        true -> []
      end
    end)
  end

  def merge(within1, _within2), do: within1
end
