defmodule NbSerializer.Phoenix do
  @moduledoc """
  Phoenix integration helpers for NbSerializer serializers.

  Provides convenience functions for using NbSerializer serializers in Phoenix JSON views.
  This module follows Phoenix 1.7+ patterns where JSON rendering is handled by
  dedicated JSON modules rather than controllers.

  ## Usage in Phoenix JSON views

      defmodule MyAppWeb.UserJSON do
        use NbSerializer.Phoenix

        alias MyApp.Serializers.UserSerializer

        def index(%{users: users}) do
          %{users: render_many(users, UserSerializer)}
        end

        def show(%{user: user}) do
          %{user: render_one(user, UserSerializer)}
        end

        def create(%{user: user}) do
          %{user: render_one(user, UserSerializer)}
        end

        def error(%{changeset: changeset}) do
          render_errors(changeset)
        end
      end

  ## In your controller

      defmodule MyAppWeb.UserController do
        use MyAppWeb, :controller

        def index(conn, _params) do
          users = Users.list_users()
          render(conn, :index, users: users)
        end

        def show(conn, %{"id" => id}) do
          user = Users.get_user!(id)
          render(conn, :show, user: user)
        end
      end

  ## With pagination

      def index(%{users: users, meta: meta}) do
        %{
          users: render_many(users, UserSerializer),
          meta: meta
        }
      end

  ## With conditional serialization

      def show(%{user: user, current_scope: current_scope}) do
        %{user: render_one(user, UserSerializer, current_scope: current_scope)}
      end
  """

  # Type definitions
  @type data :: any()
  @type serializer :: module()
  @type opts :: keyword()
  @type serialized :: map() | list(map()) | nil
  @type changeset :: map()

  defmacro __using__(_opts) do
    quote do
      import NbSerializer.Phoenix
    end
  end

  alias NbSerializer.Utils

  @doc """
  Serializes a collection of resources.

  ## Examples

      render_many(users, UserSerializer)
      render_many(users, UserSerializer, view: :detailed)
  """
  @spec render_many(data(), serializer(), opts()) :: serialized()
  def render_many(data, serializer, opts \\ []) do
    cond do
      is_nil(data) ->
        nil

      data == [] ->
        []

      is_list(data) ->
        case NbSerializer.serialize(serializer, data, opts) do
          {:ok, result} -> result
          {:error, _} -> []
        end

      true ->
        data
    end
  end

  @doc """
  Serializes a single resource.

  ## Examples

      render_one(user, UserSerializer)
      render_one(user, UserSerializer, view: :admin)
  """
  @spec render_one(data(), serializer(), opts()) :: serialized()
  def render_one(data, serializer, opts \\ []) do
    case Utils.handle_nil_or_empty(data, :one) do
      nil ->
        nil

      data ->
        case NbSerializer.serialize(serializer, data, opts) do
          {:ok, result} -> result
          {:error, _} -> nil
        end
    end
  end

  @doc """
  Shorthand for serializing data. Automatically detects whether to use
  render_one or render_many based on the data type.

  ## Examples

      render(user, UserSerializer)
      render(users, UserSerializer)
  """
  @spec render(data(), serializer(), opts()) :: serialized()
  def render(data, serializer, opts \\ []) do
    cond do
      is_nil(data) -> nil
      is_list(data) -> render_many(data, serializer, opts)
      true -> render_one(data, serializer, opts)
    end
  end

  @doc """
  Formats Ecto changeset errors for JSON responses.

  Returns a map with an `:errors` key containing field-level error messages.

  ## Examples

      render_errors(changeset)
      # => %{errors: %{email: ["can't be blank"], name: ["is too short"]}}
  """
  @spec render_errors(changeset()) :: map()
  def render_errors(changeset) do
    errors = Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
    %{errors: errors}
  end

  @doc """
  Translates an error message.

  This function can be customized to provide internationalization support.
  By default, it returns the error message as-is.
  """
  @spec translate_error({binary(), keyword()} | binary()) :: binary()
  def translate_error({msg, opts}) do
    # You can customize this to use gettext or another i18n library
    # For now, we'll do simple interpolation
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  def translate_error(msg) when is_binary(msg), do: msg
end
