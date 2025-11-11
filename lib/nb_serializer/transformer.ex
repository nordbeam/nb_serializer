defprotocol NbSerializer.Transformer do
  @moduledoc """
  Protocol for transforming field values before formatting.

  Transformers are applied before formatters in the serialization pipeline:

      Value → Transform → Format → Output

  This protocol allows you to define custom transformation behavior for your types.

  ## Built-in Implementations

  NbSerializer provides implementations for common types:

    * `String` - Can upcase, downcase, trim, etc.
    * `List` - Can map, filter, sort
    * `Any` (fallback) - Returns value unchanged

  ## Defining Custom Transformers

  Implement this protocol for your custom types:

      defmodule MyApp.Markdown do
        defstruct [:raw]
      end

      defimpl NbSerializer.Transformer, for: MyApp.Markdown do
        def transform(%MyApp.Markdown{raw: raw}, opts) do
          if Keyword.get(opts, :to_html, false) do
            MyApp.Markdown.to_html(raw)
          else
            raw
          end
        end
      end

  ## Transform Options

  The `transform/2` function receives options that control the transformation:

      defimpl NbSerializer.Transformer, for: MyApp.CustomType do
        def transform(value, opts) do
          case Keyword.get(opts, :transform) do
            :normalize -> normalize(value)
            :sanitize -> sanitize(value)
            _ -> value
          end
        end
      end

  """

  @fallback_to_any true

  @doc """
  Transforms a value before formatting.

  ## Parameters

    * `value` - The value to transform
    * `opts` - Transformation options (keyword list)

  ## Returns

  The transformed value.
  """
  def transform(value, opts)
end

defimpl NbSerializer.Transformer, for: BitString do
  def transform(value, opts) do
    value
    |> maybe_upcase(opts)
    |> maybe_downcase(opts)
    |> maybe_trim(opts)
    |> maybe_truncate(opts)
  end

  defp maybe_upcase(value, opts) do
    if Keyword.get(opts, :upcase, false), do: String.upcase(value), else: value
  end

  defp maybe_downcase(value, opts) do
    if Keyword.get(opts, :downcase, false), do: String.downcase(value), else: value
  end

  defp maybe_trim(value, opts) do
    if Keyword.get(opts, :trim, false), do: String.trim(value), else: value
  end

  defp maybe_truncate(value, opts) do
    case Keyword.get(opts, :truncate) do
      nil -> value
      length when is_integer(length) -> String.slice(value, 0, length)
      _ -> value
    end
  end
end

defimpl NbSerializer.Transformer, for: List do
  def transform(value, opts) do
    value
    |> maybe_map(opts)
    |> maybe_filter(opts)
    |> maybe_sort(opts)
    |> maybe_take(opts)
  end

  defp maybe_map(value, opts) do
    case Keyword.get(opts, :map) do
      nil -> value
      fun when is_function(fun, 1) -> Enum.map(value, fun)
      _ -> value
    end
  end

  defp maybe_filter(value, opts) do
    case Keyword.get(opts, :filter) do
      nil -> value
      fun when is_function(fun, 1) -> Enum.filter(value, fun)
      _ -> value
    end
  end

  defp maybe_sort(value, opts) do
    if Keyword.get(opts, :sort, false), do: Enum.sort(value), else: value
  end

  defp maybe_take(value, opts) do
    case Keyword.get(opts, :take) do
      nil -> value
      n when is_integer(n) -> Enum.take(value, n)
      _ -> value
    end
  end
end

defimpl NbSerializer.Transformer, for: Any do
  def transform(value, _opts), do: value
end
