# Quick performance benchmark for NbSerializer
# Run with: mix run bench/quick_bench.exs

defmodule QuickBench do
  defmodule SimpleSerializer do
    use NbSerializer.Serializer

    schema do
      field(:id)
      field(:name)
      field(:email)
    end
  end

  defmodule ComputedSerializer do
    use NbSerializer.Serializer

    schema do
      field(:id)
      field(:name)
      field(:display_name, compute: :upcase_name)
    end

    def upcase_name(user, _opts) do
      String.upcase(user.name)
    end
  end

  def manual_serialize(user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email
    }
  end

  def test_data do
    %{
      id: 1,
      name: "John Doe",
      email: "john@example.com",
      age: 30,
      active: true
    }
  end

  def users_list(count) do
    Enum.map(1..count, fn i ->
      %{
        id: i,
        name: "User #{i}",
        email: "user#{i}@example.com",
        age: 20 + rem(i, 50),
        active: rem(i, 2) == 0
      }
    end)
  end
end

# Single object benchmarks
IO.puts("\n=== SINGLE OBJECT SERIALIZATION ===\n")

Benchee.run(
  %{
    "NbSerializer" => fn -> NbSerializer.serialize(QuickBench.SimpleSerializer, QuickBench.test_data()) end,
    "Manual" => fn -> QuickBench.manual_serialize(QuickBench.test_data()) end,
    "Map.take" => fn -> Map.take(QuickBench.test_data(), [:id, :name, :email]) end
  },
  time: 2,
  warmup: 1,
  print: [fast_warning: false]
)

# Collection benchmarks
IO.puts("\n=== COLLECTION SERIALIZATION (100 items) ===\n")

users_100 = QuickBench.users_list(100)

Benchee.run(
  %{
    "NbSerializer - 100 items" => fn ->
      NbSerializer.serialize(QuickBench.SimpleSerializer, users_100)
    end,
    "Manual - 100 items" => fn ->
      Enum.map(users_100, &QuickBench.manual_serialize/1)
    end
  },
  time: 2,
  warmup: 1
)

# Computed fields benchmark
IO.puts("\n=== COMPUTED FIELDS ===\n")

Benchee.run(
  %{
    "NbSerializer - Computed" => fn ->
      NbSerializer.serialize(QuickBench.ComputedSerializer, QuickBench.test_data())
    end,
    "Manual - Computed" => fn ->
      user = QuickBench.test_data()

      %{
        id: user.id,
        name: user.name,
        display_name: String.upcase(user.name)
      }
    end
  },
  time: 2,
  warmup: 1
)

# JSON encoding benchmark
IO.puts("\n=== JSON ENCODING ===\n")

Benchee.run(
  %{
    "NbSerializer.serialize!" => fn ->
      NbSerializer.serialize!(QuickBench.SimpleSerializer, QuickBench.test_data())
    end,
    "Manual + Jason" => fn ->
      QuickBench.test_data()
      |> QuickBench.manual_serialize()
      |> Jason.encode!()
    end
  },
  time: 2,
  warmup: 1
)

IO.puts("\n=== PERFORMANCE SUMMARY ===")
IO.puts("NbSerializer adds overhead compared to manual serialization due to:")
IO.puts("  1. Dynamic field lookup and transformation")
IO.puts("  2. Conditional evaluation for each field")
IO.puts("  3. Module function calls for computed fields")
IO.puts("\nHowever, NbSerializer provides:")
IO.puts("  ✓ Declarative, maintainable serializers")
IO.puts("  ✓ Automatic handling of nil values and defaults")
IO.puts("  ✓ Built-in Ecto support")
IO.puts("  ✓ Conditional field inclusion")
IO.puts("  ✓ Nested relationship handling")
