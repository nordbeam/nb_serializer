defprotocol NbSerializer.Formatter do
  @moduledoc """
  Protocol for formatting field values during serialization.

  This protocol allows you to define custom formatting behavior for your own types,
  making the serializer extensible without modifying the core library.

  ## Built-in Implementations

  NbSerializer provides implementations for common Elixir types:

    * `DateTime` - Formats to ISO8601 string
    * `NaiveDateTime` - Formats to ISO8601 string
    * `Date` - Formats to ISO8601 string
    * `Decimal` - Formats to string representation
    * `Any` (fallback) - Returns the value unchanged

  ## Defining Custom Formatters

  To add formatting for your custom types, implement this protocol:

      defmodule MyApp.Money do
        defstruct [:amount, :currency]
      end

      defimpl NbSerializer.Formatter, for: MyApp.Money do
        def format(%MyApp.Money{amount: amount, currency: currency}, _opts) do
          "\#{currency}\#{:erlang.float_to_binary(amount / 1.0, decimals: 2)}"
        end
      end

  Now when serializing structs containing Money fields, they'll automatically
  be formatted as currency strings.

  ## Options

  The `format/2` function receives an options keyword list that can be used
  to customize formatting behavior:

      defimpl NbSerializer.Formatter, for: MyApp.Money do
        def format(%MyApp.Money{amount: amount, currency: currency}, opts) do
          precision = Keyword.get(opts, :precision, 2)
          symbol = Keyword.get(opts, :symbol, currency)
          formatted = :erlang.float_to_binary(amount / 1.0, decimals: precision)
          "\#{symbol}\#{formatted}"
        end
      end

  """

  @fallback_to_any true

  @doc """
  Formats a value for serialization.

  ## Parameters

    * `value` - The value to format
    * `opts` - Formatting options (keyword list)

  ## Returns

  The formatted value, typically a string or primitive type suitable for JSON.
  """
  def format(value, opts)
end

# Built-in implementations for common types

defimpl NbSerializer.Formatter, for: DateTime do
  def format(datetime, _opts), do: DateTime.to_iso8601(datetime)
end

defimpl NbSerializer.Formatter, for: NaiveDateTime do
  def format(datetime, _opts), do: NaiveDateTime.to_iso8601(datetime)
end

defimpl NbSerializer.Formatter, for: Date do
  def format(date, _opts), do: Date.to_iso8601(date)
end

if Code.ensure_loaded?(Decimal) do
  defimpl NbSerializer.Formatter, for: Decimal do
    def format(decimal, opts) do
      if Keyword.get(opts, :as_string, true) do
        Decimal.to_string(decimal)
      else
        Decimal.to_float(decimal)
      end
    end
  end
end

defimpl NbSerializer.Formatter, for: Any do
  def format(value, _opts), do: value
end
