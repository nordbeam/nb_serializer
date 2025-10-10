defmodule NbSerializer.FormatterRegistryTest do
  use ExUnit.Case, async: true

  alias NbSerializer.FormatterRegistry

  describe "apply_formatter/3" do
    test "applies currency formatter with argument" do
      assert FormatterRegistry.apply_formatter(:currency, 100, "USD") == "USD100.00"
    end

    test "applies currency formatter without argument" do
      assert FormatterRegistry.apply_formatter(:currency, 100, nil) == "$100.00"
    end

    test "applies iso8601 formatter" do
      dt = ~U[2024-01-01 12:00:00Z]
      assert FormatterRegistry.apply_formatter(:iso8601, dt, nil) == "2024-01-01T12:00:00Z"
    end

    test "applies datetime formatter with format string" do
      dt = ~U[2024-01-01 12:00:00Z]
      result = FormatterRegistry.apply_formatter(:datetime, dt, "%Y-%m-%d")
      assert result == "2024-01-01"
    end

    test "applies number formatter with options" do
      # The number formatter doesn't add thousands separator, just formats with precision
      assert FormatterRegistry.apply_formatter(:number, 1234.5, precision: 1) == "1234.5"
    end

    test "applies boolean formatter" do
      assert FormatterRegistry.apply_formatter(:boolean, true, nil) == true
      assert FormatterRegistry.apply_formatter(:boolean, false, nil) == false
      assert FormatterRegistry.apply_formatter(:boolean, "yes", nil) == true
      assert FormatterRegistry.apply_formatter(:boolean, "no", nil) == false
    end

    test "applies string formatters" do
      assert FormatterRegistry.apply_formatter(:downcase, "HELLO", nil) == "hello"
      assert FormatterRegistry.apply_formatter(:upcase, "hello", nil) == "HELLO"

      assert FormatterRegistry.apply_formatter(:parameterize, "Hello World!", nil) ==
               "hello-world"
    end

    test "raises for unknown formatter" do
      assert_raise ArgumentError, ~r/Unknown formatter: :unknown/, fn ->
        FormatterRegistry.apply_formatter(:unknown, "value", nil)
      end
    end
  end

  describe "has_formatter?/1" do
    test "returns true for registered formatters" do
      assert FormatterRegistry.has_formatter?(:currency)
      assert FormatterRegistry.has_formatter?(:iso8601)
      assert FormatterRegistry.has_formatter?(:boolean)
    end

    test "returns false for unknown formatters" do
      refute FormatterRegistry.has_formatter?(:unknown)
      refute FormatterRegistry.has_formatter?(:custom_format)
    end
  end
end
