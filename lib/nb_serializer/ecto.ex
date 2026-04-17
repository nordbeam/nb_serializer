defmodule NbSerializer.Ecto do
  @moduledoc """
  Provides Ecto-specific functionality for NbSerializer serializers.

  When used, this module adds helpers for dealing with Ecto schemas,
  associations, and changesets.
  """

  defmacro __using__(_opts) do
    quote do
      # Override the serialize_one function to handle Ecto-specific types
      defp serialize_one(data, opts) do
        data
        |> NbSerializer.Ecto.prepare_data()
        |> __nb_serializer_serialize__(opts)
      end
    end
  end

  @doc """
  Prepares Ecto data for serialization by cleaning metadata.
  """
  def prepare_data(%{__meta__: _} = schema) do
    schema
    |> Map.from_struct()
    |> Map.delete(:__meta__)
  end

  def prepare_data(data) do
    if NbSerializer.Utils.ecto_changeset?(data) do
      prepare_data(data.data)
    else
      data
    end
  end

  @doc """
  Checks if an association is loaded.
  """
  def loaded?(data), do: not NbSerializer.Utils.ecto_not_loaded?(data)

  @doc """
  Helper to conditionally include associations based on whether they're loaded.
  """
  def if_loaded(data, field) do
    data
    |> Map.get(field)
    |> loaded?()
  end
end
