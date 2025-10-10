defmodule NbSerializer.MetadataTest do
  use ExUnit.Case

  defmodule SimpleSerializer do
    use NbSerializer.Serializer

    schema do
      field(:id)
      field(:name)
    end
  end

  describe "root key wrapping" do
    test "wraps single object with root key" do
      data = %{id: 1, name: "Test"}

      {:ok, result} = NbSerializer.serialize(SimpleSerializer, data, root: "user")

      assert result == %{
               "user" => %{id: 1, name: "Test"}
             }
    end

    test "wraps collection with root key" do
      data = [
        %{id: 1, name: "User 1"},
        %{id: 2, name: "User 2"}
      ]

      {:ok, result} = NbSerializer.serialize(SimpleSerializer, data, root: "users")

      assert result == %{
               "users" => [
                 %{id: 1, name: "User 1"},
                 %{id: 2, name: "User 2"}
               ]
             }
    end

    test "uses symbol or string for root key" do
      data = %{id: 1, name: "Test"}

      {:ok, result_string} = NbSerializer.serialize(SimpleSerializer, data, root: "user")
      {:ok, result_atom} = NbSerializer.serialize(SimpleSerializer, data, root: :user)

      assert result_string == %{"user" => %{id: 1, name: "Test"}}
      assert result_atom == %{user: %{id: 1, name: "Test"}}
    end

    test "no root key when not specified" do
      data = %{id: 1, name: "Test"}

      {:ok, result} = NbSerializer.serialize(SimpleSerializer, data)

      assert result == %{id: 1, name: "Test"}
    end
  end

  describe "metadata" do
    test "adds metadata to response" do
      data = %{id: 1, name: "Test"}

      result =
        NbSerializer.serialize!(SimpleSerializer, data,
          meta: %{version: "1.0", generated_at: "2024-01-01"}
        )

      assert result == %{
               data: %{id: 1, name: "Test"},
               meta: %{version: "1.0", generated_at: "2024-01-01"}
             }
    end

    test "combines root key and metadata" do
      data = %{id: 1, name: "Test"}

      result =
        NbSerializer.serialize!(SimpleSerializer, data,
          root: "user",
          meta: %{version: "1.0"}
        )

      assert result == %{
               "user" => %{id: 1, name: "Test"},
               "meta" => %{version: "1.0"}
             }
    end

    test "metadata with collection" do
      data = [
        %{id: 1, name: "User 1"},
        %{id: 2, name: "User 2"}
      ]

      result =
        NbSerializer.serialize!(SimpleSerializer, data,
          root: "users",
          meta: %{
            page: 1,
            per_page: 10,
            total: 2
          }
        )

      assert result == %{
               "users" => [
                 %{id: 1, name: "User 1"},
                 %{id: 2, name: "User 2"}
               ],
               "meta" => %{
                 page: 1,
                 per_page: 10,
                 total: 2
               }
             }
    end

    test "metadata function builder" do
      data = [
        %{id: 1, name: "User 1"},
        %{id: 2, name: "User 2"}
      ]

      meta_builder = fn data, _opts ->
        %{
          count: length(data),
          timestamp: ~U[2024-01-01 00:00:00Z]
        }
      end

      result =
        NbSerializer.serialize!(SimpleSerializer, data,
          root: "users",
          meta: meta_builder
        )

      assert result == %{
               "users" => [
                 %{id: 1, name: "User 1"},
                 %{id: 2, name: "User 2"}
               ],
               "meta" => %{
                 count: 2,
                 timestamp: ~U[2024-01-01 00:00:00Z]
               }
             }
    end
  end

  describe "pagination helpers" do
    test "adds pagination metadata" do
      data = [
        %{id: 1, name: "User 1"},
        %{id: 2, name: "User 2"}
      ]

      result =
        NbSerializer.serialize!(SimpleSerializer, data,
          root: "users",
          page: 1,
          per_page: 10,
          total: 100
        )

      assert result == %{
               "users" => [
                 %{id: 1, name: "User 1"},
                 %{id: 2, name: "User 2"}
               ],
               "meta" => %{
                 pagination: %{
                   page: 1,
                   per_page: 10,
                   total: 100,
                   total_pages: 10
                 }
               }
             }
    end
  end

  describe "JSON encoding with metadata" do
    test "encodes to JSON with root and meta" do
      data = %{id: 1, name: "Test"}

      json =
        NbSerializer.to_json!(SimpleSerializer, data,
          root: "user",
          meta: %{version: "1.0"}
        )

      assert json == ~s({"meta":{"version":"1.0"},"user":{"id":1,"name":"Test"}})
    end
  end
end
