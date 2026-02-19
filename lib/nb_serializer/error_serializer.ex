defmodule NbSerializer.ErrorSerializer do
  @moduledoc """
  Standard error serializer for consistent error responses.

  Provides serialization for errors, validation failures, and Ecto changesets.

  ## Usage

      # Structured error (uses schema)
      NbSerializer.ErrorSerializer.serialize(%{
        error: "Not Found",
        message: "The requested resource was not found"
      })

      # Flat field errors (passed through as-is)
      NbSerializer.ErrorSerializer.serialize(%{
        name: "can't be blank",
        email: "has invalid format"
      })
      # => %{name: "can't be blank", email: "has invalid format"}

      # Changeset errors
      NbSerializer.ErrorSerializer.serialize_changeset(changeset)

      # Custom error serializer
      defmodule MyErrorSerializer do
        use NbSerializer.Serializer

        schema do
          field :error, :string
          field :message, :string
          field :code, :string
          field :timestamp, :datetime, compute: :current_time
        end

        def current_time(_error, _opts) do
          DateTime.utc_now()
        end
      end
  """

  alias NbSerializer.Utils

  # Type definitions
  @type error_data :: map()
  @type changeset :: map()
  @type serialized :: map()
  @type json_string :: binary()
  @type opts :: keyword()

  use NbSerializer.Serializer

  # Fields that indicate a structured error response (vs flat field errors)
  @known_fields MapSet.new(~w(error message code status details field)a)

  schema do
    field(:error, :string, optional: true)
    field(:message, :string, optional: true)
    field(:code, :string, optional: true)
    field(:status, :number, optional: true)
    field(:details, :any, optional: true)
    field(:field, :string, optional: true)
  end

  # Override serialize to handle flat field error maps.
  # Maps like %{slug: "taken", name: "can't be blank"} (from Inertia.Errors.to_errors)
  # are passed through as-is instead of being forced through the schema (which drops them).
  def serialize(nil, _opts), do: nil
  def serialize(data, opts) when is_list(data), do: Enum.map(data, &serialize(&1, opts))

  def serialize(%{} = data, opts) when not is_struct(data) do
    if flat_field_errors?(data), do: data, else: super(data, opts)
  end

  def serialize(data, opts), do: super(data, opts)

  @doc """
  Serializes an Ecto changeset into a standard error format.
  """
  @spec serialize_changeset(changeset(), opts()) :: {:ok, serialized()} | {:error, term()}
  def serialize_changeset(changeset, opts \\ []) do
    try do
      details = extract_changeset_errors(changeset)

      error_data = %{
        error: "Validation Failed",
        message: opts[:message] || "The provided data is invalid",
        details: details
      }

      {:ok, serialize(error_data, opts)}
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Serializes an Ecto changeset into a standard error format (bang version).
  """
  @spec serialize_changeset!(changeset(), opts()) :: serialized() | no_return()
  def serialize_changeset!(changeset, opts \\ []) do
    case serialize_changeset(changeset, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise NbSerializer.SerializationError, message: inspect(reason)
    end
  end

  @doc """
  Converts error to JSON string.

  Returns {:ok, json_string} or {:error, reason}.
  """
  @spec to_json(error_data(), opts()) :: {:ok, json_string()} | {:error, term()}
  def to_json(error, opts \\ []) do
    try do
      serialized = __MODULE__.serialize(error, opts)
      {:ok, NbSerializer.encoder().encode!(serialized)}
    rescue
      e -> {:error, e}
    end
  end

  @doc """
  Converts error to JSON string (bang version).

  Returns a JSON string or raises on error.
  """
  @spec to_json!(error_data(), opts()) :: json_string() | no_return()
  def to_json!(error, opts \\ []) do
    case to_json(error, opts) do
      {:ok, json} -> json
      {:error, reason} -> raise NbSerializer.SerializationError, message: inspect(reason)
    end
  end

  # Extract errors from changeset
  defp extract_changeset_errors(%{errors: errors} = changeset) do
    # Get top-level errors
    top_level_errors = format_errors(errors)

    # Get nested errors from changes
    nested_errors = extract_nested_errors(changeset[:changes] || %{})

    Map.merge(top_level_errors, nested_errors)
  end

  defp extract_changeset_errors(_), do: %{}

  defp format_errors(errors) when is_list(errors) do
    errors
    |> Enum.group_by(
      fn {field, _} -> field end,
      fn {_, {msg, opts}} -> format_error_message(msg, opts) end
    )
    |> Map.new()
  end

  defp format_errors(_), do: %{}

  defp format_error_message(msg, opts) do
    Utils.format_error_message(msg, opts)
  end

  defp extract_nested_errors(changes) when is_map(changes) do
    Enum.reduce(changes, %{}, fn {field, value}, acc ->
      case value do
        %{errors: errors} when is_list(errors) and length(errors) > 0 ->
          nested = format_errors(errors)
          # Prefix nested field names
          prefixed =
            Map.new(nested, fn {k, v} ->
              {:"#{field}.#{k}", v}
            end)

          Map.merge(acc, prefixed)

        _ ->
          acc
      end
    end)
  end

  defp extract_nested_errors(_), do: %{}

  # A map is considered "flat field errors" if none of its keys match the schema fields.
  # e.g., %{slug: "taken", name: "can't be blank"} → true (pass through)
  # e.g., %{error: "Not Found", message: "..."} → false (use schema)
  defp flat_field_errors?(data) when map_size(data) == 0, do: true

  defp flat_field_errors?(data) do
    not Enum.any?(Map.keys(data), &MapSet.member?(@known_fields, &1))
  end
end
