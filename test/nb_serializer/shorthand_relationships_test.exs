defmodule NbSerializer.ShorthandRelationshipsTest do
  use ExUnit.Case

  describe "has_one shorthand syntax" do
    test "accepts serializer module directly without keyword list" do
      defmodule ShorthandAuthorSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
        end
      end

      defmodule ShorthandPostSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:title, :string)
          # Shorthand syntax: has_one :author, AuthorSerializer
          has_one(:author, ShorthandAuthorSerializer)
        end
      end

      post = %{
        id: 1,
        title: "My Post",
        author: %{id: 10, name: "Jane Doe", email: "jane@example.com"}
      }

      {:ok, result} = NbSerializer.serialize(ShorthandPostSerializer, post)

      assert result == %{
               id: 1,
               title: "My Post",
               author: %{id: 10, name: "Jane Doe"}
             }
    end

    test "shorthand syntax equivalent to keyword syntax" do
      defmodule ConfigSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:enabled, :boolean)
        end
      end

      defmodule WidgetShorthandSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
          has_one(:config, ConfigSerializer)
        end
      end

      defmodule WidgetKeywordSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
          has_one(:config, serializer: ConfigSerializer)
        end
      end

      widget = %{
        id: 1,
        name: "Widget",
        config: %{id: 5, enabled: true, settings: %{}}
      }

      {:ok, shorthand_result} = NbSerializer.serialize(WidgetShorthandSerializer, widget)
      {:ok, keyword_result} = NbSerializer.serialize(WidgetKeywordSerializer, widget)

      assert shorthand_result == keyword_result

      assert shorthand_result == %{
               id: 1,
               name: "Widget",
               config: %{id: 5, enabled: true}
             }
    end
  end

  describe "has_many shorthand syntax" do
    test "accepts serializer module directly without keyword list" do
      defmodule ShorthandCommentSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:body, :string)
        end
      end

      defmodule ShorthandBlogSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:title, :string)
          # Shorthand syntax: has_many :comments, CommentSerializer
          has_many(:comments, ShorthandCommentSerializer)
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

      {:ok, result} = NbSerializer.serialize(ShorthandBlogSerializer, post)

      assert result == %{
               id: 1,
               title: "Post with Comments",
               comments: [
                 %{id: 1, body: "First comment"},
                 %{id: 2, body: "Second comment"}
               ]
             }
    end

    test "shorthand syntax equivalent to keyword syntax for has_many" do
      defmodule ItemSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
        end
      end

      defmodule OrderShorthandSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          has_many(:items, ItemSerializer)
        end
      end

      defmodule OrderKeywordSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          has_many(:items, serializer: ItemSerializer)
        end
      end

      order = %{
        id: 1,
        items: [
          %{id: 10, name: "Item 1"},
          %{id: 11, name: "Item 2"}
        ]
      }

      {:ok, shorthand_result} = NbSerializer.serialize(OrderShorthandSerializer, order)
      {:ok, keyword_result} = NbSerializer.serialize(OrderKeywordSerializer, order)

      assert shorthand_result == keyword_result

      assert shorthand_result == %{
               id: 1,
               items: [
                 %{id: 10, name: "Item 1"},
                 %{id: 11, name: "Item 2"}
               ]
             }
    end
  end

  describe "belongs_to shorthand syntax" do
    test "accepts serializer module directly without keyword list" do
      defmodule ShorthandUserSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:username, :string)
        end
      end

      defmodule ShorthandArticleSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:title, :string)
          # Shorthand syntax: belongs_to :user, UserSerializer
          belongs_to(:user, ShorthandUserSerializer)
        end
      end

      article = %{
        id: 1,
        title: "Article",
        user: %{id: 5, username: "author1"}
      }

      {:ok, result} = NbSerializer.serialize(ShorthandArticleSerializer, article)

      assert result == %{
               id: 1,
               title: "Article",
               user: %{id: 5, username: "author1"}
             }
    end
  end

  describe "mixed shorthand and keyword syntax" do
    test "can use both syntaxes in same serializer" do
      defmodule MixedAuthorSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
        end
      end

      defmodule MixedTagSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
        end
      end

      defmodule MixedCommentSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:text, :string)
        end
      end

      defmodule MixedPostSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:title, :string)
          # Shorthand syntax
          has_one(:author, MixedAuthorSerializer)
          # Keyword syntax with options
          has_many(:tags, serializer: MixedTagSerializer, if: :include_tags?)
          # Shorthand syntax
          has_many(:comments, MixedCommentSerializer)
        end

        def include_tags?(_data, opts) do
          opts[:include_tags] == true
        end
      end

      post = %{
        id: 1,
        title: "Mixed Post",
        author: %{id: 10, name: "Author"},
        tags: [%{id: 1, name: "Tag1"}],
        comments: [%{id: 1, text: "Comment"}]
      }

      {:ok, result} = NbSerializer.serialize(MixedPostSerializer, post)

      assert result == %{
               id: 1,
               title: "Mixed Post",
               author: %{id: 10, name: "Author"},
               comments: [%{id: 1, text: "Comment"}]
             }

      {:ok, result_with_tags} =
        NbSerializer.serialize(MixedPostSerializer, post, include_tags: true)

      assert result_with_tags == %{
               id: 1,
               title: "Mixed Post",
               author: %{id: 10, name: "Author"},
               tags: [%{id: 1, name: "Tag1"}],
               comments: [%{id: 1, text: "Comment"}]
             }
    end
  end

  describe "nested shorthand relationships" do
    test "shorthand works with deeply nested serializers" do
      defmodule NestedShorthandUserSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:username, :string)
        end
      end

      defmodule NestedShorthandCommentSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:text, :string)
          has_one(:user, NestedShorthandUserSerializer)
        end
      end

      defmodule NestedShorthandPostSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:title, :string)
          has_one(:author, NestedShorthandUserSerializer)
          has_many(:comments, NestedShorthandCommentSerializer)
        end
      end

      post = %{
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
            text: "Thanks!",
            user: %{id: 21, username: "commenter2"}
          }
        ]
      }

      {:ok, result} = NbSerializer.serialize(NestedShorthandPostSerializer, post)

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
                   text: "Thanks!",
                   user: %{id: 21, username: "commenter2"}
                 }
               ]
             }
    end
  end
end
