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

  def prepare_data(%Ecto.Changeset{data: data}) do
    prepare_data(data)
  end

  def prepare_data(data), do: data

  @doc """
  Checks if an association is loaded.
  """
  def loaded?(%Ecto.Association.NotLoaded{}), do: false
  def loaded?(_), do: true

  @doc """
  Helper to conditionally include associations based on whether they're loaded.
  """
  def if_loaded(data, field) do
    case Map.get(data, field) do
      %Ecto.Association.NotLoaded{} -> false
      _ -> true
    end
  end
end
