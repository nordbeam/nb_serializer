defmodule NbSerializer.CircularReferenceTest do
  use ExUnit.Case, async: true

  defmodule Author do
    defstruct [:id, :name, :books]
  end

  defmodule Book do
    defstruct [:id, :title, :author, :publisher, :related_books]
  end

  defmodule Publisher do
    defstruct [:id, :name, :books]
  end

  describe "within option for circular reference control" do
    test "prevents circular references with max_depth option" do
      defmodule BasicBookSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:title)
        has_one(:author, serializer: NbSerializer.CircularReferenceTest.BasicAuthorSerializer)
      end

      defmodule BasicAuthorSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:name)
        has_many(:books, serializer: NbSerializer.CircularReferenceTest.BasicBookSerializer)
      end

      author = %Author{id: 1, name: "John Doe", books: []}
      book = %Book{id: 1, title: "Elixir Guide", author: author}
      author = %{author | books: [book]}
      book = %{book | author: author}

      # Use max_depth: 1 to serialize only one level deep
      result = BasicBookSerializer.serialize(book, max_depth: 1)

      assert result == %{
               id: 1,
               title: "Elixir Guide",
               author: %{
                 id: 1,
                 name: "John Doe",
                 # Books are empty because we hit max_depth
                 books: []
               }
             }
    end

    test "allows controlled circular references with within option" do
      defmodule BookSerializerWithin do
        use NbSerializer.Serializer

        field(:id)
        field(:title)
        has_one(:author, serializer: NbSerializer.CircularReferenceTest.AuthorSerializerWithin)
      end

      defmodule AuthorSerializerWithin do
        use NbSerializer.Serializer

        field(:id)
        field(:name)
        has_many(:books, serializer: NbSerializer.CircularReferenceTest.BookSerializerWithin)
      end

      author = %Author{id: 1, name: "John Doe", books: []}
      book1 = %Book{id: 1, title: "Book One", author: author}
      book2 = %Book{id: 2, title: "Book Two", author: author}
      author = %{author | books: [book1, book2]}
      book1 = %{book1 | author: author}
      book2 = %{book2 | author: author}

      # within: [author: [books: []]] means:
      # - serialize the author
      # - serialize the author's books
      # - but don't serialize those books' associations (stop there)
      result = BookSerializerWithin.serialize(book1, within: [author: [books: []]])

      assert result == %{
               id: 1,
               title: "Book One",
               author: %{
                 id: 1,
                 name: "John Doe",
                 books: [
                   # Author field is nil to prevent circular reference
                   %{id: 1, title: "Book One", author: nil},
                   # Author field is nil to prevent circular reference
                   %{id: 2, title: "Book Two", author: nil}
                 ]
               }
             }
    end

    test "supports complex nested within paths" do
      defmodule ComplexBookSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:title)
        has_one(:author, serializer: NbSerializer.CircularReferenceTest.ComplexAuthorSerializer)
        has_one(:publisher, serializer: NbSerializer.CircularReferenceTest.PublisherSerializer)

        has_many(:related_books,
          serializer: NbSerializer.CircularReferenceTest.ComplexBookSerializer
        )
      end

      defmodule ComplexAuthorSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:name)
        has_many(:books, serializer: NbSerializer.CircularReferenceTest.ComplexBookSerializer)
      end

      defmodule PublisherSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:name)
        has_many(:books, serializer: NbSerializer.CircularReferenceTest.ComplexBookSerializer)
      end

      publisher = %Publisher{id: 1, name: "Tech Books Inc", books: []}
      author = %Author{id: 1, name: "Jane Smith", books: []}

      book1 = %Book{
        id: 1,
        title: "Advanced Elixir",
        author: author,
        publisher: publisher,
        related_books: []
      }

      book2 = %Book{
        id: 2,
        title: "OTP in Action",
        author: author,
        publisher: publisher,
        related_books: [book1]
      }

      author = %{author | books: [book1, book2]}
      publisher = %{publisher | books: [book1, book2]}
      book1 = %{book1 | author: author, publisher: publisher, related_books: [book2]}
      book2 = %{book2 | author: author, publisher: publisher}

      # Complex within option:
      # - serialize author and their books
      # - serialize publisher but not their books
      # - serialize related_books and their authors
      result =
        ComplexBookSerializer.serialize(
          book1,
          within: [
            author: [books: []],
            publisher: [],
            related_books: [author: []]
          ]
        )

      assert result == %{
               id: 1,
               title: "Advanced Elixir",
               author: %{
                 id: 1,
                 name: "Jane Smith",
                 books: [
                   %{
                     id: 1,
                     title: "Advanced Elixir",
                     author: nil,
                     publisher: nil,
                     related_books: []
                   },
                   %{
                     id: 2,
                     title: "OTP in Action",
                     author: nil,
                     publisher: nil,
                     related_books: []
                   }
                 ]
               },
               publisher: %{
                 id: 1,
                 name: "Tech Books Inc",
                 # Empty because not in within
                 books: []
               },
               related_books: [
                 %{
                   id: 2,
                   title: "OTP in Action",
                   author: %{
                     id: 1,
                     name: "Jane Smith",
                     # Empty because at depth limit in within
                     books: []
                   },
                   # nil because not in within
                   publisher: nil,
                   # Empty because not in within
                   related_books: []
                 }
               ]
             }
    end

    test "within option with list syntax for multiple paths" do
      defmodule ListBookSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:title)
        has_one(:author, serializer: NbSerializer.CircularReferenceTest.ListAuthorSerializer)

        has_many(:related_books,
          serializer: NbSerializer.CircularReferenceTest.ListBookSerializer
        )
      end

      defmodule ListAuthorSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:name)
        has_many(:books, serializer: NbSerializer.CircularReferenceTest.ListBookSerializer)
      end

      author = %Author{id: 1, name: "Author One", books: []}
      book1 = %Book{id: 1, title: "Book One", author: author, related_books: []}
      book2 = %Book{id: 2, title: "Book Two", author: author, related_books: [book1]}

      author = %{author | books: [book1, book2]}
      book1 = %{book1 | author: author, related_books: [book2]}
      book2 = %{book2 | author: author}

      # Using mixed syntax - plain atoms and keyword pairs
      # :author means serialize author with no nested associations
      # related_books: [:author] means serialize related_books and their authors
      result =
        ListBookSerializer.serialize(
          book1,
          within: [:author, related_books: [:author]]
        )

      assert result == %{
               id: 1,
               title: "Book One",
               author: %{
                 id: 1,
                 name: "Author One",
                 # Empty because not in within path
                 books: []
               },
               related_books: [
                 %{
                   id: 2,
                   title: "Book Two",
                   author: %{
                     id: 1,
                     name: "Author One",
                     # Empty because at depth limit
                     books: []
                   },
                   # Empty because not in within path
                   related_books: []
                 }
               ]
             }
    end

    test "stops at configured depth even with within option" do
      defmodule DepthBookSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:title)
        has_one(:author, serializer: NbSerializer.CircularReferenceTest.DepthAuthorSerializer)
      end

      defmodule DepthAuthorSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:name)
        has_many(:books, serializer: NbSerializer.CircularReferenceTest.DepthBookSerializer)
      end

      author = %Author{id: 1, name: "Deep Author", books: []}
      book = %Book{id: 1, title: "Deep Book", author: author}
      author = %{author | books: [book]}
      book = %{book | author: author}

      # Even with within allowing deep nesting, max_depth should still apply
      result =
        DepthBookSerializer.serialize(
          book,
          within: [author: [books: [author: [books: []]]]],
          max_depth: 3
        )

      assert result == %{
               id: 1,
               title: "Deep Book",
               author: %{
                 id: 1,
                 name: "Deep Author",
                 books: [
                   %{
                     id: 1,
                     title: "Deep Book",
                     # At max_depth=3, we can still show author
                     author: %{
                       id: 1,
                       name: "Deep Author",
                       # But their books are empty due to max_depth
                       books: []
                     }
                   }
                 ]
               }
             }
    end

    test "within option respects conditional fields" do
      defmodule ConditionalBookSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:title)

        has_one(:author,
          serializer: NbSerializer.CircularReferenceTest.ConditionalAuthorSerializer,
          if: :has_author?
        )

        def has_author?(book, _opts) do
          book.author != nil
        end
      end

      defmodule ConditionalAuthorSerializer do
        use NbSerializer.Serializer

        field(:id)
        field(:name)

        has_many(:books,
          serializer: NbSerializer.CircularReferenceTest.ConditionalBookSerializer,
          if: :has_books?
        )

        def has_books?(author, _opts) do
          length(author.books) > 0
        end
      end

      author = %Author{id: 1, name: "Conditional Author", books: []}
      book_with_author = %Book{id: 1, title: "Book with Author", author: author}
      book_without_author = %Book{id: 2, title: "Book without Author", author: nil}

      author = %{author | books: [book_with_author]}
      book_with_author = %{book_with_author | author: author}

      result =
        ConditionalBookSerializer.serialize(
          book_with_author,
          within: [author: [books: []]]
        )

      assert result == %{
               id: 1,
               title: "Book with Author",
               author: %{
                 id: 1,
                 name: "Conditional Author",
                 books: [
                   # nil because of within limits
                   %{id: 1, title: "Book with Author", author: nil}
                 ]
               }
             }

      result_no_author =
        ConditionalBookSerializer.serialize(
          book_without_author,
          within: [author: [books: []]]
        )

      assert result_no_author == %{
               id: 2,
               title: "Book without Author"
               # No author field due to condition
             }
    end
  end
end
