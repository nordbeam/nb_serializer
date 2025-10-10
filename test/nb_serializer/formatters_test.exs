defmodule NbSerializer.FormattersTest do
  use ExUnit.Case

  describe "built-in formatters" do
    defmodule FormattersSerializer do
      use NbSerializer.Serializer

      schema do
        field(:id)
        field(:price, format: :currency)
        field(:price_usd, from: :price, format: {:currency, "$"})
        field(:price_eur, from: :price, format: {:currency, "€"})
        field(:created_at, format: :iso8601)
        field(:updated_at, format: {:datetime, "%Y-%m-%d %H:%M:%S"})
        field(:percentage, format: {:number, precision: 2})
        field(:rating, format: {:number, precision: 1})
        field(:is_active, format: :boolean)
        field(:status, format: :downcase)
        field(:title, format: :upcase)
        field(:slug, format: :parameterize)
      end
    end

    test "formats currency values" do
      data = %{
        id: 1,
        price: 19.99
      }

      {:ok, result} = NbSerializer.serialize(FormattersSerializer, data)

      assert result[:price] == "$19.99"
      assert result[:price_usd] == "$19.99"
      assert result[:price_eur] == "€19.99"
    end

    test "formats datetime to ISO8601" do
      data = %{
        id: 1,
        created_at: ~U[2024-01-15 10:30:00Z],
        updated_at: ~U[2024-01-15 10:30:00Z]
      }

      {:ok, result} = NbSerializer.serialize(FormattersSerializer, data)

      assert result[:created_at] == "2024-01-15T10:30:00Z"
      assert result[:updated_at] == "2024-01-15 10:30:00"
    end

    test "formats datetime with NaiveDateTime" do
      data = %{
        id: 1,
        created_at: ~N[2024-01-15 10:30:00],
        updated_at: ~N[2024-01-15 10:30:00]
      }

      {:ok, result} = NbSerializer.serialize(FormattersSerializer, data)

      assert result[:created_at] == "2024-01-15T10:30:00"
      assert result[:updated_at] == "2024-01-15 10:30:00"
    end

    test "formats numbers with precision" do
      data = %{
        id: 1,
        percentage: 85.4567,
        rating: 4.86
      }

      {:ok, result} = NbSerializer.serialize(FormattersSerializer, data)

      assert result[:percentage] == "85.46"
      assert result[:rating] == "4.9"
    end

    test "formats boolean values" do
      data = %{
        id: 1,
        is_active: 1
      }

      {:ok, result} = NbSerializer.serialize(FormattersSerializer, data)

      assert result[:is_active] == true

      data2 = %{id: 2, is_active: 0}
      {:ok, result2} = NbSerializer.serialize(FormattersSerializer, data2)
      assert result2[:is_active] == false

      data3 = %{id: 3, is_active: "true"}
      {:ok, result3} = NbSerializer.serialize(FormattersSerializer, data3)
      assert result3[:is_active] == true
    end

    test "formats string values" do
      data = %{
        id: 1,
        status: "Active",
        title: "hello world",
        slug: "Hello World 2024!"
      }

      {:ok, result} = NbSerializer.serialize(FormattersSerializer, data)

      assert result[:status] == "active"
      assert result[:title] == "HELLO WORLD"
      assert result[:slug] == "hello-world-2024"
    end
  end

  describe "custom format functions" do
    defmodule CustomFormatSerializer do
      use NbSerializer.Serializer

      schema do
        field(:id)
        field(:name)
        field(:email, format: :mask_email)
        field(:phone, format: :format_phone)
        field(:amount, format: {:custom_currency, precision: 2, symbol: "USD"})
      end

      def mask_email(email) when is_binary(email) do
        case String.split(email, "@") do
          [username, domain] ->
            masked = String.slice(username, 0..1) <> "***"
            "#{masked}@#{domain}"

          _ ->
            email
        end
      end

      def format_phone(phone) when is_binary(phone) do
        digits = String.replace(phone, ~r/\D/, "")

        case String.length(digits) do
          10 ->
            area = String.slice(digits, 0..2)
            prefix = String.slice(digits, 3..5)
            number = String.slice(digits, 6..9)
            "(#{area}) #{prefix}-#{number}"

          _ ->
            phone
        end
      end

      def custom_currency(value, opts) do
        precision = opts[:precision] || 2
        symbol = opts[:symbol] || "$"
        formatted = :erlang.float_to_binary(value / 1.0, decimals: precision)
        "#{symbol} #{formatted}"
      end
    end

    test "uses custom format functions" do
      data = %{
        id: 1,
        name: "John Doe",
        email: "johndoe@example.com",
        phone: "5551234567",
        amount: 1999.50
      }

      {:ok, result} = NbSerializer.serialize(CustomFormatSerializer, data)

      assert result[:email] == "jo***@example.com"
      assert result[:phone] == "(555) 123-4567"
      assert result[:amount] == "USD 1999.50"
    end
  end

  describe "format with transform" do
    defmodule TransformFormatSerializer do
      use NbSerializer.Serializer

      schema do
        field(:id)
        field(:price, transform: :cents_to_dollars, format: :currency)
        field(:score, transform: :normalize_score, format: {:number, precision: 1})
      end

      def cents_to_dollars(cents) when is_integer(cents) do
        cents / 100.0
      end

      def normalize_score(score) when is_integer(score) do
        score / 10.0
      end
    end

    test "applies transform before format" do
      data = %{
        id: 1,
        # cents
        price: 1999,
        # out of 100
        score: 85
      }

      {:ok, result} = NbSerializer.serialize(TransformFormatSerializer, data)

      assert result[:price] == "$19.99"
      assert result[:score] == "8.5"
    end
  end

  describe "format error handling" do
    defmodule SafeFormatSerializer do
      use NbSerializer.Serializer

      schema do
        field(:id)
        field(:date, format: :iso8601, on_error: :null)
        field(:amount, format: :currency, on_error: {:default, "N/A"})
      end
    end

    test "handles format errors gracefully with on_error" do
      data = %{
        id: 1,
        date: "not a date",
        amount: "not a number"
      }

      {:ok, result} = NbSerializer.serialize(SafeFormatSerializer, data)

      assert result[:date] == nil
      assert result[:amount] == "N/A"
    end
  end

  describe "NbSerializer.Formatters module" do
    test "can use formatters directly" do
      assert NbSerializer.Formatters.currency(19.99) == "$19.99"
      assert NbSerializer.Formatters.currency(19.99, "€") == "€19.99"

      assert NbSerializer.Formatters.iso8601(~U[2024-01-15 10:30:00Z]) == "2024-01-15T10:30:00Z"

      assert NbSerializer.Formatters.number(85.4567, precision: 2) == "85.46"

      assert NbSerializer.Formatters.boolean(1) == true
      assert NbSerializer.Formatters.boolean(0) == false

      assert NbSerializer.Formatters.downcase("HELLO") == "hello"
      assert NbSerializer.Formatters.upcase("hello") == "HELLO"
      assert NbSerializer.Formatters.parameterize("Hello World!") == "hello-world"
    end
  end
end
