defmodule NbSerializer.PlugTest do
  use ExUnit.Case
  import Plug.Conn
  import Plug.Test

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
    end
  end

  describe "NbSerializer.Plug" do
    setup do
      conn = build_conn()
      {:ok, conn: conn}
    end

    test "automatically serializes assigns based on configuration", %{conn: conn} do
      opts =
        NbSerializer.Plug.init(
          serializers: %{
            user: UserSerializer,
            users: UserSerializer,
            post: PostSerializer,
            posts: PostSerializer
          }
        )

      user = %{id: 1, name: "John", email: "john@example.com"}

      conn =
        conn
        |> assign(:user, user)
        |> NbSerializer.Plug.call(opts)

      assert conn.status == 200
      body = Jason.decode!(conn.resp_body)
      assert body["user"]["id"] == 1
      assert body["user"]["name"] == "John"
    end

    test "serializes multiple assigns", %{conn: conn} do
      opts =
        NbSerializer.Plug.init(
          serializers: %{
            user: UserSerializer,
            post: PostSerializer
          }
        )

      user = %{id: 1, name: "John", email: "john@example.com"}
      post = %{id: 1, title: "Hello", body: "World"}

      conn =
        conn
        |> assign(:user, user)
        |> assign(:post, post)
        |> NbSerializer.Plug.call(opts)

      body = Jason.decode!(conn.resp_body)
      assert body["user"]["id"] == 1
      assert body["post"]["title"] == "Hello"
    end

    test "serializes collections", %{conn: conn} do
      opts =
        NbSerializer.Plug.init(
          serializers: %{
            users: UserSerializer
          }
        )

      users = [
        %{id: 1, name: "John", email: "john@example.com"},
        %{id: 2, name: "Jane", email: "jane@example.com"}
      ]

      conn =
        conn
        |> assign(:users, users)
        |> NbSerializer.Plug.call(opts)

      body = Jason.decode!(conn.resp_body)
      assert length(body["users"]) == 2
    end

    test "supports conditional serialization", %{conn: conn} do
      opts =
        NbSerializer.Plug.init(
          serializers: %{
            user: UserSerializer,
            admin_data: UserSerializer
          },
          only: [:user]
        )

      user = %{id: 1, name: "John", email: "john@example.com"}
      admin = %{id: 2, name: "Admin", email: "admin@example.com"}

      conn =
        conn
        |> assign(:user, user)
        |> assign(:admin_data, admin)
        |> NbSerializer.Plug.call(opts)

      body = Jason.decode!(conn.resp_body)
      assert body["user"]
      refute body["admin_data"]
    end

    test "supports except option", %{conn: conn} do
      opts =
        NbSerializer.Plug.init(
          serializers: %{
            user: UserSerializer,
            internal: UserSerializer
          },
          except: [:internal]
        )

      user = %{id: 1, name: "John", email: "john@example.com"}
      internal = %{id: 2, name: "Internal", email: "internal@example.com"}

      conn =
        conn
        |> assign(:user, user)
        |> assign(:internal, internal)
        |> NbSerializer.Plug.call(opts)

      body = Jason.decode!(conn.resp_body)
      assert body["user"]
      refute body["internal"]
    end

    test "adds metadata", %{conn: conn} do
      opts =
        NbSerializer.Plug.init(
          serializers: %{
            users: UserSerializer
          },
          meta: %{version: "1.0", api: "v2"}
        )

      users = [%{id: 1, name: "John", email: "john@example.com"}]

      conn =
        conn
        |> assign(:users, users)
        |> NbSerializer.Plug.call(opts)

      body = Jason.decode!(conn.resp_body)
      assert body["meta"]["version"] == "1.0"
      assert body["meta"]["api"] == "v2"
    end

    test "supports meta function", %{conn: conn} do
      opts =
        NbSerializer.Plug.init(
          serializers: %{
            users: UserSerializer
          },
          meta: fn conn ->
            %{
              request_id: conn.assigns[:request_id],
              timestamp: "2024-01-01T00:00:00Z"
            }
          end
        )

      users = [%{id: 1, name: "John", email: "john@example.com"}]

      conn =
        conn
        |> assign(:request_id, "req-123")
        |> assign(:users, users)
        |> NbSerializer.Plug.call(opts)

      body = Jason.decode!(conn.resp_body)
      assert body["meta"]["request_id"] == "req-123"
      assert body["meta"]["timestamp"] == "2024-01-01T00:00:00Z"
    end

    test "supports response caching", %{conn: conn} do
      opts =
        NbSerializer.Plug.init(
          serializers: %{
            user: UserSerializer
          },
          cache: true,
          cache_ttl: 300
        )

      user = %{id: 1, name: "John", email: "john@example.com"}

      conn =
        conn
        |> assign(:user, user)
        |> NbSerializer.Plug.call(opts)

      assert get_resp_header(conn, "cache-control") == ["max-age=300, public"]
      assert get_resp_header(conn, "etag") != []
    end

    test "skips when no matching serializers", %{conn: conn} do
      opts =
        NbSerializer.Plug.init(
          serializers: %{
            user: UserSerializer
          }
        )

      conn =
        conn
        |> assign(:other_data, %{foo: "bar"})
        |> NbSerializer.Plug.call(opts)

      # Should pass through without serialization
      refute conn.resp_body
    end

    test "works with halted connections", %{conn: conn} do
      opts =
        NbSerializer.Plug.init(
          serializers: %{
            user: UserSerializer
          }
        )

      conn =
        conn
        |> halt()
        |> assign(:user, %{id: 1, name: "John", email: "john@example.com"})
        |> NbSerializer.Plug.call(opts)

      # Should not process halted connections
      refute conn.resp_body
    end
  end

  defp build_conn do
    Plug.Test.conn(:get, "/")
  end
end
