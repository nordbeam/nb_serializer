defmodule NbSerializerTest do
  use ExUnit.Case
  doctest NbSerializer

  defmodule User do
    defstruct [:id, :name, :email]
  end

  describe "serialize/3" do
    test "serializes a simple map with basic fields" do
      defmodule SimpleSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
        end
      end

      data = %{id: 1, name: "John", email: "john@example.com"}
      {:ok, result} = NbSerializer.serialize(SimpleSerializer, data)

      assert result == %{id: 1, name: "John"}
    end

    test "serializes a struct" do
      defmodule UserSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
        end
      end

      user = %NbSerializerTest.User{id: 1, name: "Jane", email: "jane@example.com"}
      {:ok, result} = NbSerializer.serialize(UserSerializer, user)

      assert result == %{id: 1, name: "Jane"}
    end

    test "serializes a list of items" do
      defmodule ListSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:title, :string)
        end
      end

      items = [
        %{id: 1, title: "First", body: "Content 1"},
        %{id: 2, title: "Second", body: "Content 2"}
      ]

      {:ok, result} = NbSerializer.serialize(ListSerializer, items)

      assert result == [
               %{id: 1, title: "First"},
               %{id: 2, title: "Second"}
             ]
    end

    test "handles nil values" do
      defmodule NilSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
          field(:email, :string)
        end
      end

      data = %{id: 1, name: nil, email: "test@example.com"}
      {:ok, result} = NbSerializer.serialize(NilSerializer, data)

      assert result == %{id: 1, name: nil, email: "test@example.com"}
    end
  end

  describe "serialize!/3" do
    test "returns map representation" do
      defmodule JsonSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
        end
      end

      data = %{id: 1, name: "Test"}
      result = NbSerializer.serialize!(JsonSerializer, data)

      assert result == %{id: 1, name: "Test"}
    end
  end

  describe "to_json!/3" do
    test "returns JSON string" do
      defmodule JsonSerializerForJson do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
        end
      end

      data = %{id: 1, name: "Test"}
      result = NbSerializer.to_json!(JsonSerializerForJson, data)

      assert result == ~s({"id":1,"name":"Test"})
    end
  end

  describe "fields definition" do
    test "supports multiple fields at once" do
      defmodule MultiFieldSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
          field(:email, :string)
          field(:created_at, :datetime)
        end
      end

      data = %{
        id: 1,
        name: "Alice",
        email: "alice@example.com",
        created_at: ~U[2024-01-01 12:00:00Z],
        updated_at: ~U[2024-01-02 12:00:00Z]
      }

      {:ok, result} = NbSerializer.serialize(MultiFieldSerializer, data)

      assert result == %{
               id: 1,
               name: "Alice",
               email: "alice@example.com",
               created_at: "2024-01-01T12:00:00Z"
             }
    end

    test "supports field renaming with :from option" do
      defmodule RenameSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:full_name, :string, from: :name)
          field(:created_timestamp, :datetime, from: :created_at)
        end
      end

      data = %{
        id: 1,
        name: "Bob",
        created_at: ~U[2024-01-01 12:00:00Z]
      }

      {:ok, result} = NbSerializer.serialize(RenameSerializer, data)

      assert result == %{
               id: 1,
               full_name: "Bob",
               created_timestamp: "2024-01-01T12:00:00Z"
             }
    end

    test "supports default values" do
      defmodule DefaultSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:status, :string, default: "active")
          field(:role, :string, default: "user")
        end
      end

      data = %{id: 1, status: nil}
      {:ok, result} = NbSerializer.serialize(DefaultSerializer, data)

      assert result == %{
               id: 1,
               status: "active",
               role: "user"
             }
    end
  end

  describe "any type support" do
    test "supports :any atom syntax for fields" do
      defmodule AnyTypeSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:metadata, :any)
          field(:custom_data, :any)
        end
      end

      data = %{
        id: 1,
        metadata: %{nested: %{data: "value"}},
        custom_data: [1, "two", %{three: 3}]
      }

      {:ok, result} = NbSerializer.serialize(AnyTypeSerializer, data)

      assert result == %{
               id: 1,
               metadata: %{nested: %{data: "value"}},
               custom_data: [1, "two", %{three: 3}]
             }
    end

    test "supports type: 'any' string syntax for fields" do
      defmodule AnyTypeStringSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:metadata, type: "any")
          field(:custom_data, type: "any")
        end
      end

      data = %{
        id: 1,
        metadata: %{nested: %{data: "value"}},
        custom_data: [1, "two", %{three: 3}]
      }

      {:ok, result} = NbSerializer.serialize(AnyTypeStringSerializer, data)

      assert result == %{
               id: 1,
               metadata: %{nested: %{data: "value"}},
               custom_data: [1, "two", %{three: 3}]
             }
    end

    test "supports :any with additional options" do
      defmodule AnyWithOptionsSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:metadata, :any, nullable: true)
          field(:optional_data, :any, optional: true)
        end
      end

      data = %{id: 1, metadata: nil}
      {:ok, result} = NbSerializer.serialize(AnyWithOptionsSerializer, data)

      assert result == %{id: 1, metadata: nil, optional_data: nil}
    end
  end

  describe "camelization" do
    test "camelizes keys when enabled via config" do
      # Temporarily enable camelization
      original = Application.get_env(:nb_serializer, :camelize_props)
      Application.put_env(:nb_serializer, :camelize_props, true)

      try do
        defmodule CamelizeSerializer do
          use NbSerializer.Serializer

          schema do
            field(:user_name, :string)
            field(:total_count, :integer)
            field(:is_active, :boolean)
            field(:created_at, :string)
          end
        end

        data = %{user_name: "John", total_count: 42, is_active: true, created_at: "2024-01-01"}
        {:ok, result} = NbSerializer.serialize(CamelizeSerializer, data)

        assert result == %{
                 userName: "John",
                 totalCount: 42,
                 isActive: true,
                 createdAt: "2024-01-01"
               }
      after
        if original == nil do
          Application.delete_env(:nb_serializer, :camelize_props)
        else
          Application.put_env(:nb_serializer, :camelize_props, original)
        end
      end
    end

    test "respects camelize option over config" do
      # Config is disabled in tests, but we can override with option
      defmodule SnakeCaseSerializer do
        use NbSerializer.Serializer

        schema do
          field(:user_name, :string)
          field(:total_count, :integer)
        end
      end

      data = %{user_name: "Jane", total_count: 10}

      # Explicitly enable camelization
      {:ok, result} = NbSerializer.serialize(SnakeCaseSerializer, data, camelize: true)
      assert result == %{userName: "Jane", totalCount: 10}

      # Explicitly disable camelization
      {:ok, result} = NbSerializer.serialize(SnakeCaseSerializer, data, camelize: false)
      assert result == %{user_name: "Jane", total_count: 10}
    end

    test "camelizes nested maps and lists" do
      # Temporarily enable camelization
      original = Application.get_env(:nb_serializer, :camelize_props)
      Application.put_env(:nb_serializer, :camelize_props, true)

      try do
        defmodule NestedUserSerializer do
          use NbSerializer.Serializer

          schema do
            field(:user_name, :string)
            field(:email_address, :string)
          end
        end

        defmodule NestedPostSerializer do
          use NbSerializer.Serializer

          schema do
            field(:post_title, :string)
            field(:created_at, :string)
            has_one(:post_author, serializer: NestedUserSerializer)
          end
        end

        data = %{
          post_title: "Hello",
          created_at: "2024-01-01",
          post_author: %{user_name: "John", email_address: "john@example.com"}
        }

        {:ok, result} = NbSerializer.serialize(NestedPostSerializer, data)

        assert result == %{
                 postTitle: "Hello",
                 createdAt: "2024-01-01",
                 postAuthor: %{
                   userName: "John",
                   emailAddress: "john@example.com"
                 }
               }
      after
        if original == nil do
          Application.delete_env(:nb_serializer, :camelize_props)
        else
          Application.put_env(:nb_serializer, :camelize_props, original)
        end
      end
    end
  end
end
