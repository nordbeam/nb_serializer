defmodule NbSerializer.RelationshipsTest do
  use ExUnit.Case

  describe "has_one relationship" do
    test "serializes a single association" do
      defmodule AuthorSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:name)
        end
      end

      defmodule PostWithAuthorSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:title)
          has_one(:author, serializer: AuthorSerializer)
        end
      end

      post = %{
        id: 1,
        title: "My Post",
        author: %{id: 10, name: "Jane Doe", email: "jane@example.com"}
      }

      {:ok, result} = NbSerializer.serialize(PostWithAuthorSerializer, post)

      assert result == %{
               id: 1,
               title: "My Post",
               author: %{id: 10, name: "Jane Doe"}
             }
    end

    test "handles nil association" do
      defmodule CategorySerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:name)
        end
      end

      defmodule ProductSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:name)
          has_one(:category, serializer: CategorySerializer)
        end
      end

      product = %{id: 1, name: "Widget", category: nil}
      {:ok, result} = NbSerializer.serialize(ProductSerializer, product)

      assert result == %{id: 1, name: "Widget", category: nil}
    end

    test "supports custom key for association" do
      defmodule UserInfoSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:name)
        end
      end

      defmodule ArticleSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:title)
          has_one(:author, serializer: UserInfoSerializer, key: :written_by)
        end
      end

      article = %{
        id: 1,
        title: "Article",
        author: %{id: 5, name: "Author Name"}
      }

      {:ok, result} = NbSerializer.serialize(ArticleSerializer, article)

      assert result == %{
               id: 1,
               title: "Article",
               written_by: %{id: 5, name: "Author Name"}
             }
    end
  end

  describe "has_many relationship" do
    test "serializes a collection association" do
      defmodule CommentSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:body)
        end
      end

      defmodule PostWithCommentsSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:title)
          has_many(:comments, serializer: CommentSerializer)
        end
      end

      post = %{
        id: 1,
        title: "Post with Comments",
        comments: [
          %{id: 1, body: "First comment", user_id: 1},
          %{id: 2, body: "Second comment", user_id: 2}
        ]
      }

      {:ok, result} = NbSerializer.serialize(PostWithCommentsSerializer, post)

      assert result == %{
               id: 1,
               title: "Post with Comments",
               comments: [
                 %{id: 1, body: "First comment"},
                 %{id: 2, body: "Second comment"}
               ]
             }
    end

    test "handles empty collection" do
      defmodule TagSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:name)
        end
      end

      defmodule BlogPostSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:title)
          has_many(:tags, serializer: TagSerializer)
        end
      end

      post = %{id: 1, title: "Post without tags", tags: []}
      {:ok, result} = NbSerializer.serialize(BlogPostSerializer, post)

      assert result == %{id: 1, title: "Post without tags", tags: []}
    end

    test "handles nil collection as empty list" do
      defmodule ItemSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:name)
        end
      end

      defmodule OrderSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          has_many(:items, serializer: ItemSerializer)
        end
      end

      order = %{id: 1, items: nil}
      {:ok, result} = NbSerializer.serialize(OrderSerializer, order)

      assert result == %{id: 1, items: []}
    end
  end

  describe "nested relationships" do
    test "serializes deeply nested associations" do
      defmodule NestedUserSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:username)
        end
      end

      defmodule NestedCommentSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:text)
          has_one(:user, serializer: NestedUserSerializer)
        end
      end

      defmodule NestedPostSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:title)
          has_one(:author, serializer: NestedUserSerializer)
          has_many(:comments, serializer: NestedCommentSerializer)
        end
      end

      post = %{
        id: 1,
        title: "Nested Post",
        author: %{id: 10, username: "author1", email: "author@example.com"},
        comments: [
          %{
            id: 1,
            text: "Great post!",
            user: %{id: 20, username: "commenter1", email: "c1@example.com"}
          },
          %{
            id: 2,
            text: "Thanks for sharing",
            user: %{id: 21, username: "commenter2", email: "c2@example.com"}
          }
        ]
      }

      {:ok, result} = NbSerializer.serialize(NestedPostSerializer, post)

      assert result == %{
               id: 1,
               title: "Nested Post",
               author: %{id: 10, username: "author1"},
               comments: [
                 %{
                   id: 1,
                   text: "Great post!",
                   user: %{id: 20, username: "commenter1"}
                 },
                 %{
                   id: 2,
                   text: "Thanks for sharing",
                   user: %{id: 21, username: "commenter2"}
                 }
               ]
             }
    end
  end

  describe "computed associations" do
    test "supports computed association with function reference" do
      defmodule ComputedAssocSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id)
          field(:name)
          has_one(:metadata, compute: :build_metadata)
        end

        def build_metadata(item, _opts) do
          %{
            created_by: item.user_id,
            status: item.status,
            tags: String.split(item.tag_string, ",")
          }
        end
      end

      item = %{
        id: 1,
        name: "Item",
        user_id: 5,
        status: "active",
        tag_string: "new,featured,sale"
      }

      {:ok, result} = NbSerializer.serialize(ComputedAssocSerializer, item)

      assert result == %{
               id: 1,
               name: "Item",
               metadata: %{
                 created_by: 5,
                 status: "active",
                 tags: ["new", "featured", "sale"]
               }
             }
    end
  end
end
