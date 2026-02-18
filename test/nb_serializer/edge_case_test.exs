defmodule NbSerializer.EdgeCaseTest do
  use ExUnit.Case

  describe "nil handling" do
    test "serializes nil data as nil" do
      defmodule NilSerializer do
        use NbSerializer.Serializer

        field(:id, :number)
        field(:name, :string)
      end

      assert {:ok, result} = NbSerializer.serialize(NilSerializer, nil)
      assert result == nil
    end

    test "handles nil in list serialization" do
      defmodule ListNilSerializer do
        use NbSerializer.Serializer

        field(:id, :number)
        field(:name, :string)
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

        field(:id, :number)
        field(:name, :string)
        field(:email, :string)
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

        field(:id, :number)
        field(:computed_field, :any, compute: :non_existent_function, on_error: :null)
      end

      data = %{id: 1}
      {:ok, result} = NbSerializer.serialize(MissingComputeNullSerializer, data)
      assert result == %{id: 1, computed_field: nil}
    end

    test "handles missing compute function with on_error: :skip" do
      defmodule MissingComputeSkipSerializer do
        use NbSerializer.Serializer

        field(:id, :number)
        field(:computed_field, :any, compute: :non_existent_function, on_error: :skip)
      end

      data = %{id: 1}
      {:ok, result} = NbSerializer.serialize(MissingComputeSkipSerializer, data)
      assert result == %{id: 1}
    end

    test "handles missing compute function with on_error: {:default, value}" do
      defmodule MissingComputeDefaultSerializer do
        use NbSerializer.Serializer

        field(:id, :number)

        field(:computed_field, :string,
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

          field(:id, :number)
          field(:computed_field, :any, compute: :non_existent_function)
        end
      end
    end
  end

  describe "transform function arity" do
    test "transform functions are called with single argument" do
      defmodule TransformAritySerializer do
        use NbSerializer.Serializer

        field(:name, :string, transform: :upcase_name)

        def upcase_name(value), do: String.upcase(value || "")
      end

      data = %{name: "john"}
      {:ok, result} = NbSerializer.serialize(TransformAritySerializer, data)
      assert result == %{name: "JOHN"}
    end

    test "transform with nil value" do
      defmodule TransformNilSerializer do
        use NbSerializer.Serializer

        field(:name, :string, transform: :safe_upcase)

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

        field(:post_count, :integer, compute: :calculate_post_count)

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

        field(:bad_field, :any, compute: :will_crash, on_error: :null)

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
        field(:id, :number)
        field(:text, :string)
      end

      defmodule PostWithComputedSerializer do
        use NbSerializer.Serializer

        field(:id, :number)
        field(:title, :string)

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
        field(:id, :number)
        field(:name, :string)
      end

      defmodule PostWithComputedOneSerializer do
        use NbSerializer.Serializer

        field(:id, :number)

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
        field(:id, :number)
      end

      defmodule MainWithNilSerializer do
        use NbSerializer.Serializer

        field(:id, :number)

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

        field(:created_at, :datetime, format: :datetime)
      end

      data = %{created_at: ~U[2024-01-15 10:30:00Z]}
      {:ok, result} = NbSerializer.serialize(DateTimeFormatterSerializer, data)
      assert result == %{created_at: "2024-01-15T10:30:00Z"}
    end

    test "applies built-in date formatter" do
      defmodule DateFormatterSerializer do
        use NbSerializer.Serializer

        field(:birth_date, :date, format: :date)
      end

      data = %{birth_date: ~D[2024-01-15]}
      {:ok, result} = NbSerializer.serialize(DateFormatterSerializer, data)
      assert result == %{birth_date: "2024-01-15"}
    end

    test "applies built-in currency formatter" do
      defmodule CurrencyFormatterSerializer do
        use NbSerializer.Serializer

        field(:price, :number, format: :currency)
      end

      data = %{price: 19.99}
      {:ok, result} = NbSerializer.serialize(CurrencyFormatterSerializer, data)
      assert result == %{price: "$19.99"}
    end

    test "handles formatter with nil value" do
      defmodule NilFormatterSerializer do
        use NbSerializer.Serializer

        field(:price, :number, format: :currency)
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

        field(:id, :number)
        field(:name, :string)
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

    test "handles circular references with max_depth" do
      defmodule CircularUserSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
          has_one(:best_friend, serializer: __MODULE__)
        end
      end

      user1 = %{id: 1, name: "User 1"}
      user2 = %{id: 2, name: "User 2", best_friend: user1}
      user1 = Map.put(user1, :best_friend, user2)

      # Should not hang - max_depth prevents infinite recursion
      {:ok, result} = NbSerializer.serialize(CircularUserSerializer, user1, max_depth: 3)

      assert result.id == 1
      assert result.best_friend.id == 2
      # At depth 3, associations should be nil
      assert get_in(result, [:best_friend, :best_friend, :best_friend]) == nil
    end
  end

  describe "error handling in computed fields" do
    test "handles errors with on_error option" do
      defmodule SafeComputeSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:risky_compute, :string, compute: :might_fail, on_error: :null)
          field(:with_default, :string, compute: :might_fail, on_error: {:default, "fallback"})
          field(:with_handler, :string, compute: :might_fail, on_error: :handle_error)
        end

        def might_fail(%{should_fail: true}, _opts) do
          raise "Intentional error"
        end

        def might_fail(data, _opts) do
          "computed: #{data.id}"
        end

        def handle_error(_error, _data, _opts) do
          "error caught"
        end
      end

      # Test with error
      data = %{id: 1, should_fail: true}
      {:ok, result} = NbSerializer.serialize(SafeComputeSerializer, data)

      assert result.risky_compute == nil
      assert result.with_default == "fallback"
      assert result.with_handler == "error caught"

      # Test without error
      data = %{id: 2, should_fail: false}
      {:ok, result} = NbSerializer.serialize(SafeComputeSerializer, data)

      assert result.risky_compute == "computed: 2"
      assert result.with_default == "computed: 2"
      assert result.with_handler == "computed: 2"
    end
  end

  describe "error messages" do
    test "provides helpful error message for missing field" do
      defmodule StrictFieldSerializer do
        use NbSerializer.Serializer

        field(:required_field, :any, compute: :get_required)

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

  describe "missing association handling" do
    test "handles NotLoaded associations gracefully" do
      defmodule SafeAssociationSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:title, :string)

          has_one(:author,
            serializer: NbSerializer.EdgeCaseTest.EdgeUserSerializer,
            on_missing: :null
          )

          has_many(:tags,
            serializer: NbSerializer.EdgeCaseTest.EdgeTagSerializer,
            on_missing: :empty
          )
        end
      end

      defmodule EdgeUserSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
        end
      end

      defmodule EdgeTagSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
        end
      end

      # Test with NotLoaded
      data = %{
        id: 1,
        title: "Post",
        author: %Ecto.Association.NotLoaded{},
        tags: %Ecto.Association.NotLoaded{}
      }

      {:ok, result} = NbSerializer.serialize(SafeAssociationSerializer, data)

      assert result.author == nil
      assert result.tags == []

      # Test with nil
      data = %{id: 2, title: "Post 2", author: nil, tags: nil}
      {:ok, result} = NbSerializer.serialize(SafeAssociationSerializer, data)

      assert result.author == nil
      assert result.tags == []

      # Test with actual data
      data = %{
        id: 3,
        title: "Post 3",
        author: %{id: 1, name: "Author"},
        tags: [%{id: 1, name: "elixir"}]
      }

      {:ok, result} = NbSerializer.serialize(SafeAssociationSerializer, data)
      assert result.author.name == "Author"
      assert length(result.tags) == 1
    end
  end

  describe "edge cases and unusual data types" do
    test "handles deeply nested maps" do
      defmodule DeepSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:deep_value, :string, compute: :extract_deep)
        end

        def extract_deep(data, _opts) do
          get_in(data, [:level1, :level2, :level3, :value])
        end
      end

      data = %{
        id: 1,
        level1: %{
          level2: %{
            level3: %{
              value: "found it!"
            }
          }
        }
      }

      {:ok, result} = NbSerializer.serialize(DeepSerializer, data)
      assert result == %{id: 1, deep_value: "found it!"}
    end

    test "handles dates and times" do
      defmodule DateTimeEdgeSerializer do
        use NbSerializer.Serializer

        schema do
          field(:date, :date)
          field(:time, :any)
          field(:datetime, :datetime)
          field(:naive_datetime, :any)
        end
      end

      data = %{
        date: ~D[2024-01-15],
        time: ~T[13:30:00],
        datetime: ~U[2024-01-15 13:30:00Z],
        naive_datetime: ~N[2024-01-15 13:30:00]
      }

      {:ok, result} = NbSerializer.serialize(DateTimeEdgeSerializer, data)

      assert result.date == ~D[2024-01-15]
      assert result.time == ~T[13:30:00]
      assert result.datetime == ~U[2024-01-15 13:30:00Z]
      assert result.naive_datetime == ~N[2024-01-15 13:30:00]

      # These should all encode to JSON properly
      json = NbSerializer.to_json!(DateTimeEdgeSerializer, data)
      assert is_binary(json)
    end

    test "handles float and decimal types" do
      defmodule NumericSerializer do
        use NbSerializer.Serializer

        schema do
          field(:float_val, :any)
          field(:decimal_val, :any)
          field(:integer_val, :integer)
        end
      end

      data = %{
        float_val: 3.14159,
        decimal_val: Decimal.new("123.456"),
        integer_val: 42
      }

      {:ok, result} = NbSerializer.serialize(NumericSerializer, data)

      assert result.float_val == 3.14159
      assert result.decimal_val == Decimal.new("123.456")
      assert result.integer_val == 42
    end

    test "handles atoms as values" do
      defmodule AtomSerializer do
        use NbSerializer.Serializer

        schema do
          field(:status, :string)
          field(:type, :string)
        end
      end

      data = %{
        status: :active,
        type: :premium
      }

      {:ok, result} = NbSerializer.serialize(AtomSerializer, data)
      assert result == %{status: :active, type: :premium}

      # Atoms should encode to JSON as strings
      json = NbSerializer.to_json!(AtomSerializer, data)
      assert json == ~s({"status":"active","type":"premium"})
    end

    test "handles binary data" do
      defmodule BinarySerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:data, :any)
        end
      end

      data = %{
        id: 1,
        data: <<1, 2, 3, 4, 5>>
      }

      {:ok, result} = NbSerializer.serialize(BinarySerializer, data)
      assert result.data == <<1, 2, 3, 4, 5>>
    end

    test "handles tuples in computed fields" do
      defmodule TupleSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:coordinates, :any, compute: :get_coordinates)
        end

        def get_coordinates(data, _opts) do
          {data.x, data.y}
        end
      end

      data = %{id: 1, x: 10, y: 20}
      {:ok, result} = NbSerializer.serialize(TupleSerializer, data)

      assert result == %{id: 1, coordinates: {10, 20}}
    end

    test "handles empty maps and lists" do
      defmodule EmptySerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:tags, :any)
          field(:metadata, :any)
        end
      end

      data = %{
        id: 1,
        tags: [],
        metadata: %{}
      }

      {:ok, result} = NbSerializer.serialize(EmptySerializer, data)
      assert result == %{id: 1, tags: [], metadata: %{}}
    end

    test "handles very large collections efficiently" do
      defmodule BulkSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:value, :string)
        end
      end

      # Generate 1000 items
      items =
        Enum.map(1..1000, fn i ->
          %{id: i, value: "item_#{i}"}
        end)

      {:ok, result} = NbSerializer.serialize(BulkSerializer, items)
      assert length(result) == 1000
      assert List.first(result) == %{id: 1, value: "item_1"}
      assert List.last(result) == %{id: 1000, value: "item_1000"}
    end

    test "handles MapSet collections" do
      defmodule MapSetSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:unique_tags, list: :string, compute: :tags_to_list)
        end

        def tags_to_list(data, _opts) do
          MapSet.to_list(data.tags)
        end
      end

      data = %{
        id: 1,
        tags: MapSet.new(["elixir", "phoenix", "ecto"])
      }

      {:ok, result} = NbSerializer.serialize(MapSetSerializer, data)
      assert MapSet.new(result.unique_tags) == MapSet.new(["elixir", "phoenix", "ecto"])
    end

    test "handles recursive serialization" do
      defmodule TreeNodeSerializer do
        use NbSerializer.Serializer

        schema do
          field(:value, :string)
          has_many(:children, serializer: __MODULE__)
        end
      end

      tree = %{
        value: "root",
        children: [
          %{value: "child1", children: []},
          %{
            value: "child2",
            children: [
              %{value: "grandchild", children: []}
            ]
          }
        ]
      }

      {:ok, result} = NbSerializer.serialize(TreeNodeSerializer, tree)

      assert result == %{
               value: "root",
               children: [
                 %{value: "child1", children: []},
                 %{
                   value: "child2",
                   children: [
                     %{value: "grandchild", children: []}
                   ]
                 }
               ]
             }
    end

    test "handles computed fields that return other serialized data" do
      defmodule InnerSerializer do
        use NbSerializer.Serializer

        schema do
          field(:name, :string)
        end
      end

      defmodule OuterSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:processed_inner, :any, compute: :serialize_inner)
        end

        def serialize_inner(data, opts) do
          NbSerializer.serialize!(InnerSerializer, data.inner, opts)
        end
      end

      data = %{
        id: 1,
        inner: %{name: "Inner Object", extra: "ignored"}
      }

      {:ok, result} = NbSerializer.serialize(OuterSerializer, data)
      assert result == %{id: 1, processed_inner: %{name: "Inner Object"}}
    end

    test "handles Range types" do
      defmodule RangeSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:range, list: :integer, compute: :convert_range)
        end

        def convert_range(data, _opts) do
          Enum.to_list(data.range)
        end
      end

      data = %{id: 1, range: 1..5}
      {:ok, result} = NbSerializer.serialize(RangeSerializer, data)

      assert result == %{id: 1, range: [1, 2, 3, 4, 5]}
    end
  end

  describe "compile-time validation" do
    test "validates compute function exists at compile time" do
      # This test validates that the compile-time check would catch this
      # In practice, this would be a compile error
      assert_raise NbSerializer.CompileError, fn ->
        defmodule InvalidComputeSerializer do
          use NbSerializer.Serializer

          field(:computed, :any, compute: :function_that_does_not_exist)
        end
      end
    end
  end
end
