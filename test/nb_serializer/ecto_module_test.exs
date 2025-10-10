defmodule NbSerializer.EctoModuleTest do
  use ExUnit.Case

  # Mock Ecto schema for testing
  defmodule TestSchema do
    use Ecto.Schema

    schema "test_schemas" do
      field(:name, :string)
      field(:email, :string)
      has_many(:items, TestItem)
    end
  end

  defmodule TestItem do
    use Ecto.Schema

    schema "test_items" do
      field(:title, :string)
      belongs_to(:test_schema, TestSchema)
    end
  end

  describe "NbSerializer.Ecto module" do
    test "prepare_data removes __meta__ from Ecto schemas" do
      schema = %TestSchema{
        id: 1,
        name: "Test",
        email: "test@example.com",
        __meta__: %Ecto.Schema.Metadata{state: :loaded, source: "test_schemas"}
      }

      result = NbSerializer.Ecto.prepare_data(schema)

      assert result[:id] == 1
      assert result[:name] == "Test"
      assert result[:email] == "test@example.com"
      refute Map.has_key?(result, :__meta__)
      refute Map.has_key?(result, :__struct__)
    end

    test "prepare_data handles Ecto changesets" do
      schema = %TestSchema{
        id: 1,
        name: "Original",
        email: "original@example.com",
        __meta__: %Ecto.Schema.Metadata{state: :loaded, source: "test_schemas"}
      }

      changeset = Ecto.Changeset.change(schema, %{name: "Updated"})
      result = NbSerializer.Ecto.prepare_data(changeset)

      assert result[:id] == 1
      # Gets the original data, not changes
      assert result[:name] == "Original"
      assert result[:email] == "original@example.com"
      refute Map.has_key?(result, :__meta__)
    end

    test "prepare_data passes through non-Ecto data unchanged" do
      data = %{id: 1, name: "Test"}
      assert NbSerializer.Ecto.prepare_data(data) == data

      list = [1, 2, 3]
      assert NbSerializer.Ecto.prepare_data(list) == list

      string = "test"
      assert NbSerializer.Ecto.prepare_data(string) == string
    end

    test "loaded? correctly identifies loaded associations" do
      not_loaded = %Ecto.Association.NotLoaded{
        __field__: :items,
        __owner__: TestSchema,
        __cardinality__: :many
      }

      assert NbSerializer.Ecto.loaded?(not_loaded) == false
      assert NbSerializer.Ecto.loaded?([]) == true
      assert NbSerializer.Ecto.loaded?(nil) == true
      assert NbSerializer.Ecto.loaded?([%TestItem{id: 1}]) == true
    end

    test "if_loaded helper checks association status" do
      schema_with_loaded = %{
        id: 1,
        items: [%TestItem{id: 1, title: "Item"}]
      }

      schema_with_not_loaded = %{
        id: 1,
        items: %Ecto.Association.NotLoaded{
          __field__: :items,
          __owner__: TestSchema,
          __cardinality__: :many
        }
      }

      assert NbSerializer.Ecto.if_loaded(schema_with_loaded, :items) == true
      assert NbSerializer.Ecto.if_loaded(schema_with_not_loaded, :items) == false
      assert NbSerializer.Ecto.if_loaded(schema_with_loaded, :missing_field) == true
    end

    test "serializer using NbSerializer.Ecto cleans metadata" do
      defmodule EctoAwareSerializer do
        use NbSerializer.Serializer
        use NbSerializer.Ecto

        schema do
          field(:id)
          field(:name)
          field(:email)
        end
      end

      schema = %TestSchema{
        id: 1,
        name: "John",
        email: "john@example.com",
        __meta__: %Ecto.Schema.Metadata{state: :loaded, source: "test_schemas"},
        items: %Ecto.Association.NotLoaded{
          __field__: :items,
          __owner__: TestSchema,
          __cardinality__: :many
        }
      }

      {:ok, result} = NbSerializer.serialize(EctoAwareSerializer, schema)

      assert result == %{
               id: 1,
               name: "John",
               email: "john@example.com"
             }

      # Ensure __meta__ and items are not in the result
      refute Map.has_key?(result, :__meta__)
      refute Map.has_key?(result, :items)
    end

    test "serializer with NbSerializer.Ecto handles lists of schemas" do
      defmodule EctoListSerializer do
        use NbSerializer.Serializer
        use NbSerializer.Ecto

        schema do
          field(:id)
          field(:name)
        end
      end

      schemas = [
        %TestSchema{
          id: 1,
          name: "First",
          __meta__: %Ecto.Schema.Metadata{state: :loaded, source: "test_schemas"}
        },
        %TestSchema{
          id: 2,
          name: "Second",
          __meta__: %Ecto.Schema.Metadata{state: :loaded, source: "test_schemas"}
        }
      ]

      {:ok, result} = NbSerializer.serialize(EctoListSerializer, schemas)

      assert result == [
               %{id: 1, name: "First"},
               %{id: 2, name: "Second"}
             ]
    end
  end
end
