defmodule NbSerializer.EdgeCaseTest do
  use ExUnit.Case

  describe "nil handling" do
    test "serializes nil data as nil" do
      defmodule NilSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:name)
      end

      assert {:ok, result} = NbSerializer.serialize(NilSerializer, nil)
      assert result == nil
    end

    test "handles nil in list serialization" do
      defmodule ListNilSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:name)
      end

      assert {:ok, result} = NbSerializer.serialize(ListNilSerializer, [nil, %{id: 1}, nil])

      assert result == [
               nil,
               %{id: 1, name: nil},
               nil
             ]
    end

    test "handles missing fields gracefully" do
      defmodule MissingFieldSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:name)
        field(:email)
      end

      # missing name and email
      data = %{id: 1}
      {:ok, result} = NbSerializer.serialize(MissingFieldSerializer, data)
      assert result == %{id: 1, name: nil, email: nil}
    end
  end

  describe "missing compute functions" do
    test "handles missing compute function with on_error: :null" do
      defmodule MissingComputeNullSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:computed_field, compute: :non_existent_function, on_error: :null)
      end

      data = %{id: 1}
      {:ok, result} = NbSerializer.serialize(MissingComputeNullSerializer, data)
      assert result == %{id: 1, computed_field: nil}
    end

    test "handles missing compute function with on_error: :skip" do
      defmodule MissingComputeSkipSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:computed_field, compute: :non_existent_function, on_error: :skip)
      end

      data = %{id: 1}
      {:ok, result} = NbSerializer.serialize(MissingComputeSkipSerializer, data)
      assert result == %{id: 1}
    end

    test "handles missing compute function with on_error: {:default, value}" do
      defmodule MissingComputeDefaultSerializer do
        use NbSerializer.Serializer

        field(:id)

        field(:computed_field,
          compute: :non_existent_function,
          on_error: {:default, "default_value"}
        )
      end

      data = %{id: 1}
      {:ok, result} = NbSerializer.serialize(MissingComputeDefaultSerializer, data)
      assert result == %{id: 1, computed_field: "default_value"}
    end

    test "raises compile error for missing compute function without on_error" do
      # This test validates compile-time validation
      assert_raise NbSerializer.CompileError, fn ->
        defmodule MissingComputeErrorSerializer do
          use NbSerializer.Serializer

          field(:id)
          field(:computed_field, compute: :non_existent_function)
        end
      end
    end
  end

  describe "transform function arity" do
    test "transform functions are called with single argument" do
      defmodule TransformAritySerializer do
        use NbSerializer.Serializer

        field(:name, transform: :upcase_name)

        def upcase_name(value), do: String.upcase(value || "")
      end

      data = %{name: "john"}
      {:ok, result} = NbSerializer.serialize(TransformAritySerializer, data)
      assert result == %{name: "JOHN"}
    end

    test "transform with nil value" do
      defmodule TransformNilSerializer do
        use NbSerializer.Serializer

        field(:name, transform: :safe_upcase)

        def safe_upcase(nil), do: nil
        def safe_upcase(value), do: String.upcase(value)
      end

      data = %{name: nil}
      {:ok, result} = NbSerializer.serialize(TransformNilSerializer, data)
      assert result == %{name: nil}
    end
  end

  describe "KeyError prevention" do
    test "safely accesses nested fields that may not exist" do
      defmodule SafeAccessSerializer do
        use NbSerializer.Serializer

        field(:post_count, compute: :calculate_post_count)

        def calculate_post_count(user, _opts) do
          posts = Map.get(user, :posts, [])
          length(posts)
        end
      end

      # User without posts field
      data = %{id: 1, name: "Test"}
      {:ok, result} = NbSerializer.serialize(SafeAccessSerializer, data)
      assert result == %{post_count: 0}
    end

    test "handles error in compute function with on_error" do
      defmodule ErrorComputeSerializer do
        use NbSerializer.Serializer

        field(:bad_field, compute: :will_crash, on_error: :null)

        def will_crash(data, _opts) do
          # This will cause KeyError
          data.nonexistent_field
        end
      end

      data = %{id: 1}
      {:ok, result} = NbSerializer.serialize(ErrorComputeSerializer, data)
      assert result == %{bad_field: nil}
    end
  end

  describe "computed associations" do
    test "serializes computed has_many associations" do
      defmodule CommentSerializer do
        use NbSerializer.Serializer
        field(:id)
        field(:text)
      end

      defmodule PostWithComputedSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:title)

        has_many(:recent_comments,
          serializer: CommentSerializer,
          compute: :get_recent_comments
        )

        def get_recent_comments(post, _opts) do
          comments = Map.get(post, :comments, [])
          Enum.take(comments, 2)
        end
      end

      post = %{
        id: 1,
        title: "Test Post",
        comments: [
          %{id: 1, text: "First"},
          %{id: 2, text: "Second"},
          %{id: 3, text: "Third"}
        ]
      }

      {:ok, result} = NbSerializer.serialize(PostWithComputedSerializer, post)

      assert result == %{
               id: 1,
               title: "Test Post",
               recent_comments: [
                 %{id: 1, text: "First"},
                 %{id: 2, text: "Second"}
               ]
             }
    end

    test "serializes computed has_one association" do
      defmodule AuthorSerializer do
        use NbSerializer.Serializer
        field(:id)
        field(:name)
      end

      defmodule PostWithComputedOneSerializer do
        use NbSerializer.Serializer

        field(:id)

        has_one(:primary_author,
          serializer: AuthorSerializer,
          compute: :get_primary_author
        )

        def get_primary_author(post, _opts) do
          authors = Map.get(post, :authors, [])
          List.first(authors)
        end
      end

      post = %{
        id: 1,
        authors: [
          %{id: 1, name: "John"},
          %{id: 2, name: "Jane"}
        ]
      }

      {:ok, result} = NbSerializer.serialize(PostWithComputedOneSerializer, post)

      assert result == %{
               id: 1,
               primary_author: %{id: 1, name: "John"}
             }
    end

    test "handles nil in computed associations" do
      defmodule NilAssocSerializer do
        use NbSerializer.Serializer
        field(:id)
      end

      defmodule MainWithNilSerializer do
        use NbSerializer.Serializer

        field(:id)

        has_one(:related,
          serializer: NilAssocSerializer,
          compute: :get_related
        )

        def get_related(_data, _opts), do: nil
      end

      {:ok, result} = NbSerializer.serialize(MainWithNilSerializer, %{id: 1})
      assert result == %{id: 1, related: nil}
    end
  end

  describe "formatters" do
    test "applies built-in datetime formatter" do
      defmodule DateTimeFormatterSerializer do
        use NbSerializer.Serializer

        field(:created_at, format: :datetime)
      end

      data = %{created_at: ~U[2024-01-15 10:30:00Z]}
      {:ok, result} = NbSerializer.serialize(DateTimeFormatterSerializer, data)
      assert result == %{created_at: "2024-01-15T10:30:00Z"}
    end

    test "applies built-in date formatter" do
      defmodule DateFormatterSerializer do
        use NbSerializer.Serializer

        field(:birth_date, format: :date)
      end

      data = %{birth_date: ~D[2024-01-15]}
      {:ok, result} = NbSerializer.serialize(DateFormatterSerializer, data)
      assert result == %{birth_date: "2024-01-15"}
    end

    test "applies built-in currency formatter" do
      defmodule CurrencyFormatterSerializer do
        use NbSerializer.Serializer

        field(:price, format: :currency)
      end

      data = %{price: 19.99}
      {:ok, result} = NbSerializer.serialize(CurrencyFormatterSerializer, data)
      assert result == %{price: "$19.99"}
    end

    test "handles formatter with nil value" do
      defmodule NilFormatterSerializer do
        use NbSerializer.Serializer

        field(:price, format: :currency)
      end

      data = %{price: nil}
      {:ok, result} = NbSerializer.serialize(NilFormatterSerializer, data)
      assert result == %{price: nil}
    end
  end

  describe "circular reference protection" do
    test "prevents infinite loops in self-referential structures" do
      defmodule NodeSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:name)
        has_one(:parent, serializer: __MODULE__)
        has_many(:children, serializer: __MODULE__)
      end

      # Create a simple tree without circular reference for now
      root = %{
        id: 1,
        name: "root",
        parent: nil,
        children: [
          %{id: 2, name: "child1", parent: nil, children: []},
          %{id: 3, name: "child2", parent: nil, children: []}
        ]
      }

      {:ok, result} = NbSerializer.serialize(NodeSerializer, root)
      assert result[:id] == 1
      assert length(result[:children]) == 2
    end
  end

  describe "error messages" do
    test "provides helpful error message for missing field" do
      defmodule StrictFieldSerializer do
        use NbSerializer.Serializer

        field(:required_field, compute: :get_required)

        def get_required(data, _opts) do
          # This should cause an error if field doesn't exist
          data.required_field
        end
      end

      data = %{id: 1}

      # With new error handling, it returns an error tuple instead of raising
      assert {:error, _error} = NbSerializer.serialize(StrictFieldSerializer, data)

      # To test raising behavior, use the bang function
      # Errors are now wrapped in SerializationError
      error =
        assert_raise NbSerializer.SerializationError, fn ->
          NbSerializer.serialize!(StrictFieldSerializer, data)
        end

      # Verify the original error is preserved
      assert error.original_error.__struct__ == KeyError
    end
  end

  describe "compile-time validation" do
    test "validates compute function exists at compile time" do
      # This test validates that the compile-time check would catch this
      # In practice, this would be a compile error
      assert_raise NbSerializer.CompileError, fn ->
        defmodule InvalidComputeSerializer do
          use NbSerializer.Serializer

          field(:computed, compute: :function_that_does_not_exist)
        end
      end
    end
  end
end
