defmodule NbSerializer.UsageRulesTest do
  use ExUnit.Case, async: true

  defmodule Author do
    use Ecto.Schema

    schema "usage_rules_authors" do
      field(:name, :string)
    end
  end

  defmodule Post do
    use Ecto.Schema

    schema "usage_rules_posts" do
      field(:title, :string)
      belongs_to(:author, NbSerializer.UsageRulesTest.Author)
    end
  end

  defmodule AuthorSerializer do
    use NbSerializer.Serializer
    use NbSerializer.Ecto

    schema do
      field(:id, :integer)
      field(:name, :string)
      field(:display_name, :string, compute: :display_name)
    end

    def display_name(%{name: name}, _opts), do: name
  end

  defmodule PostSerializer do
    use NbSerializer.Serializer
    use NbSerializer.Ecto

    schema do
      field(:id, :integer)
      field(:title, :string)
      field(:author_id, :integer)

      has_one(:primary_reviewer,
        serializer: NbSerializer.UsageRulesTest.AuthorSerializer,
        compute: :primary_reviewer,
        nullable: true,
        on_missing: :null
      )
    end

    def primary_reviewer(%{author: author}, _opts), do: author
  end

  test "documents the result envelope, camelized keys, computed field, and nullable association" do
    author = %Author{id: 10, name: "Ada"}

    post = %Post{
      id: 1,
      title: "Typed JSON",
      author_id: 10,
      author: author
    }

    assert {:ok, result} = NbSerializer.serialize(PostSerializer, post, camelize: true)

    assert result == %{
             id: 1,
             title: "Typed JSON",
             authorId: 10,
             primaryReviewer: %{id: 10, name: "Ada", displayName: "Ada"}
           }
  end

  test "maps nil and unloaded computed associations to a nullable value" do
    nil_post = %Post{id: 2, title: "No reviewer", author: nil}

    assert {:ok, %{primaryReviewer: nil}} =
             NbSerializer.serialize(PostSerializer, nil_post, camelize: true)

    unloaded_post = %Post{id: 3, title: "Not preloaded"}

    assert {:ok, %{primaryReviewer: nil}} =
             NbSerializer.serialize(PostSerializer, unloaded_post, camelize: true)
  end

  test "records the nullable association in the serializer contract" do
    [relationship] = NbSerializer.Contract.build(PostSerializer).relationships

    assert relationship.name == :primary_reviewer
    assert relationship.serializer == AuthorSerializer
    assert relationship.nullable
  end
end
