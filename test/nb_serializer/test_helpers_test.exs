defmodule NbSerializer.TestHelpersTest do
  use ExUnit.Case, async: true

  import NbSerializer.TestHelpers

  # Test data structures
  defmodule User do
    defstruct [:id, :name, :email, :password, :internal_data]
  end

  defmodule Post do
    defstruct [:id, :title, :body, :user]
  end

  # Test serializers
  defmodule UserSerializer do
    use NbSerializer.Serializer

    schema do
      field(:id, :number)
      field(:name, :string)
      field(:email, :string)
    end
  end

  defmodule PostSerializer do
    use NbSerializer.Serializer

    schema do
      field(:id, :number)
      field(:title, :string)
      field(:excerpt, :string, from: :body)
    end
  end

  defmodule DetailedPostSerializer do
    use NbSerializer.Serializer

    schema do
      field(:id, :number)
      field(:title, :string)
      field(:body, :string)
      has_one(:user, serializer: UserSerializer)
    end
  end

  describe "serialize!/3" do
    test "serializes data successfully" do
      user = %User{id: 1, name: "Alice", email: "alice@example.com", password: "secret"}
      json = serialize!(UserSerializer, user)

      assert json == %{id: 1, name: "Alice", email: "alice@example.com"}
    end

    test "serializes with options" do
      user = %User{id: 1, name: "Alice", email: "alice@example.com"}
      json = serialize!(UserSerializer, user, camelize: false)

      assert is_map(json)
    end
  end

  describe "assert_serialized_fields/2" do
    test "passes when all fields are present" do
      user = %User{id: 1, name: "Alice", email: "alice@example.com"}
      json = serialize!(UserSerializer, user)

      assert assert_serialized_fields(json, [:id, :name, :email]) == true
    end

    test "passes with string keys" do
      json = %{"id" => 1, "name" => "Alice", "email" => "alice@example.com"}

      assert assert_serialized_fields(json, ["id", "name", "email"]) == true
    end

    test "passes when checking subset of fields" do
      user = %User{id: 1, name: "Alice", email: "alice@example.com"}
      json = serialize!(UserSerializer, user)

      # Only check some fields
      assert assert_serialized_fields(json, [:id, :name]) == true
    end

    test "fails when fields are missing" do
      json = %{id: 1, name: "Alice"}

      assert_raise ExUnit.AssertionError, ~r/missing: \[:email\]/, fn ->
        assert_serialized_fields(json, [:id, :name, :email])
      end
    end

    test "provides helpful error message for lists" do
      json = [%{id: 1}, %{id: 2}]

      assert_raise ExUnit.AssertionError, ~r/expects a map, but got a list/, fn ->
        assert_serialized_fields(json, [:id])
      end
    end
  end

  describe "assert_serialized_field/3" do
    test "passes when field value matches" do
      user = %User{id: 1, name: "Alice", email: "alice@example.com"}
      json = serialize!(UserSerializer, user)

      assert assert_serialized_field(json, :id, 1) == true
      assert assert_serialized_field(json, :name, "Alice") == true
      assert assert_serialized_field(json, :email, "alice@example.com") == true
    end

    test "works with string keys" do
      json = %{"name" => "Alice", "email" => "alice@example.com"}

      assert assert_serialized_field(json, "name", "Alice") == true
    end

    test "handles camelCase conversion" do
      json = %{userId: 42, totalCount: 100}

      # Can assert using snake_case even when field is camelCase
      assert assert_serialized_field(json, :user_id, 42) == true
      assert assert_serialized_field(json, :total_count, 100) == true
    end

    test "fails when field value doesn't match" do
      json = %{id: 1, name: "Alice"}

      assert_raise ExUnit.AssertionError, ~r/Expected field :name to equal "Bob"/, fn ->
        assert_serialized_field(json, :name, "Bob")
      end
    end

    test "fails when field doesn't exist" do
      json = %{id: 1, name: "Alice"}

      assert_raise ExUnit.AssertionError, ~r/Field :email not found/, fn ->
        assert_serialized_field(json, :email, "test@example.com")
      end
    end

    test "provides helpful error message for lists" do
      json = [%{id: 1}, %{id: 2}]

      assert_raise ExUnit.AssertionError, ~r/expects a map, but got a list/, fn ->
        assert_serialized_field(json, :id, 1)
      end
    end
  end

  describe "refute_serialized_field/2" do
    test "passes when field is not present" do
      user = %User{id: 1, name: "Alice", email: "alice@example.com", password: "secret"}
      json = serialize!(UserSerializer, user)

      assert refute_serialized_field(json, :password) == true
      assert refute_serialized_field(json, :internal_data) == true
    end

    test "fails when field is present" do
      json = %{id: 1, password: "secret"}

      assert_raise ExUnit.AssertionError, ~r/Expected field :password to NOT be present/, fn ->
        refute_serialized_field(json, :password)
      end
    end

    test "provides helpful error message for lists" do
      json = [%{id: 1}, %{id: 2}]

      assert_raise ExUnit.AssertionError, ~r/expects a map, but got a list/, fn ->
        refute_serialized_field(json, :password)
      end
    end
  end

  describe "assert_serialized_structure/2" do
    test "passes when structure matches exactly" do
      user = %User{id: 1, name: "Alice", email: "alice@example.com"}
      json = serialize!(UserSerializer, user)

      assert assert_serialized_structure(json, %{
               id: 1,
               name: "Alice",
               email: "alice@example.com"
             }) == true
    end

    test "passes when checking partial structure" do
      user = %User{id: 1, name: "Alice", email: "alice@example.com"}
      json = serialize!(UserSerializer, user)

      # Only check some fields - others are ignored
      assert assert_serialized_structure(json, %{
               id: 1,
               name: "Alice"
             }) == true
    end

    test "works with nested structures" do
      post = %Post{
        id: 1,
        title: "Hello",
        body: "World",
        user: %User{id: 2, name: "Bob", email: "bob@example.com"}
      }

      json = serialize!(DetailedPostSerializer, post)

      assert assert_serialized_structure(json, %{
               id: 1,
               title: "Hello",
               user: %{
                 id: 2,
                 name: "Bob"
               }
             }) == true
    end

    test "works with lists" do
      users = [
        %User{id: 1, name: "Alice", email: "alice@example.com"},
        %User{id: 2, name: "Bob", email: "bob@example.com"}
      ]

      json = serialize!(UserSerializer, users)

      assert assert_serialized_structure(json, [
               %{id: 1, name: "Alice", email: "alice@example.com"},
               %{id: 2, name: "Bob", email: "bob@example.com"}
             ]) == true
    end

    test "fails when structure doesn't match" do
      json = %{id: 1, name: "Alice"}

      assert_raise ExUnit.AssertionError, fn ->
        assert_serialized_structure(json, %{
          id: 1,
          name: "Bob"
        })
      end
    end

    test "fails when list length doesn't match" do
      json = [%{id: 1}, %{id: 2}]

      assert_raise ExUnit.AssertionError, ~r/Expected list to have 3 items, but got 2/, fn ->
        assert_serialized_structure(json, [%{id: 1}, %{id: 2}, %{id: 3}])
      end
    end

    test "fails when nested structure doesn't match" do
      json = %{
        id: 1,
        user: %{id: 2, name: "Alice"}
      }

      assert_raise ExUnit.AssertionError, fn ->
        assert_serialized_structure(json, %{
          id: 1,
          user: %{id: 2, name: "Bob"}
        })
      end
    end
  end

  describe "camelCase and snake_case conversion" do
    test "handles snake_case fields when checking camelCase" do
      json = %{user_id: 42, total_count: 100}

      # Can query using camelCase even when field is snake_case
      assert assert_serialized_field(json, :userId, 42) == true
      assert assert_serialized_field(json, :totalCount, 100) == true
    end

    test "handles camelCase fields when checking snake_case" do
      json = %{userId: 42, totalCount: 100}

      # Can query using snake_case even when field is camelCase
      assert assert_serialized_field(json, :user_id, 42) == true
      assert assert_serialized_field(json, :total_count, 100) == true
    end
  end

  describe "real-world usage examples" do
    test "validates serializer excludes sensitive data" do
      user = %User{
        id: 1,
        name: "Alice",
        email: "alice@example.com",
        password: "secret123",
        internal_data: %{notes: "internal"}
      }

      json = serialize!(UserSerializer, user)

      # Assert expected fields are present
      assert_serialized_fields(json, [:id, :name, :email])

      # Assert sensitive fields are NOT present
      refute_serialized_field(json, :password)
      refute_serialized_field(json, :internal_data)
    end

    test "validates field transformation" do
      post = %Post{id: 1, title: "Hello", body: "This is a long body"}
      json = serialize!(PostSerializer, post)

      # Check that 'body' is transformed to 'excerpt'
      assert_serialized_field(json, :excerpt, "This is a long body")
      refute_serialized_field(json, :body)
    end

    test "validates nested serialization" do
      post = %Post{
        id: 1,
        title: "My Post",
        body: "Content",
        user: %User{id: 2, name: "Alice", email: "alice@example.com"}
      }

      json = serialize!(DetailedPostSerializer, post)

      # Use structure assertion for nested data
      assert_serialized_structure(json, %{
        id: 1,
        title: "My Post",
        user: %{
          id: 2,
          name: "Alice",
          email: "alice@example.com"
        }
      })

      # Ensure nested serializer also excludes sensitive data
      refute_serialized_field(json.user, :password)
    end
  end
end
