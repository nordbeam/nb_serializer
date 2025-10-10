# This file demonstrates the improved error messages with TypeGenerationError
# Run with: mix test test/nb_serializer/type_generation_error_demo.exs

defmodule NbSerializer.TypeGenerationErrorDemoTest do
  use ExUnit.Case

  @moduledoc """
  This test suite demonstrates the improved error messages provided by TypeGenerationError.
  Each test shows how helpful context and suggestions are provided for common errors.
  """

  describe "Error message examples" do
    test "invalid type atom shows helpful suggestion" do
      error =
        assert_raise NbSerializer.TypeGenerationError, fn ->
          defmodule IntegerTypeDemo do
            use NbSerializer.Serializer

            schema do
              field(:count, :integer)
            end
          end
        end

      # The error includes helpful context
      assert error.message =~ "Invalid type annotation: :integer"
      assert error.message =~ "Did you mean :number?"
      assert error.message =~ "Valid types are:"
      assert error.serializer == NbSerializer.TypeGenerationErrorDemoTest.IntegerTypeDemo
      assert error.field == :count
    end

    test "invalid custom TypeScript type shows character restrictions" do
      error =
        assert_raise NbSerializer.TypeGenerationError, fn ->
          defmodule InvalidCustomTypeDemo do
            use NbSerializer.Serializer

            schema do
              field(:data, type: "Map<String$Key>")
            end
          end
        end

      # The error explains what characters are allowed
      assert error.message =~ "Invalid custom TypeScript type"
      assert error.message =~ "Map<String$Key>"
      assert error.message =~ "Valid characters:"
      assert error.field == :data
      assert length(error.suggestions) > 0
    end

    test "common typos get helpful suggestions" do
      # Test :integer -> :number suggestion
      error1 =
        assert_raise NbSerializer.TypeGenerationError, fn ->
          defmodule IntDemo do
            use NbSerializer.Serializer

            schema do
              field(:id, :integer)
            end
          end
        end

      assert error1.message =~ "Did you mean :number?"

      # Test :float -> :number suggestion
      error2 =
        assert_raise NbSerializer.TypeGenerationError, fn ->
          defmodule FloatDemo do
            use NbSerializer.Serializer

            schema do
              field(:price, :float)
            end
          end
        end

      assert error2.message =~ "Did you mean :number?"

      # Test :str -> :string suggestion
      error3 =
        assert_raise NbSerializer.TypeGenerationError, fn ->
          defmodule StrDemo do
            use NbSerializer.Serializer

            schema do
              field(:name, :str)
            end
          end
        end

      assert error3.message =~ "Did you mean :string?"

      # Test :bool -> :boolean suggestion
      error4 =
        assert_raise NbSerializer.TypeGenerationError, fn ->
          defmodule BoolDemo do
            use NbSerializer.Serializer

            schema do
              field(:active, :bool)
            end
          end
        end

      assert error4.message =~ "Did you mean :boolean?"
    end
  end
end
