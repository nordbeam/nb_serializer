defmodule NbSerializer.ComputedFieldsTest do
  use ExUnit.Case

  describe "computed fields" do
    test "supports function reference for computation" do
      defmodule FunctionRefSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:display_name, :string, compute: :format_name)
        end

        def format_name(user, _opts) do
          String.upcase(user.name)
        end
      end

      data = %{id: 1, name: "alice"}
      {:ok, result} = NbSerializer.serialize(FunctionRefSerializer, data)

      assert result == %{id: 1, display_name: "ALICE"}
    end

    test "computed field with full_name example" do
      defmodule FullNameSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:full_name, :string, compute: :build_full_name)
        end

        def build_full_name(user, _opts) do
          "#{user.first_name} #{user.last_name}"
        end
      end

      data = %{id: 1, first_name: "John", last_name: "Doe"}
      {:ok, result} = NbSerializer.serialize(FullNameSerializer, data)

      assert result == %{id: 1, full_name: "John Doe"}
    end

    test "computed field with pattern matching in function" do
      defmodule StatusSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:status_label, :string, compute: :format_status)
        end

        def format_status(%{status: "pending"}, _opts), do: "Awaiting Approval"
        def format_status(%{status: "active"}, _opts), do: "Active"
        def format_status(%{status: "archived"}, _opts), do: "Archived"
        def format_status(_, _opts), do: "Unknown"
      end

      pending = %{id: 1, status: "pending"}
      active = %{id: 2, status: "active"}
      unknown = %{id: 3, status: "weird"}

      assert {:ok, result} = NbSerializer.serialize(StatusSerializer, pending)

      assert result == %{
               id: 1,
               status_label: "Awaiting Approval"
             }

      assert {:ok, result} = NbSerializer.serialize(StatusSerializer, active)
      assert result == %{id: 2, status_label: "Active"}
      assert {:ok, result2} = NbSerializer.serialize(StatusSerializer, unknown)
      assert result2 == %{id: 3, status_label: "Unknown"}
    end

    test "computed field receives opts as second argument" do
      defmodule GreetingSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:greeting, :string, compute: :build_greeting)
        end

        def build_greeting(user, opts) do
          locale = Keyword.get(opts, :locale, :en)

          case locale do
            :es -> "Hola, #{user.name}"
            :fr -> "Bonjour, #{user.name}"
            _ -> "Hello, #{user.name}"
          end
        end
      end

      data = %{id: 1, name: "Marie"}

      assert {:ok, result} = NbSerializer.serialize(GreetingSerializer, data)
      assert result == %{id: 1, greeting: "Hello, Marie"}

      assert {:ok, result2} = NbSerializer.serialize(GreetingSerializer, data, locale: :fr)

      assert result2 == %{
               id: 1,
               greeting: "Bonjour, Marie"
             }

      assert {:ok, result3} = NbSerializer.serialize(GreetingSerializer, data, locale: :es)

      assert result3 == %{
               id: 1,
               greeting: "Hola, Marie"
             }
    end

    test "nested computed fields" do
      defmodule MetadataSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:metadata, :any, compute: :build_metadata)
        end

        def build_metadata(product, _opts) do
          %{
            category: product.category,
            tags: Enum.map(product.tags, &String.upcase/1),
            in_stock: product.quantity > 0
          }
        end
      end

      data = %{
        id: 1,
        category: "electronics",
        tags: ["phone", "smartphone"],
        quantity: 5
      }

      {:ok, result} = NbSerializer.serialize(MetadataSerializer, data)

      assert result == %{
               id: 1,
               metadata: %{
                 category: "electronics",
                 tags: ["PHONE", "SMARTPHONE"],
                 in_stock: true
               }
             }
    end

    test "transform option modifies computed value" do
      defmodule TransformSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:price, :any, compute: :calculate_price, transform: :round_price)
          field(:tags, list: :string, transform: :sort_tags)
        end

        def calculate_price(item, _opts) do
          item.price_cents / 100
        end

        def round_price(price) do
          Float.round(price, 2)
        end

        def sort_tags(tags) do
          Enum.sort(tags)
        end
      end

      data = %{
        id: 1,
        price_cents: 1999,
        tags: ["new", "featured", "bestseller"]
      }

      {:ok, result} = NbSerializer.serialize(TransformSerializer, data)

      assert result == %{
               id: 1,
               price: 19.99,
               tags: ["bestseller", "featured", "new"]
             }
    end
  end
end
