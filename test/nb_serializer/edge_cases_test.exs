defmodule NbSerializer.EdgeCasesTest do
  use ExUnit.Case

  describe "circular reference detection" do
    test "handles circular references with max_depth" do
      defmodule CircularUserSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:name)
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
          field(:id)
          field(:risky_compute, compute: :might_fail, on_error: :null)
          field(:with_default, compute: :might_fail, on_error: {:default, "fallback"})
          field(:with_handler, compute: :might_fail, on_error: :handle_error)
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

  describe "missing association handling" do
    test "handles NotLoaded associations gracefully" do
      defmodule SafeAssociationSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:title)

          has_one(:author,
            serializer: NbSerializer.EdgeCasesTest.UserSerializer,
            on_missing: :null
          )

          has_many(:tags,
            serializer: NbSerializer.EdgeCasesTest.TagSerializer,
            on_missing: :empty
          )
        end
      end

      defmodule UserSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:name)
        end
      end

      defmodule TagSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:name)
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
          field(:id)
          field(:deep_value, compute: :extract_deep)
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
      defmodule DateTimeSerializer do
        use NbSerializer.Serializer

        schema do
          field(:date)
          field(:time)
          field(:datetime)
          field(:naive_datetime)
        end
      end

      data = %{
        date: ~D[2024-01-15],
        time: ~T[13:30:00],
        datetime: ~U[2024-01-15 13:30:00Z],
        naive_datetime: ~N[2024-01-15 13:30:00]
      }

      {:ok, result} = NbSerializer.serialize(DateTimeSerializer, data)

      assert result.date == ~D[2024-01-15]
      assert result.time == ~T[13:30:00]
      assert result.datetime == ~U[2024-01-15 13:30:00Z]
      assert result.naive_datetime == ~N[2024-01-15 13:30:00]

      # These should all encode to JSON properly
      json = NbSerializer.to_json!(DateTimeSerializer, data)
      assert is_binary(json)
    end

    test "handles float and decimal types" do
      defmodule NumericSerializer do
        use NbSerializer.Serializer

        schema do
          field(:float_val)
          field(:decimal_val)
          field(:integer_val)
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
          field(:status)
          field(:type)
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
          field(:id)
          field(:data)
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
          field(:id)
          field(:coordinates, compute: :get_coordinates)
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
          field(:id)
          field(:tags)
          field(:metadata)
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
          field(:id)
          field(:value)
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
          field(:id)
          field(:unique_tags, compute: :tags_to_list)
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
          field(:value)
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
          field(:name)
        end
      end

      defmodule OuterSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:processed_inner, compute: :serialize_inner)
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
          field(:id)
          field(:range, compute: :convert_range)
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
end
