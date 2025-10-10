defmodule NbSerializer.ErrorSerializerTest do
  use ExUnit.Case

  describe "ErrorSerializer" do
    test "serializes simple error" do
      error = %{
        error: "Not Found",
        message: "The requested resource was not found"
      }

      {:ok, result} = NbSerializer.serialize(NbSerializer.ErrorSerializer, error)

      assert result[:error] == "Not Found"
      assert result[:message] == "The requested resource was not found"
    end

    test "serializes error with details" do
      error = %{
        error: "Validation Failed",
        message: "The request contains invalid data",
        details: %{
          email: ["is invalid", "has already been taken"],
          name: ["can't be blank"]
        }
      }

      {:ok, result} = NbSerializer.serialize(NbSerializer.ErrorSerializer, error)

      assert result[:error] == "Validation Failed"
      assert result[:message] == "The request contains invalid data"
      assert result[:details][:email] == ["is invalid", "has already been taken"]
      assert result[:details][:name] == ["can't be blank"]
    end

    test "serializes error with code" do
      error = %{
        error: "Unauthorized",
        message: "Authentication required",
        code: "AUTH_REQUIRED",
        status: 401
      }

      {:ok, result} = NbSerializer.serialize(NbSerializer.ErrorSerializer, error)

      assert result[:error] == "Unauthorized"
      assert result[:code] == "AUTH_REQUIRED"
      assert result[:status] == 401
    end

    test "serializes changeset errors" do
      # Simulating an Ecto changeset with errors
      changeset = %{
        errors: [
          email: {"is invalid", [validation: :format]},
          password:
            {"should be at least %{count} character(s)", [count: 8, validation: :length, min: 8]},
          name: {"can't be blank", [validation: :required]}
        ],
        valid?: false
      }

      {:ok, result} = NbSerializer.ErrorSerializer.serialize_changeset(changeset)

      assert result[:error] == "Validation Failed"
      assert result[:message] == "The provided data is invalid"
      assert result[:details][:email] == ["is invalid"]
      assert result[:details][:password] == ["should be at least 8 character(s)"]
      assert result[:details][:name] == ["can't be blank"]
    end

    test "serializes nested changeset errors" do
      changeset = %{
        errors: [
          email: {"is invalid", []}
        ],
        changes: %{
          profile: %{
            errors: [
              bio: {"is too long", [max: 500]},
              age: {"must be greater than %{number}", [number: 0]}
            ]
          }
        },
        valid?: false
      }

      {:ok, result} = NbSerializer.ErrorSerializer.serialize_changeset(changeset)

      assert result[:details][:email] == ["is invalid"]
      assert result[:details][:"profile.bio"] == ["is too long"]
      assert result[:details][:"profile.age"] == ["must be greater than 0"]
    end

    test "serializes multiple errors per field" do
      changeset = %{
        errors: [
          password: {"is too short", [min: 8]},
          password: {"must contain a number", []},
          password: {"must contain an uppercase letter", []}
        ],
        valid?: false
      }

      {:ok, result} = NbSerializer.ErrorSerializer.serialize_changeset(changeset)

      assert length(result[:details][:password]) == 3
      assert "is too short" in result[:details][:password]
      assert "must contain a number" in result[:details][:password]
      assert "must contain an uppercase letter" in result[:details][:password]
    end

    test "handles empty changeset" do
      changeset = %{
        errors: [],
        valid?: true
      }

      {:ok, result} = NbSerializer.ErrorSerializer.serialize_changeset(changeset)

      assert result[:error] == "Validation Failed"
      assert result[:details] == %{}
    end

    test "formats error for HTTP response" do
      error = %{
        error: "Server Error",
        message: "An unexpected error occurred"
      }

      {:ok, json} = NbSerializer.ErrorSerializer.to_json(error)

      assert json =~ ~s("error":"Server Error")
      assert json =~ ~s("message":"An unexpected error occurred")
    end

    test "supports custom error serializer" do
      defmodule CustomErrorSerializer do
        use NbSerializer.Serializer

        schema do
          field(:error_type, from: :error)
          field(:error_message, from: :message)
          field(:timestamp, compute: :add_timestamp)
          field(:request_id, compute: :get_request_id)
        end

        def add_timestamp(_error, _opts) do
          DateTime.utc_now() |> DateTime.to_iso8601()
        end

        def get_request_id(_error, opts) do
          opts[:request_id] || "unknown"
        end
      end

      error = %{
        error: "Not Found",
        message: "Resource not found"
      }

      {:ok, result} = NbSerializer.serialize(CustomErrorSerializer, error, request_id: "req-123")

      assert result[:error_type] == "Not Found"
      assert result[:error_message] == "Resource not found"
      assert result[:timestamp]
      assert result[:request_id] == "req-123"
    end
  end

  describe "integration with Phoenix" do
    defmodule TestSchema do
      use Ecto.Schema
      import Ecto.Changeset

      schema "test_schemas" do
        field(:email, :string)
        field(:name, :string)
      end

      def changeset(schema, attrs) do
        schema
        |> cast(attrs, [:email, :name])
        |> validate_required([:name])
        |> validate_format(:email, ~r/@/)
      end
    end

    test "works with changeset error rendering" do
      # Create a changeset with errors
      changeset = TestSchema.changeset(%TestSchema{}, %{email: "invalid"})

      # In real usage, this would be in a JSON view:
      # def error(%{changeset: changeset}) do
      #   NbSerializer.Phoenix.render_errors(changeset)
      # end

      # For testing, we'll call it directly
      error_data = NbSerializer.Phoenix.render_errors(changeset)

      assert error_data[:errors][:email] == ["has invalid format"]
      assert error_data[:errors][:name] == ["can't be blank"]
    end
  end
end
