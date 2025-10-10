defmodule NbSerializer.FormatterRegistry do
  @moduledoc """
  Registry for built-in formatters.

  Provides a centralized way to apply formatters to values,
  simplifying the formatter dispatch logic.
  """

  @formatters %{
    currency: {NbSerializer.Formatters, :currency},
    iso8601: {NbSerializer.Formatters, :iso8601},
    datetime: {NbSerializer.Formatters, :iso8601},
    date: {NbSerializer.Formatters, :iso8601},
    time: {NbSerializer.Formatters, :iso8601},
    number: {NbSerializer.Formatters, :number},
    boolean: {NbSerializer.Formatters, :boolean},
    downcase: {NbSerializer.Formatters, :downcase},
    upcase: {NbSerializer.Formatters, :upcase},
    parameterize: {NbSerializer.Formatters, :parameterize}
  }

  @doc """
  Applies a formatter to a value with optional arguments.

  ## Examples

      iex> NbSerializer.FormatterRegistry.apply_formatter(:currency, 100, "USD")
      "$100.00"

      iex> NbSerializer.FormatterRegistry.apply_formatter(:boolean, true, nil)
      "Yes"
  """
  def apply_formatter(format, value, arg) do
    case @formatters[format] do
      nil ->
        raise ArgumentError, "Unknown formatter: #{inspect(format)}"

      {module, function} ->
        apply_formatter_with_args(module, function, value, arg, format)
    end
  end

  @doc """
  Checks if a formatter is registered.

  ## Examples

      iex> NbSerializer.FormatterRegistry.has_formatter?(:currency)
      true

      iex> NbSerializer.FormatterRegistry.has_formatter?(:unknown)
      false
  """
  def has_formatter?(format) do
    Map.has_key?(@formatters, format)
  end

  @doc """
  Returns all registered formatter names.
  """
  def registered_formatters do
    Map.keys(@formatters)
  end

  # Private helpers

  defp apply_formatter_with_args(module, function, value, arg, format_key) do
    # Special handling for formatters with optional args
    # Use format_key if provided, otherwise use function name
    case {format_key || function, arg} do
      {:currency, nil} ->
        apply(module, function, [value])

      {:currency, []} ->
        apply(module, function, [value])

      {:currency, arg} when is_binary(arg) ->
        apply(module, function, [value, arg])

      {:datetime, format} when is_binary(format) ->
        # For datetime formatter, we need to use the datetime function with format
        if function == :iso8601 do
          # If it's the iso8601 function being used for datetime, use Formatters.datetime instead
          apply(NbSerializer.Formatters, :datetime, [value, format])
        else
          apply(module, function, [value, format])
        end

      {:number, opts} when is_list(opts) or is_map(opts) ->
        apply(module, function, [value, opts])

      {_, nil} ->
        # Most formatters just take a single value argument
        apply(module, function, [value])

      {_, []} ->
        # Empty list also means no arguments
        apply(module, function, [value])

      _ ->
        # Try with arg if function accepts 2 params
        if function_exported?(module, function, 2) do
          apply(module, function, [value, arg])
        else
          apply(module, function, [value])
        end
    end
  end
end
