defmodule NbSerializer.SerializationErrorTest do
  use ExUnit.Case, async: true

  alias NbSerializer.SerializationError

  describe "SerializationError exception" do
    test "raises with field and original error" do
      original_error = %RuntimeError{message: "Something went wrong"}

      assert_raise SerializationError, fn ->
        raise SerializationError, field: :email, original_error: original_error
      end
    end

    test "formats message correctly with field and error" do
      original_error = %RuntimeError{message: "Something went wrong"}

      error = %SerializationError{field: :email, original_error: original_error}

      assert Exception.message(error) == "Error serializing field :email: Something went wrong"
    end

    test "formats message with field only" do
      error = %SerializationError{field: :username, original_error: nil}

      assert Exception.message(error) == "Error serializing field :username"
    end

    test "formats message with original error only" do
      original_error = %ArgumentError{message: "invalid argument"}
      error = %SerializationError{field: nil, original_error: original_error}

      assert Exception.message(error) == "Serialization error: invalid argument"
    end

    test "formats message with neither field nor error" do
      error = %SerializationError{field: nil, original_error: nil}

      assert Exception.message(error) == "Unknown serialization error"
    end

    test "handles string error messages" do
      error = %SerializationError{field: :age, original_error: "must be a number"}

      assert Exception.message(error) == "Error serializing field :age: must be a number"
    end
  end
end
