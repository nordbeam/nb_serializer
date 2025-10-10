defmodule NbSerializer.UtilsTest do
  use ExUnit.Case, async: true

  alias NbSerializer.Utils

  describe "handle_nil_or_empty/2" do
    test "returns empty list for nil with :many cardinality" do
      assert Utils.handle_nil_or_empty(nil, :many) == []
    end

    test "returns nil for nil with :one cardinality" do
      assert Utils.handle_nil_or_empty(nil, :one) == nil
    end

    test "returns empty list for empty list with :many cardinality" do
      assert Utils.handle_nil_or_empty([], :many) == []
    end

    test "returns empty list for NotLoaded association with :many cardinality" do
      not_loaded = %Ecto.Association.NotLoaded{
        __field__: :posts,
        __owner__: nil,
        __cardinality__: :many
      }

      assert Utils.handle_nil_or_empty(not_loaded, :many) == []
    end

    test "returns nil for NotLoaded association with :one cardinality" do
      not_loaded = %Ecto.Association.NotLoaded{
        __field__: :author,
        __owner__: nil,
        __cardinality__: :one
      }

      assert Utils.handle_nil_or_empty(not_loaded, :one) == nil
    end

    test "returns data unchanged for non-nil, non-empty values" do
      assert Utils.handle_nil_or_empty([1, 2, 3], :many) == [1, 2, 3]
      assert Utils.handle_nil_or_empty(%{id: 1}, :one) == %{id: 1}
      assert Utils.handle_nil_or_empty("string", :one) == "string"
    end

    test "returns data unchanged for any cardinality when data is present" do
      assert Utils.handle_nil_or_empty(%{id: 1}, :unknown) == %{id: 1}
    end
  end

  describe "format_error_message/2" do
    test "interpolates field name into error message" do
      assert Utils.format_error_message("can't be blank", "email") == "email can't be blank"
    end

    test "handles messages with existing field placeholder" do
      assert Utils.format_error_message("%{field} is required", "name") == "name is required"
    end

    test "returns message unchanged when no interpolation needed" do
      assert Utils.format_error_message("Invalid format", "field") == "field Invalid format"
    end

    test "handles nil field gracefully" do
      assert Utils.format_error_message("can't be blank", nil) == "can't be blank"
    end

    test "handles empty field gracefully" do
      assert Utils.format_error_message("can't be blank", "") == "can't be blank"
    end

    test "handles keyword list options for multiple interpolations" do
      assert Utils.format_error_message("must be at least %{count} characters",
               field: "username",
               count: 3
             ) ==
               "must be at least 3 characters"
    end

    test "handles mixed field interpolations in keyword list" do
      assert Utils.format_error_message("%{field} must be %{count} characters",
               field: "password",
               count: 8
             ) ==
               "password must be 8 characters"
    end

    test "handles non-string values with to_string conversion" do
      assert Utils.format_error_message(123, nil) == "123"
    end
  end
end
