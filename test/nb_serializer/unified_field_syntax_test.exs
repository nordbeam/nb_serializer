defmodule NbSerializer.UnifiedFieldSyntaxTest do
  use ExUnit.Case

  describe "unified field syntax - list types" do
    test "field(:tags, list: :string) stores as {:tags, [list: :string]}" do
      defmodule ListStringSerializer do
        use NbSerializer.Serializer

        schema do
          field(:tags, list: :string)
        end
      end

      fields = ListStringSerializer.__nb_serializer_fields__()
      assert {:tags, [list: :string]} in fields
    end

    test "field(:scores, list: :number) stores as {:scores, [list: :number]}" do
      defmodule ListNumberSerializer do
        use NbSerializer.Serializer

        schema do
          field(:scores, list: :number)
        end
      end

      fields = ListNumberSerializer.__nb_serializer_fields__()
      assert {:scores, [list: :number]} in fields
    end

    test "field(:flags, list: :boolean) stores as {:flags, [list: :boolean]}" do
      defmodule ListBooleanSerializer do
        use NbSerializer.Serializer

        schema do
          field(:flags, list: :boolean)
        end
      end

      fields = ListBooleanSerializer.__nb_serializer_fields__()
      assert {:flags, [list: :boolean]} in fields
    end

    test "field(:items, list: :any) stores as {:items, [list: :any]}" do
      defmodule ListAnySerializer do
        use NbSerializer.Serializer

        schema do
          field(:items, list: :any)
        end
      end

      fields = ListAnySerializer.__nb_serializer_fields__()
      assert {:items, [list: :any]} in fields
    end
  end

  describe "unified field syntax - enum types" do
    test "field(:status, enum: [...]) stores as {:status, [enum: [...]]}" do
      defmodule EnumSerializer do
        use NbSerializer.Serializer

        schema do
          field(:status, enum: ["active", "inactive", "pending"])
        end
      end

      fields = EnumSerializer.__nb_serializer_fields__()
      assert {:status, [enum: ["active", "inactive", "pending"]]} in fields
    end

    test "field(:role, enum: [:admin, :user]) stores atom enums correctly" do
      defmodule AtomEnumSerializer do
        use NbSerializer.Serializer

        schema do
          field(:role, enum: [:admin, :user, :guest])
        end
      end

      fields = AtomEnumSerializer.__nb_serializer_fields__()
      assert {:role, [enum: [:admin, :user, :guest]]} in fields
    end
  end

  describe "unified field syntax - nested structures" do
    test "field(:statuses, list: [enum: [...]]) stores list of enums" do
      defmodule ListEnumSerializer do
        use NbSerializer.Serializer

        schema do
          field(:statuses, list: [enum: ["active", "inactive"]])
        end
      end

      fields = ListEnumSerializer.__nb_serializer_fields__()
      assert {:statuses, [list: [enum: ["active", "inactive"]]]} in fields
    end
  end

  describe "unified field syntax - backward compatibility" do
    test "field(:name, :string) still works (simple syntax)" do
      defmodule SimpleFieldSerializer do
        use NbSerializer.Serializer

        schema do
          field(:name, :string)
        end
      end

      fields = SimpleFieldSerializer.__nb_serializer_fields__()
      assert {:name, [type: :string]} in fields
    end

    test "field(:count, :integer, optional: true) still works with additional options" do
      defmodule FieldWithOptionsSerializer do
        use NbSerializer.Serializer

        schema do
          field(:count, :integer, optional: true, nullable: true)
        end
      end

      fields = FieldWithOptionsSerializer.__nb_serializer_fields__()
      assert {:count, opts} = List.keyfind(fields, :count, 0)
      assert opts[:type] == :integer
      assert opts[:optional] == true
      assert opts[:nullable] == true
    end
  end

  describe "unified field syntax - with additional options" do
    test "field(:tags, list: :string, optional: true) combines new syntax with options" do
      defmodule ListWithOptionsSerializer do
        use NbSerializer.Serializer

        schema do
          field(:tags, list: :string, optional: true, nullable: true)
        end
      end

      fields = ListWithOptionsSerializer.__nb_serializer_fields__()
      assert {:tags, opts} = List.keyfind(fields, :tags, 0)
      assert opts[:list] == :string
      assert opts[:optional] == true
      assert opts[:nullable] == true
    end

    test "field(:status, enum: [...], default: value) combines enum with default" do
      defmodule EnumWithDefaultSerializer do
        use NbSerializer.Serializer

        schema do
          field(:status, enum: ["active", "inactive"], default: "active")
        end
      end

      fields = EnumWithDefaultSerializer.__nb_serializer_fields__()
      assert {:status, opts} = List.keyfind(fields, :status, 0)
      assert opts[:enum] == ["active", "inactive"]
      assert opts[:default] == "active"
    end
  end

  describe "unified field syntax - serialization behavior" do
    test "list: :string actually serializes list of strings" do
      defmodule ListSerializationSerializer do
        use NbSerializer.Serializer

        schema do
          field(:tags, list: :string)
        end
      end

      data = %{tags: ["elixir", "phoenix", "testing"]}
      {:ok, result} = NbSerializer.serialize(ListSerializationSerializer, data)

      assert result == %{tags: ["elixir", "phoenix", "testing"]}
    end

    test "enum: [...] serializes enum values" do
      defmodule EnumSerializationSerializer do
        use NbSerializer.Serializer

        schema do
          field(:status, enum: ["active", "inactive"])
        end
      end

      data = %{status: "active"}
      {:ok, result} = NbSerializer.serialize(EnumSerializationSerializer, data)

      assert result == %{status: "active"}
    end
  end
end
