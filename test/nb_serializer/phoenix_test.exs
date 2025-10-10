defmodule NbSerializer.PhoenixTest do
  use ExUnit.Case

  defmodule UserSerializer do
    use NbSerializer.Serializer

    schema do
      field(:id)
      field(:name)
      field(:email)
    end
  end

  defmodule PostSerializer do
    use NbSerializer.Serializer

    schema do
      field(:id)
      field(:title)
      field(:body)
      has_one(:author, serializer: UserSerializer)
    end
  end

  # Test module that simulates a Phoenix JSON view
  defmodule UserJSON do
    use NbSerializer.Phoenix

    def index(%{users: users}) do
      %{users: NbSerializer.serialize!(UserSerializer, users)}
    end

    def show(%{user: user}) do
      %{user: NbSerializer.serialize!(UserSerializer, user)}
    end

    def create(%{user: user}) do
      %{user: NbSerializer.serialize!(UserSerializer, user)}
    end

    def error(%{changeset: changeset}) do
      NbSerializer.Phoenix.render_errors(changeset)
    end
  end

  # Test module that uses the render_many/render_one helpers
  defmodule PostJSON do
    use NbSerializer.Phoenix

    def index(%{posts: posts}) do
      %{posts: render_many(posts, PostSerializer)}
    end

    def show(%{post: post}) do
      %{post: render_one(post, PostSerializer)}
    end

    def paginated(%{posts: posts, meta: meta}) do
      %{
        posts: render_many(posts, PostSerializer),
        meta: meta
      }
    end
  end

  # Test schema for Ecto changeset testing
  defmodule TestUser do
    use Ecto.Schema
    import Ecto.Changeset

    schema "test_users" do
      field(:email, :string)
      field(:name, :string)
    end

    def changeset(user, attrs) do
      user
      |> cast(attrs, [:email, :name])
      |> validate_required([:email, :name])
      |> validate_format(:email, ~r/@/)
      |> validate_length(:name, min: 2)
    end
  end

  describe "Phoenix JSON view pattern" do
    test "index/1 renders collection" do
      users = [
        %{id: 1, name: "John", email: "john@example.com"},
        %{id: 2, name: "Jane", email: "jane@example.com"}
      ]

      result = UserJSON.index(%{users: users})

      assert %{users: serialized_users} = result
      assert length(serialized_users) == 2
      assert Enum.at(serialized_users, 0).name == "John"
      assert Enum.at(serialized_users, 1).name == "Jane"
    end

    test "show/1 renders single resource" do
      user = %{id: 1, name: "John", email: "john@example.com"}

      result = UserJSON.show(%{user: user})

      assert %{user: serialized_user} = result
      assert serialized_user.id == 1
      assert serialized_user.name == "John"
      assert serialized_user.email == "john@example.com"
    end

    test "create/1 renders created resource" do
      user = %{id: 1, name: "John", email: "john@example.com"}

      result = UserJSON.create(%{user: user})

      assert %{user: serialized_user} = result
      assert serialized_user.id == 1
    end
  end

  describe "render_many/2 helper" do
    test "serializes a collection" do
      posts = [
        %{
          id: 1,
          title: "First Post",
          body: "Content",
          author: %{id: 1, name: "John", email: "john@example.com"}
        },
        %{
          id: 2,
          title: "Second Post",
          body: "More content",
          author: %{id: 2, name: "Jane", email: "jane@example.com"}
        }
      ]

      result = PostJSON.index(%{posts: posts})

      assert %{posts: serialized_posts} = result
      assert length(serialized_posts) == 2
      assert Enum.at(serialized_posts, 0).title == "First Post"
      assert Enum.at(serialized_posts, 0).author.name == "John"
    end

    test "handles empty collections" do
      result = PostJSON.index(%{posts: []})

      assert %{posts: []} = result
    end

    test "supports nil values" do
      result = PostJSON.index(%{posts: nil})

      assert %{posts: nil} = result
    end
  end

  describe "render_one/2 helper" do
    test "serializes a single resource" do
      post = %{
        id: 1,
        title: "First Post",
        body: "Content",
        author: %{id: 1, name: "John", email: "john@example.com"}
      }

      result = PostJSON.show(%{post: post})

      assert %{post: serialized_post} = result
      assert serialized_post.id == 1
      assert serialized_post.title == "First Post"
      assert serialized_post.author.name == "John"
    end

    test "handles nil resource" do
      result = PostJSON.show(%{post: nil})

      assert %{post: nil} = result
    end
  end

  describe "render_many/3 and render_one/3 with options" do
    test "passes options to serializer" do
      defmodule ConditionalSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:name)
          field(:email, if: :show_email?)
        end

        def show_email?(_data, opts) do
          opts[:show_private] == true
        end
      end

      defmodule ConditionalJSON do
        use NbSerializer.Phoenix

        def public(%{users: users}) do
          %{users: render_many(users, ConditionalSerializer, show_private: false)}
        end

        def private(%{users: users}) do
          %{users: render_many(users, ConditionalSerializer, show_private: true)}
        end
      end

      users = [%{id: 1, name: "John", email: "john@example.com"}]

      public_result = ConditionalJSON.public(%{users: users})
      private_result = ConditionalJSON.private(%{users: users})

      assert [%{id: 1, name: "John"}] = public_result.users
      refute Map.has_key?(Enum.at(public_result.users, 0), :email)

      assert [%{id: 1, name: "John", email: "john@example.com"}] = private_result.users
    end
  end

  describe "pagination pattern" do
    test "combines serialized data with metadata" do
      posts = [
        %{id: 1, title: "Post 1", body: "Content", author: nil}
      ]

      meta = %{
        page: 1,
        per_page: 10,
        total: 100,
        total_pages: 10
      }

      result = PostJSON.paginated(%{posts: posts, meta: meta})

      assert %{posts: serialized_posts, meta: ^meta} = result
      assert length(serialized_posts) == 1
    end
  end

  describe "error rendering" do
    test "render_errors/1 formats changeset errors" do
      changeset = TestUser.changeset(%TestUser{}, %{})

      result = UserJSON.error(%{changeset: changeset})

      assert %{errors: errors} = result
      assert errors.email == ["can't be blank"]
      assert errors.name == ["can't be blank"]
    end

    test "render_errors/1 handles validation errors" do
      changeset = TestUser.changeset(%TestUser{}, %{email: "invalid", name: "a"})

      result = UserJSON.error(%{changeset: changeset})

      assert %{errors: errors} = result
      assert errors.email == ["has invalid format"]
      assert errors.name == ["should be at least 2 character(s)"]
    end

    test "render_errors/1 handles empty errors" do
      changeset = TestUser.changeset(%TestUser{}, %{email: "test@example.com", name: "John"})

      result = UserJSON.error(%{changeset: changeset})

      assert %{errors: %{}} = result
    end
  end

  describe "render/2 shorthand" do
    defmodule ShorthandJSON do
      use NbSerializer.Phoenix

      def index(%{users: users}) do
        render(users, UserSerializer)
      end

      def show(%{user: user}) do
        render(user, UserSerializer)
      end
    end

    test "render/2 automatically detects single vs many" do
      users = [
        %{id: 1, name: "John", email: "john@example.com"},
        %{id: 2, name: "Jane", email: "jane@example.com"}
      ]

      result = ShorthandJSON.index(%{users: users})
      assert is_list(result)
      assert length(result) == 2

      user = %{id: 1, name: "John", email: "john@example.com"}
      result = ShorthandJSON.show(%{user: user})
      assert is_map(result)
      assert result.id == 1
    end
  end
end
