defmodule NbSerializer.ConditionalFieldsTest do
  use ExUnit.Case

  describe "conditional fields" do
    test "includes field when :if condition is true" do
      defmodule ConditionalSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
          field(:secret, :string, if: :show_secret?)
        end

        def show_secret?(_data, opts) do
          opts[:admin] == true
        end
      end

      data = %{id: 1, name: "Item", secret: "hidden value"}

      {:ok, regular_result} = NbSerializer.serialize(ConditionalSerializer, data)
      {:ok, admin_result} = NbSerializer.serialize(ConditionalSerializer, data, admin: true)

      assert regular_result == %{id: 1, name: "Item"}
      assert admin_result == %{id: 1, name: "Item", secret: "hidden value"}
    end

    test "excludes field when :if condition is false" do
      defmodule PrivateFieldSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:public_info, :string)
          field(:private_info, :string, if: :include_private?)
        end

        def include_private?(_data, opts) do
          opts[:include_private] == true
        end
      end

      data = %{id: 1, public_info: "public", private_info: "private"}

      {:ok, result} = NbSerializer.serialize(PrivateFieldSerializer, data)
      assert result == %{id: 1, public_info: "public"}

      {:ok, result_with_private} =
        NbSerializer.serialize(PrivateFieldSerializer, data, include_private: true)

      assert result_with_private == %{id: 1, public_info: "public", private_info: "private"}
    end

    test "conditional computed fields" do
      defmodule ConditionalComputeSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
          field(:discounted_price, :any, compute: :calculate_discount, if: :on_sale?)
        end

        def calculate_discount(product, _opts) do
          product.price * 0.9
        end

        def on_sale?(product, _opts) do
          product.on_sale
        end
      end

      regular = %{id: 1, name: "Regular Item", price: 100, on_sale: false}
      on_sale = %{id: 2, name: "Sale Item", price: 100, on_sale: true}

      {:ok, regular_result} = NbSerializer.serialize(ConditionalComputeSerializer, regular)
      {:ok, sale_result} = NbSerializer.serialize(ConditionalComputeSerializer, on_sale)

      assert regular_result == %{id: 1, name: "Regular Item"}
      assert sale_result == %{id: 2, name: "Sale Item", discounted_price: 90.0}
    end

    test "multiple conditions on the same field" do
      defmodule MultiConditionSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
          field(:sensitive_data, :string, if: [:authorized?, :not_redacted?])
        end

        def authorized?(_data, opts), do: opts[:user_role] == "admin"
        def not_redacted?(data, _opts), do: !data[:redacted]
      end

      data = %{id: 1, name: "Item", sensitive_data: "secret", redacted: false}

      # Both conditions must be true
      {:ok, no_auth} = NbSerializer.serialize(MultiConditionSerializer, data)

      {:ok, admin_redacted} =
        NbSerializer.serialize(
          MultiConditionSerializer,
          %{data | redacted: true},
          user_role: "admin"
        )

      {:ok, admin_not_redacted} =
        NbSerializer.serialize(MultiConditionSerializer, data, user_role: "admin")

      assert no_auth == %{id: 1, name: "Item"}
      assert admin_redacted == %{id: 1, name: "Item"}
      assert admin_not_redacted == %{id: 1, name: "Item", sensitive_data: "secret"}
    end

    test "conditional relationships" do
      defmodule AuthorSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
        end
      end

      defmodule ArticleSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:title, :string)
          has_one(:author, serializer: AuthorSerializer, if: :include_author?)
        end

        def include_author?(_article, opts) do
          opts[:include_author]
        end
      end

      article = %{
        id: 1,
        title: "Article Title",
        author: %{id: 10, name: "Author Name"}
      }

      {:ok, without_author} = NbSerializer.serialize(ArticleSerializer, article)

      {:ok, with_author} =
        NbSerializer.serialize(ArticleSerializer, article, include_author: true)

      assert without_author == %{id: 1, title: "Article Title"}

      assert with_author == %{
               id: 1,
               title: "Article Title",
               author: %{id: 10, name: "Author Name"}
             }
    end

    test "view-based field inclusion" do
      defmodule ViewBasedSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:name, :string)
          field(:email, :string, if: :show_email?)
          field(:created_at, :datetime, if: :show_admin_fields?)
          field(:summary, :string, if: :show_summary?)
        end

        def show_email?(_data, opts) do
          opts[:view] in [:detailed, :admin]
        end

        def show_admin_fields?(_data, opts) do
          opts[:view] == :admin
        end

        def show_summary?(_data, opts) do
          opts[:view] == :summary
        end
      end

      data = %{
        id: 1,
        name: "User",
        email: "user@example.com",
        created_at: ~U[2024-01-01 12:00:00Z],
        summary: "Active user"
      }

      {:ok, basic} = NbSerializer.serialize(ViewBasedSerializer, data)
      {:ok, summary} = NbSerializer.serialize(ViewBasedSerializer, data, view: :summary)
      {:ok, detailed} = NbSerializer.serialize(ViewBasedSerializer, data, view: :detailed)
      {:ok, admin} = NbSerializer.serialize(ViewBasedSerializer, data, view: :admin)

      assert basic == %{id: 1, name: "User"}
      assert summary == %{id: 1, name: "User", summary: "Active user"}
      assert detailed == %{id: 1, name: "User", email: "user@example.com"}

      assert admin == %{
               id: 1,
               name: "User",
               email: "user@example.com",
               created_at: ~U[2024-01-01 12:00:00Z]
             }
    end
  end
end
