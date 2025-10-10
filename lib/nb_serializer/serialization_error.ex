defmodule NbSerializer.SerializationError do
  @moduledoc """
  Error raised during serialization when strict mode is enabled or
  when on_error: :reraise is used.
  """

  defexception [:message, :field, :original_error]

  @impl true
  def exception(opts) do
    %__MODULE__{
      message: opts[:message],
      field: opts[:field],
      original_error: opts[:original_error]
    }
  end

  @impl true
  def message(%__MODULE__{message: message}) when is_binary(message) do
    message
  end

  def message(%__MODULE__{field: field, original_error: original}) do
    cond do
      field && original && is_exception(original) ->
        "Error serializing field :#{field}: #{Exception.message(original)}"

      field && original && is_binary(original) ->
        "Error serializing field :#{field}: #{original}"

      field && original ->
        "Error serializing field :#{field}: #{inspect(original)}"

      field ->
        "Error serializing field :#{field}"

      original && is_exception(original) ->
        "Serialization error: #{Exception.message(original)}"

      original && is_binary(original) ->
        "Serialization error: #{original}"

      original ->
        "Serialization error: #{inspect(original)}"

      true ->
        "Unknown serialization error"
    end
  end
end
