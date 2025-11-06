defmodule NbSerializer.PolymorphicTest do
  use ExUnit.Case

  # Define structs at module level
  defmodule User do
    defstruct [:id, :name, :email]
  end

  defmodule Company do
    defstruct [:id, :name, :industry, :employee_count]
  end

  defmodule Admin do
    defstruct [:id, :name, :email, :role, :permissions]
  end

  defmodule Post do
    defstruct [:id, :title, :body]
  end

  defmodule Photo do
    defstruct [:id, :url, :caption]
  end

  defmodule Video do
    defstruct [:id, :url, :duration]
  end

  defmodule UnknownStruct do
    defstruct [:id, :data]
  end

  defmodule UserSerializer do
    use NbSerializer.Serializer

    schema do
      field(:id, :number)
      field(:type, :string, default: "user")
      field(:name, :string)
      field(:email, :string)
    end
  end

  defmodule CompanySerializer do
    use NbSerializer.Serializer

    schema do
      field(:id, :number)
      field(:type, :string, default: "company")
      field(:name, :string)
      field(:industry, :string)
      field(:employee_count, :integer)
    end
  end

  defmodule AdminSerializer do
    use NbSerializer.Serializer

    schema do
      field(:id, :number)
      field(:type, :string, default: "admin")
      field(:name, :string)
      field(:email, :string)
      field(:role, :string)
      field(:permissions, list: :string)
    end
  end

  describe "polymorphic relationships" do
    defmodule ActivitySerializer do
      use NbSerializer.Serializer

      schema do
        field(:id, :number)
        field(:action, :string)
        field(:timestamp, :datetime)

        has_one(:actor,
          polymorphic: [
            {NbSerializer.PolymorphicTest.User, NbSerializer.PolymorphicTest.UserSerializer},
            {NbSerializer.PolymorphicTest.Company,
             NbSerializer.PolymorphicTest.CompanySerializer},
            {NbSerializer.PolymorphicTest.Admin, NbSerializer.PolymorphicTest.AdminSerializer}
          ]
        )
      end
    end

    defmodule CommentSerializer do
      use NbSerializer.Serializer

      schema do
        field(:id, :number)
        field(:body, :string)

        has_one(:author,
          polymorphic: [
            {NbSerializer.PolymorphicTest.User, NbSerializer.PolymorphicTest.UserSerializer},
            {NbSerializer.PolymorphicTest.Admin, NbSerializer.PolymorphicTest.AdminSerializer}
          ]
        )
      end
    end

    test "serializes polymorphic has_one based on struct type" do
      activity_with_user = %{
        id: 1,
        action: "created_post",
        timestamp: "2024-01-01T12:00:00Z",
        actor: %User{id: 1, name: "John Doe", email: "john@example.com"}
      }

      {:ok, result} = NbSerializer.serialize(ActivitySerializer, activity_with_user)

      assert result[:id] == 1
      assert result[:action] == "created_post"
      assert result[:actor][:type] == "user"
      assert result[:actor][:name] == "John Doe"
      assert result[:actor][:email] == "john@example.com"

      activity_with_company = %{
        id: 2,
        action: "sponsored_event",
        timestamp: "2024-01-01T13:00:00Z",
        actor: %Company{id: 1, name: "Acme Corp", industry: "Tech", employee_count: 100}
      }

      {:ok, result2} = NbSerializer.serialize(ActivitySerializer, activity_with_company)

      assert result2[:actor][:type] == "company"
      assert result2[:actor][:industry] == "Tech"
      assert result2[:actor][:employee_count] == 100
    end

    test "handles nil in polymorphic relationships" do
      activity = %{
        id: 1,
        action: "system_event",
        timestamp: "2024-01-01T12:00:00Z",
        actor: nil
      }

      {:ok, result} = NbSerializer.serialize(ActivitySerializer, activity)

      assert result[:actor] == nil
    end

    test "serializes polymorphic with map-based type detection" do
      defmodule PostSerializer do
        use NbSerializer.Serializer

        schema do
          field(:id, :number)
          field(:title, :string)

          has_one(:owner, polymorphic: :detect_owner_type)
        end

        def detect_owner_type(data, _opts) do
          case data[:type] do
            "user" -> NbSerializer.PolymorphicTest.UserSerializer
            "company" -> NbSerializer.PolymorphicTest.CompanySerializer
            _ -> nil
          end
        end
      end

      post = %{
        id: 1,
        title: "Hello World",
        owner: %{
          id: 1,
          type: "user",
          name: "John Doe",
          email: "john@example.com"
        }
      }

      {:ok, result} = NbSerializer.serialize(PostSerializer, post)

      assert result[:owner][:type] == "user"
      assert result[:owner][:name] == "John Doe"
    end

    test "handles unknown struct types gracefully" do
      activity = %{
        id: 1,
        action: "unknown",
        timestamp: "2024-01-01T12:00:00Z",
        actor: %UnknownStruct{id: 1, data: "test"}
      }

      # Should fall back to no serialization or use a default
      {:ok, result} = NbSerializer.serialize(ActivitySerializer, activity)

      # Should pass through the raw data when no matching serializer
      assert result[:actor] == %UnknownStruct{id: 1, data: "test"}
    end
  end

  describe "polymorphic has_many" do
    defmodule FeedSerializer do
      use NbSerializer.Serializer

      schema do
        field(:id, :number)
        field(:name, :string)

        has_many(:items,
          polymorphic: [
            {NbSerializer.PolymorphicTest.Post, NbSerializer.PolymorphicTest.PostItemSerializer},
            {NbSerializer.PolymorphicTest.Photo, NbSerializer.PolymorphicTest.PhotoSerializer},
            {NbSerializer.PolymorphicTest.Video, NbSerializer.PolymorphicTest.VideoSerializer}
          ]
        )
      end
    end

    defmodule PostItemSerializer do
      use NbSerializer.Serializer

      schema do
        field(:id, :number)
        field(:type, :string, default: "post")
        field(:title, :string)
        field(:body, :string)
      end
    end

    defmodule PhotoSerializer do
      use NbSerializer.Serializer

      schema do
        field(:id, :number)
        field(:type, :string, default: "photo")
        field(:url, :string)
        field(:caption, :string)
      end
    end

    defmodule VideoSerializer do
      use NbSerializer.Serializer

      schema do
        field(:id, :number)
        field(:type, :string, default: "video")
        field(:url, :string)
        field(:duration, :integer)
      end
    end

    test "serializes polymorphic has_many with mixed types" do
      feed = %{
        id: 1,
        name: "Mixed Content Feed",
        items: [
          %Post{id: 1, title: "First Post", body: "Content"},
          %Photo{id: 2, url: "http://example.com/photo.jpg", caption: "Nice photo"},
          %Video{id: 3, url: "http://example.com/video.mp4", duration: 120},
          %Post{id: 4, title: "Second Post", body: "More content"}
        ]
      }

      {:ok, result} = NbSerializer.serialize(FeedSerializer, feed)

      assert length(result[:items]) == 4
      assert Enum.at(result[:items], 0)[:type] == "post"
      assert Enum.at(result[:items], 0)[:title] == "First Post"
      assert Enum.at(result[:items], 1)[:type] == "photo"
      assert Enum.at(result[:items], 1)[:caption] == "Nice photo"
      assert Enum.at(result[:items], 2)[:type] == "video"
      assert Enum.at(result[:items], 2)[:duration] == 120
      assert Enum.at(result[:items], 3)[:type] == "post"
    end
  end

  describe "custom type detection" do
    defmodule SmartSerializer do
      use NbSerializer.Serializer

      schema do
        field(:id, :number)
        has_one(:content, polymorphic: :detect_content_type)
      end

      def detect_content_type(data, _opts) do
        cond do
          Map.has_key?(data, :email) -> NbSerializer.PolymorphicTest.UserSerializer
          Map.has_key?(data, :industry) -> NbSerializer.PolymorphicTest.CompanySerializer
          true -> nil
        end
      end
    end

    test "uses custom detection function" do
      item = %{
        id: 1,
        content: %{
          id: 1,
          name: "John",
          email: "john@example.com"
        }
      }

      {:ok, result} = NbSerializer.serialize(SmartSerializer, item)

      assert result[:content][:type] == "user"
      assert result[:content][:email] == "john@example.com"
    end
  end
end
