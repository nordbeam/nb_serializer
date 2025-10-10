# Run with: mix run bench/serialization_bench.exs

# Setup test data and serializers
defmodule BenchData do
  def simple_user do
    %{
      id: 1,
      name: "John Doe",
      email: "john@example.com",
      age: 30,
      active: true,
      created_at: ~U[2024-01-01 00:00:00Z],
      updated_at: ~U[2024-01-15 00:00:00Z]
    }
  end

  def user_with_posts do
    %{
      id: 1,
      name: "Jane Author",
      email: "jane@example.com",
      posts: [
        %{
          id: 1,
          title: "First Post",
          body: "This is the body of the first post",
          published: true,
          comments: [
            %{id: 1, body: "Great post!", author: "Reader1"},
            %{id: 2, body: "Thanks for sharing", author: "Reader2"}
          ]
        },
        %{
          id: 2,
          title: "Second Post",
          body: "This is the body of the second post",
          published: false,
          comments: []
        }
      ]
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

  def ecto_schema do
    # Simulate an Ecto schema struct
    %{
      __struct__: Ecto.Schema,
      __meta__: %Ecto.Schema.Metadata{state: :loaded, source: "users"},
      id: 1,
      name: "Ecto User",
      email: "ecto@example.com",
      posts: %Ecto.Association.NotLoaded{
        __field__: :posts,
        __owner__: User,
        __cardinality__: :many
      }
    }
  end
end

# Define serializers for benchmarking
defmodule SimpleUserSerializer do
  use NbSerializer.Serializer

  schema do
    field(:id)
    field(:name)
    field(:email)
  end
end

defmodule UserWithComputedSerializer do
  use NbSerializer.Serializer

  schema do
    field(:id)
    field(:name)
    field(:email)
    field(:display_name, compute: :format_display_name)
    field(:account_age, compute: :calculate_age)
  end

  def format_display_name(user, _opts) do
    String.upcase(user.name)
  end

  def calculate_age(user, _opts) do
    days = DateTime.diff(DateTime.utc_now(), user.created_at, :day)
    "#{days} days"
  end
end

defmodule ConditionalUserSerializer do
  use NbSerializer.Serializer

  schema do
    field(:id)
    field(:name)
    field(:email, if: :show_email?)
    field(:age, if: :show_private?)
    field(:active, unless: :hide_status?)
  end

  def show_email?(_user, opts), do: opts[:show_email]
  def show_private?(_user, opts), do: opts[:admin]
  def hide_status?(_user, opts), do: opts[:minimal]
end

defmodule CommentSerializer do
  use NbSerializer.Serializer

  schema do
    field(:id)
    field(:body)
    field(:author)
  end
end

defmodule PostSerializer do
  use NbSerializer.Serializer

  schema do
    field(:id)
    field(:title)
    field(:body)
    has_many(:comments, serializer: CommentSerializer)
  end
end

defmodule UserWithPostsSerializer do
  use NbSerializer.Serializer

  schema do
    field(:id)
    field(:name)
    field(:email)
    has_many(:posts, serializer: PostSerializer)
  end
end

defmodule EctoUserSerializer do
  use NbSerializer.Serializer
  use NbSerializer.Ecto

  schema do
    field(:id)
    field(:name)
    field(:email)
  end
end

# Manual serialization functions for comparison
defmodule ManualSerializer do
  def simple_user(user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email
    }
  end

  def user_with_computed(user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      display_name: String.upcase(user.name),
      account_age: "#{DateTime.diff(DateTime.utc_now(), user.created_at, :day)} days"
    }
  end

  def users_list(users) do
    Enum.map(users, &simple_user/1)
  end
end

# Run benchmarks
Benchee.run(
  %{
    "NbSerializer - Simple" => fn input ->
      NbSerializer.serialize(SimpleUserSerializer, input)
    end,
    "Manual - Simple" => fn input ->
      ManualSerializer.simple_user(input)
    end,
    "Map.take - Simple" => fn input ->
      Map.take(input, [:id, :name, :email])
    end
  },
  inputs: %{
    "Single User" => BenchData.simple_user()
  },
  time: 5,
  memory_time: 2,
  warmup: 2
)

Benchee.run(
  %{
    "NbSerializer - Computed Fields" => fn input ->
      NbSerializer.serialize(UserWithComputedSerializer, input)
    end,
    "Manual - Computed Fields" => fn input ->
      ManualSerializer.user_with_computed(input)
    end
  },
  inputs: %{
    "User with Timestamps" =>
      Map.put(BenchData.simple_user(), :created_at, ~U[2024-01-01 00:00:00Z])
  },
  time: 5,
  memory_time: 2,
  warmup: 2
)

Benchee.run(
  %{
    "NbSerializer - Conditional (all fields)" => fn input ->
      NbSerializer.serialize(ConditionalUserSerializer, input, show_email: true, admin: true)
    end,
    "NbSerializer - Conditional (minimal)" => fn input ->
      NbSerializer.serialize(ConditionalUserSerializer, input, minimal: true)
    end,
    "Manual - Conditional check" => fn input ->
      result = %{id: input.id, name: input.name}
      result = if true, do: Map.put(result, :email, input.email), else: result
      result = if true, do: Map.put(result, :age, input.age), else: result
      result
    end
  },
  inputs: %{
    "User" => BenchData.simple_user()
  },
  time: 5,
  memory_time: 2,
  warmup: 2
)

Benchee.run(
  %{
    "NbSerializer - Nested Relationships" => fn input ->
      NbSerializer.serialize(UserWithPostsSerializer, input)
    end,
    "Manual - Nested" => fn input ->
      %{
        id: input.id,
        name: input.name,
        email: input.email,
        posts:
          Enum.map(input.posts, fn post ->
            %{
              id: post.id,
              title: post.title,
              body: post.body,
              comments:
                Enum.map(post.comments, fn comment ->
                  %{id: comment.id, body: comment.body, author: comment.author}
                end)
            }
          end)
      }
    end
  },
  inputs: %{
    "User with 2 posts" => BenchData.user_with_posts()
  },
  time: 5,
  memory_time: 2,
  warmup: 2
)

# Benchmark collection serialization
Benchee.run(
  %{
    "NbSerializer - 10 users" => fn input ->
      NbSerializer.serialize(SimpleUserSerializer, input)
    end,
    "Manual - 10 users" => fn input ->
      ManualSerializer.users_list(input)
    end
  },
  inputs: %{
    "10 Users" => BenchData.users_list(10)
  },
  time: 5,
  memory_time: 2,
  warmup: 2
)

Benchee.run(
  %{
    "NbSerializer - 100 users" => fn input ->
      NbSerializer.serialize(SimpleUserSerializer, input)
    end,
    "Manual - 100 users" => fn input ->
      ManualSerializer.users_list(input)
    end
  },
  inputs: %{
    "100 Users" => BenchData.users_list(100)
  },
  time: 5,
  memory_time: 2,
  warmup: 2
)

Benchee.run(
  %{
    "NbSerializer - 1000 users" => fn input ->
      NbSerializer.serialize(SimpleUserSerializer, input)
    end,
    "Manual - 1000 users" => fn input ->
      ManualSerializer.users_list(input)
    end
  },
  inputs: %{
    "1000 Users" => BenchData.users_list(1000)
  },
  time: 5,
  memory_time: 2,
  warmup: 2
)

# JSON encoding benchmark
Benchee.run(
  %{
    "NbSerializer.serialize! (with JSON)" => fn input ->
      NbSerializer.serialize!(SimpleUserSerializer, input)
    end,
    "NbSerializer + Jason.encode!" => fn input ->
      input |> NbSerializer.serialize(SimpleUserSerializer) |> Jason.encode!()
    end,
    "Manual + Jason.encode!" => fn input ->
      input |> ManualSerializer.simple_user() |> Jason.encode!()
    end
  },
  inputs: %{
    "User" => BenchData.simple_user()
  },
  time: 5,
  memory_time: 2,
  warmup: 2
)

IO.puts("\n\n=== Benchmark Summary ===")

IO.puts(
  "NbSerializer serialization performance compared to manual serialization and native Map operations."
)

IO.puts("Lower values are better. Focus on the 'ips' (iterations per second) metric.")
