defmodule NbSerializer.DSLTypelizerTest do
  use ExUnit.Case

  describe "field macro with type support" do
    defmodule SimpleTypedSerializer do
      use NbSerializer.Serializer

      schema do
        field(:id, :number)
        field(:name, :string)
        field(:active, :boolean)
      end
    end

    test "stores field types in module attributes" do
      fields = SimpleTypedSerializer.__nb_serializer_fields__()

      assert {:id, [type: :number]} in fields
      assert {:name, [type: :string]} in fields
      assert {:active, [type: :boolean]} in fields
    end
  end

  describe "field macro with shorthand syntax" do
    defmodule ShorthandSerializer do
      use NbSerializer.Serializer

      schema do
        field(:id, :number)
        field(:email, :string, nullable: true)
        field(:phone, :string, optional: true)
      end
    end

    test "handles shorthand type syntax with additional options" do
      fields = ShorthandSerializer.__nb_serializer_fields__()

      assert {:id, [type: :number]} in fields
      assert {:email, [type: :string, nullable: true]} in fields
      assert {:phone, [type: :string, optional: true]} in fields
    end
  end

  describe "field macro with extended types" do
    defmodule ExtendedTypesSerializer do
      use NbSerializer.Serializer

      schema do
        field(:id, :uuid)
        field(:price, :decimal)
        field(:created_at, :datetime)
        field(:birth_date, :date)
      end
    end

    test "handles extended type atoms" do
      fields = ExtendedTypesSerializer.__nb_serializer_fields__()

      assert {:id, [type: :uuid]} in fields
      assert {:price, [type: :decimal]} in fields
      assert {:created_at, [type: :datetime]} in fields
      assert {:birth_date, [type: :date]} in fields
    end
  end

  describe "field macro with custom types" do
    defmodule CustomTypeSerializer do
      use NbSerializer.Serializer

      schema do
        field(:metadata, type: "Record<string, unknown>")
        field(:config, type: "CustomConfig")
        field(:data, type: "Partial<User>")
      end
    end

    test "handles custom TypeScript type strings" do
      fields = CustomTypeSerializer.__nb_serializer_fields__()

      assert {:metadata, [type: "Record<string, unknown>"]} in fields
      assert {:config, [type: "CustomConfig"]} in fields
      assert {:data, [type: "Partial<User>"]} in fields
    end
  end

  describe "field macro with lists" do
    defmodule ListSerializer do
      use NbSerializer.Serializer

      schema do
        field(:tags, :string, list: true)
        field(:scores, :number, list: true)
        field(:items, type: "Product", list: true)
      end
    end

    test "handles list type modifier" do
      fields = ListSerializer.__nb_serializer_fields__()

      assert {:tags, [type: :string, list: true]} in fields
      assert {:scores, [type: :number, list: true]} in fields
      assert {:items, [type: "Product", list: true]} in fields
    end
  end

  describe "field macro with enums" do
    defmodule EnumSerializer do
      use NbSerializer.Serializer

      schema do
        field(:status, enum: ["active", "inactive", "pending"])
        field(:role, enum: [:admin, :user, :guest])
      end
    end

    test "handles enum values" do
      fields = EnumSerializer.__nb_serializer_fields__()

      assert {:status, [enum: ["active", "inactive", "pending"]]} in fields
      assert {:role, [enum: [:admin, :user, :guest]]} in fields
    end
  end

  describe "field macro backwards compatibility" do
    defmodule BackwardsCompatSerializer do
      use NbSerializer.Serializer

      schema do
        field(:id, :number)
        field(:name, :string, compute: :format_name)
        field(:admin?, :boolean, if: :is_admin)
      end

      def format_name(data, _opts), do: data.name
      def is_admin(data, _opts), do: data.admin
    end

    test "enforces explicit types on all fields" do
      fields = BackwardsCompatSerializer.__nb_serializer_fields__()

      assert {:id, [type: :number]} in fields
      assert {:name, [type: :string, compute: :format_name]} in fields
      assert {:admin?, [type: :boolean, if: :is_admin]} in fields
    end
  end

  describe "field macro with all features combined" do
    defmodule ComplexSerializer do
      use NbSerializer.Serializer

      schema do
        field(:id, :number)
        field(:name, :string, compute: :format_name)
        field(:email, :string, nullable: true, if: :show_email?)
        field(:tags, :string, list: true, optional: true)
        field(:status, enum: ["active", "inactive"])
        field(:metadata, type: "Record<string, any>", nullable: true)
      end

      def format_name(data, _opts), do: data.name
      def show_email?(data, _opts), do: true
    end

    test "combines type annotations with existing field options" do
      fields = ComplexSerializer.__nb_serializer_fields__()

      assert {:id, [type: :number]} in fields
      assert {:name, [type: :string, compute: :format_name]} in fields

      email_field = Enum.find(fields, fn {name, _} -> name == :email end)
      {_, email_opts} = email_field
      assert :string == Keyword.get(email_opts, :type)
      assert true == Keyword.get(email_opts, :nullable)
      assert :show_email? == Keyword.get(email_opts, :if)

      tags_field = Enum.find(fields, fn {name, _} -> name == :tags end)
      {_, tags_opts} = tags_field
      assert :string == Keyword.get(tags_opts, :type)
      assert true == Keyword.get(tags_opts, :list)
      assert true == Keyword.get(tags_opts, :optional)
    end
  end
end
