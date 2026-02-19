defmodule NbSerializer.EctoTest do
  use ExUnit.Case

  # Mock Ecto schemas for testing
  defmodule User do
    use Ecto.Schema

    schema "users" do
      field(:name, :string)
      field(:email, :string)
      field(:age, :integer)
      field(:is_active, :boolean, default: true)

      has_many(:posts, NbSerializer.EctoTest.Post)
      has_one(:profile, NbSerializer.EctoTest.Profile)

      timestamps()
    end
  end

  defmodule Profile do
    use Ecto.Schema

    schema "profiles" do
      field(:bio, :string)
      field(:website, :string)
      field(:avatar_url, :string)

      belongs_to(:user, NbSerializer.EctoTest.User)

      timestamps()
    end
  end

  defmodule Post do
    use Ecto.Schema

    schema "posts" do
      field(:title, :string)
      field(:body, :string)
      field(:published, :boolean, default: false)
      field(:view_count, :integer, default: 0)

      belongs_to(:user, NbSerializer.EctoTest.User)
      has_many(:comments, NbSerializer.EctoTest.Comment)

      timestamps()
    end
  end

  defmodule Comment do
    use Ecto.Schema

    schema "comments" do
      field(:body, :string)
      field(:approved, :boolean, default: false)

      belongs_to(:post, NbSerializer.EctoTest.Post)
      belongs_to(:user, NbSerializer.EctoTest.User)

      timestamps()
    end
  end

  describe "Ecto schema serialization" do
    test "serializes Ecto schema fields" do
      defmodule UserEctoSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
          field(:email, :string)
          field(:inserted_at, :datetime)
        end
      end

      now = DateTime.utc_now()

      user = %User{
        id: 1,
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        inserted_at: now,
        updated_at: now
      }

      {:ok, result} = NbSerializer.serialize(UserEctoSerializer, user)

      assert result == %{
               id: 1,
               name: "John Doe",
               email: "john@example.com",
               inserted_at: DateTime.to_iso8601(now)
             }
    end

    test "handles unloaded Ecto associations" do
      defmodule PostWithAssocSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:title, :string)
          has_one(:user, serializer: UserEctoSerializer)
        end
      end

      defmodule UserEctoSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
        end
      end

      # Simulate unloaded association with Ecto.Association.NotLoaded
      post = %Post{
        id: 1,
        title: "My Post",
        user: %Ecto.Association.NotLoaded{
          __field__: :user,
          __owner__: Post,
          __cardinality__: :one
        }
      }

      {:ok, result} = NbSerializer.serialize(PostWithAssocSerializer, post)

      # Unloaded associations should be excluded or null
      assert result == %{
               id: 1,
               title: "My Post",
               user: nil
             }
    end

    test "serializes loaded Ecto associations" do
      defmodule ProfileSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:bio, :string)
          field(:website, :string)
        end
      end

      defmodule UserWithProfileSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
          has_one(:profile, serializer: ProfileSerializer)
        end
      end

      user = %User{
        id: 1,
        name: "Jane Smith",
        profile: %Profile{
          id: 10,
          bio: "Software Developer",
          website: "https://example.com",
          avatar_url: "https://example.com/avatar.jpg"
        }
      }

      {:ok, result} = NbSerializer.serialize(UserWithProfileSerializer, user)

      assert result == %{
               id: 1,
               name: "Jane Smith",
               profile: %{
                 id: 10,
                 bio: "Software Developer",
                 website: "https://example.com"
               }
             }
    end

    test "serializes Ecto has_many associations" do
      defmodule CommentSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:body, :string)
          field(:approved, :boolean)
        end
      end

      defmodule PostWithCommentsSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:title, :string)
          field(:body, :string)
          has_many(:comments, serializer: CommentSerializer)
        end
      end

      post = %Post{
        id: 1,
        title: "Blog Post",
        body: "Post content",
        comments: [
          %Comment{id: 1, body: "First comment", approved: true},
          %Comment{id: 2, body: "Second comment", approved: false}
        ]
      }

      {:ok, result} = NbSerializer.serialize(PostWithCommentsSerializer, post)

      assert result == %{
               id: 1,
               title: "Blog Post",
               body: "Post content",
               comments: [
                 %{id: 1, body: "First comment", approved: true},
                 %{id: 2, body: "Second comment", approved: false}
               ]
             }
    end

    test "handles virtual fields" do
      defmodule PostWithVirtualSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:title, :string)
          field(:full_title, :string, compute: :build_full_title)
        end

        def build_full_title(post, _opts) do
          "#{post.title} (#{post.view_count} views)"
        end
      end

      post = %Post{
        id: 1,
        title: "Popular Post",
        view_count: 1000
      }

      {:ok, result} = NbSerializer.serialize(PostWithVirtualSerializer, post)

      assert result == %{
               id: 1,
               title: "Popular Post",
               full_title: "Popular Post (1000 views)"
             }
    end

    test "works with Ecto changesets" do
      defmodule ChangesetSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
          field(:email, :string)
        end
      end

      user = %User{id: 1, name: "Test User", email: "test@example.com"}
      changeset = Ecto.Changeset.change(user, %{name: "Updated Name"})

      # Should serialize the data from the changeset
      {:ok, result} = NbSerializer.serialize(ChangesetSerializer, changeset.data)

      assert result == %{
               id: 1,
               name: "Test User",
               email: "test@example.com"
             }
    end
  end

  describe "Ecto-specific features" do
    test "automatically excludes Ecto metadata fields" do
      defmodule CleanSerializer do
        use NbSerializer.Serializer
        # This would add Ecto-specific behavior
        use NbSerializer.Ecto

        schema do
          field(:id, :number)
          field(:name, :string)
          field(:email, :string)
        end
      end

      user = %User{
        id: 1,
        name: "John",
        email: "john@example.com",
        __meta__: %Ecto.Schema.Metadata{state: :loaded, source: "users"}
      }

      {:ok, result} = NbSerializer.serialize(CleanSerializer, user)

      # Should not include __meta__
      assert result == %{
               id: 1,
               name: "John",
               email: "john@example.com"
             }
    end

    test "handles Ecto preloads with :if option" do
      defmodule ConditionalCommentSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:body, :string)
        end
      end

      defmodule ConditionalPreloadSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:title, :string)

          has_many(:comments,
            serializer: ConditionalCommentSerializer,
            if: :loaded?
          )
        end

        def loaded?(post, _opts) do
          case post.comments do
            %Ecto.Association.NotLoaded{} -> false
            _ -> true
          end
        end
      end

      # Post with unloaded comments
      post_unloaded = %Post{
        id: 1,
        title: "Post",
        comments: %Ecto.Association.NotLoaded{
          __field__: :comments,
          __owner__: Post,
          __cardinality__: :many
        }
      }

      # Post with loaded comments
      post_loaded = %Post{
        id: 2,
        title: "Post with comments",
        comments: [
          %Comment{id: 1, body: "Comment 1"}
        ]
      }

      {:ok, result_unloaded} = NbSerializer.serialize(ConditionalPreloadSerializer, post_unloaded)
      {:ok, result_loaded} = NbSerializer.serialize(ConditionalPreloadSerializer, post_loaded)

      # Should exclude unloaded association
      assert Map.has_key?(result_unloaded, :comments) == false

      # Should include loaded association
      assert result_loaded == %{
               id: 2,
               title: "Post with comments",
               comments: [%{id: 1, body: "Comment 1"}]
             }
    end
  end
end
