defmodule NbSerializer.Formatters do
  @moduledoc """
  Built-in formatters for common data types.

  These formatters can be used with the `format:` option in field definitions
  or called directly in custom format functions.
  """

  @doc """
  Formats a number as currency.

  ## Examples

      iex> NbSerializer.Formatters.currency(19.99)
      "$19.99"

      iex> NbSerializer.Formatters.currency(19.99, "€")
      "€19.99"
  """
  def currency(value, symbol \\ "$")

  def currency(value, symbol) when is_number(value) do
    formatted = :erlang.float_to_binary(value / 1.0, decimals: 2)
    "#{symbol}#{formatted}"
  end

  def currency(value, _symbol) do
    raise ArgumentError, "Expected a number for currency formatting, got: #{inspect(value)}"
  end

  @doc """
  Formats a datetime to ISO8601 string.

  ## Examples

      iex> NbSerializer.Formatters.iso8601(~U[2024-01-15 10:30:00Z])
      "2024-01-15T10:30:00Z"
  """
  def iso8601(%DateTime{} = datetime) do
    DateTime.to_iso8601(datetime)
  end

  def iso8601(%NaiveDateTime{} = datetime) do
    NaiveDateTime.to_iso8601(datetime)
  end

  def iso8601(%Date{} = date) do
    Date.to_iso8601(date)
  end

  def iso8601(value) do
    raise ArgumentError,
          "Expected a DateTime, NaiveDateTime, or Date for ISO8601 formatting, got: #{inspect(value)}"
  end

  @doc """
  Formats a datetime with a custom format string.

  ## Examples

      iex> NbSerializer.Formatters.datetime(~U[2024-01-15 10:30:00Z], "%Y-%m-%d %H:%M:%S")
      "2024-01-15 10:30:00"
  """
  def datetime(datetime, format) when is_binary(format) do
    case datetime do
      %DateTime{} = dt ->
        Calendar.strftime(dt, format)

      %NaiveDateTime{} = dt ->
        Calendar.strftime(dt, format)

      _ ->
        raise ArgumentError, "Expected a DateTime or NaiveDateTime, got: #{inspect(datetime)}"
    end
  end

  @doc """
  Formats a number with specified precision.

  ## Examples

      iex> NbSerializer.Formatters.number(85.4567, precision: 2)
      "85.46"

      iex> NbSerializer.Formatters.number(4.86, precision: 1)
      "4.9"
  """
  def number(value, opts \\ [])

  def number(value, opts) when is_number(value) do
    precision = opts[:precision] || 2
    formatted = :erlang.float_to_binary(value / 1.0, decimals: precision)
    to_string(formatted)
  end

  def number(value, _opts) do
    raise ArgumentError, "Expected a number for number formatting, got: #{inspect(value)}"
  end

  @doc """
  Converts various truthy/falsy values to boolean.

  ## Examples

      iex> NbSerializer.Formatters.boolean(1)
      true

      iex> NbSerializer.Formatters.boolean(0)
      false

      iex> NbSerializer.Formatters.boolean("true")
      true
  """
  def boolean(value) when value in [true, "true", "TRUE", "True", "1", 1, "yes", "YES"], do: true

  def boolean(value)
      when value in [false, "false", "FALSE", "False", "0", 0, "no", "NO", nil, ""],
      do: false

  def boolean(value), do: !!value

  @doc """
  Converts a string to lowercase.

  ## Examples

      iex> NbSerializer.Formatters.downcase("HELLO")
      "hello"
  """
  def downcase(value) when is_binary(value), do: String.downcase(value)
  def downcase(value), do: value |> to_string() |> String.downcase()

  @doc """
  Converts a string to uppercase.

  ## Examples

      iex> NbSerializer.Formatters.upcase("hello")
      "HELLO"
  """
  def upcase(value) when is_binary(value), do: String.upcase(value)
  def upcase(value), do: value |> to_string() |> String.upcase()

  @doc """
  Converts a string to a URL-safe slug.

  ## Examples

      iex> NbSerializer.Formatters.parameterize("Hello World!")
      "hello-world"
  """
  def parameterize(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end

  def parameterize(value), do: value |> to_string() |> parameterize()
end
