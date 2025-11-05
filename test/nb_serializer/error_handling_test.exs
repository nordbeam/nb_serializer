defmodule NbSerializer.ErrorHandlingTest do
  use ExUnit.Case

  describe "on_error option" do
    defmodule ErrorHandlingSerializer do
      use NbSerializer.Serializer

      schema do
        field(:id, :number)
        field(:name, :string)
        field(:age, :integer, compute: :calculate_age, on_error: :null)
        field(:status, :string, compute: :missing_function, on_error: {:default, "unknown"})
        field(:level, :integer, compute: :get_level, on_error: {:default, 1})
        field(:verified, :boolean, compute: :check_verified, on_error: :skip)
        field(:full_name, :string, compute: :get_full_name, on_error: :null)
      end

      def calculate_age(_user, _opts) do
        raise "Age calculation failed"
      end

      def get_level(_user, _opts) do
        raise ArgumentError, "Invalid level"
      end

      def check_verified(_user, _opts) do
        raise "Verification check failed"
      end

      def get_full_name(user, _opts) do
        "#{user.first_name} #{user.last_name}"
      end
    end

    test "returns null when on_error: :null" do
      user = %{id: 1, name: "John"}

      {:ok, result} = NbSerializer.serialize(ErrorHandlingSerializer, user)

      assert result[:age] == nil
    end

    test "returns default value when on_error: {:default, value}" do
      user = %{id: 1, name: "John"}

      {:ok, result} = NbSerializer.serialize(ErrorHandlingSerializer, user)

      assert result[:status] == "unknown"
      assert result[:level] == 1
    end

    test "skips field when on_error: :skip" do
      user = %{id: 1, name: "John"}

      {:ok, result} = NbSerializer.serialize(ErrorHandlingSerializer, user)

      refute Map.has_key?(result, :verified)
    end

    test "handles undefined function errors with on_error" do
      user = %{id: 1, name: "John"}

      {:ok, result} = NbSerializer.serialize(ErrorHandlingSerializer, user)

      assert result[:status] == "unknown"
    end

    test "handles computed field that works correctly" do
      user = %{
        id: 1,
        name: "John",
        first_name: "John",
        last_name: "Doe"
      }

      {:ok, result} = NbSerializer.serialize(ErrorHandlingSerializer, user)

      assert result[:full_name] == "John Doe"
    end
  end

  describe "error handling" do
    test "raises compile error when compute function doesn't exist" do
      assert_raise NbSerializer.CompileError, fn ->
        defmodule BrokenComputeSerializer do
          use NbSerializer.Serializer

          schema do
            field(:id, :number)
            field(:computed, :any, compute: :non_existent_function)
          end
        end
      end
    end

    test "raises compile error when transform function doesn't exist" do
      assert_raise NbSerializer.CompileError, fn ->
        defmodule BrokenTransformSerializer do
          use NbSerializer.Serializer

          schema do
            field(:id, :number)
            field(:name, :string, transform: :non_existent_transform)
          end
        end
      end
    end

    test "raises error when condition function doesn't exist" do
      defmodule BrokenConditionSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:secret, :string, if: :non_existent_condition)
        end
      end

      data = %{id: 1, secret: "hidden"}

      # Now wrapped in SerializationError
      assert_raise NbSerializer.SerializationError, fn ->
        NbSerializer.serialize!(BrokenConditionSerializer, data)
      end
    end

    test "handles nil data gracefully" do
      defmodule NilHandlingSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
        end
      end

      {:ok, result} = NbSerializer.serialize(NilHandlingSerializer, nil)
      assert result == nil
    end

    test "handles data with wrong type" do
      defmodule TypeHandlingSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
        end
      end

      # String instead of map/struct
      {:ok, result} = NbSerializer.serialize(TypeHandlingSerializer, "not a map")
      assert result == %{id: nil, name: nil}

      # Number instead of map/struct
      {:ok, result} = NbSerializer.serialize(TypeHandlingSerializer, 123)
      assert result == %{id: nil, name: nil}
    end

    test "to_json! raises for data that can't be JSON encoded" do
      defmodule CircularSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:pid, :any, compute: :get_pid)
        end

        def get_pid(_data, _opts) do
          self()
        end
      end

      data = %{id: 1}

      # Jason raises Protocol.UndefinedError for PIDs, but we wrap it
      error =
        assert_raise NbSerializer.SerializationError, fn ->
          NbSerializer.to_json!(CircularSerializer, data)
        end

      # Verify the error message contains information about the protocol error
      assert error.message =~ "Protocol.UndefinedError" or
               (is_struct(error.original_error) and
                  error.original_error.__struct__ == Protocol.UndefinedError)
    end

    test "handles missing serializer in relationship" do
      defmodule MissingSerializerRelationship do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          # No serializer specified
          has_one(:profile)
        end
      end

      data = %{id: 1, profile: %{id: 2, name: "Profile"}}
      {:ok, result} = NbSerializer.serialize(MissingSerializerRelationship, data)

      # Should pass through the raw data when no serializer
      assert result == %{id: 1, profile: %{id: 2, name: "Profile"}}
    end

    test "handles deeply nested nil values" do
      defmodule NestedNilSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:nested, :any, compute: :get_nested)
        end

        def get_nested(data, _opts) do
          get_in(data, [:deep, :nested, :value])
        end
      end

      data = %{id: 1, deep: nil}
      {:ok, result} = NbSerializer.serialize(NestedNilSerializer, data)

      assert result == %{id: 1, nested: nil}
    end

    test "handles transform function that returns nil" do
      defmodule NilTransformSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string, transform: :always_nil)
        end

        def always_nil(_value), do: nil
      end

      data = %{id: 1, name: "Test"}
      {:ok, result} = NbSerializer.serialize(NilTransformSerializer, data)

      assert result == %{id: 1, name: nil}
    end

    test "handles compute function that raises" do
      defmodule RaisingComputeSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:computed, :any, compute: :raising_function)
        end

        def raising_function(_data, _opts) do
          raise "Computation error"
        end
      end

      data = %{id: 1}

      # Now wrapped in SerializationError
      assert_raise NbSerializer.SerializationError, fn ->
        NbSerializer.serialize!(RaisingComputeSerializer, data)
      end
    end

    test "handles keyword list data" do
      defmodule KeywordListSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
          field(:age, :integer)
        end
      end

      # Keyword lists are treated as lists when is_list check happens first
      # Each tuple becomes an item to serialize
      data = [id: 1, name: "Alice", age: 30, extra: "ignored"]
      {:ok, result} = NbSerializer.serialize(KeywordListSerializer, data)

      # It will serialize each tuple as a separate item
      assert is_list(result)
      assert length(result) == 4
    end

    test "handles struct with both atom and string keys" do
      defmodule MixedKeysSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string, from: "name")
        end
      end

      data = %{:id => 1, "name" => "Test"}
      {:ok, result} = NbSerializer.serialize(MixedKeysSerializer, data)

      assert result == %{id: 1, name: "Test"}
    end
  end
end
