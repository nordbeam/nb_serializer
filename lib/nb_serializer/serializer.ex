defmodule NbSerializer.Serializer do
  @moduledoc """
  Provides the DSL for defining serializers.

  This module is used via `use NbSerializer.Serializer` and provides
  macros for defining fields, relationships, and computed attributes.
  """

  # Behavior callbacks that serializers must implement
  @callback __nb_serializer_serialize__(data :: any(), opts :: keyword()) :: map()
  @callback __nb_serializer_fields__() :: [{atom(), keyword()}]
  @callback __nb_serializer_relationships__() :: [{atom(), keyword()}]

  @optional_callbacks __nb_serializer_fields__: 0, __nb_serializer_relationships__: 0

  defmacro __using__(_opts) do
    quote do
      import NbSerializer.DSL

      Module.register_attribute(__MODULE__, :nb_serializer_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :nb_serializer_relationships, accumulate: true)
      Module.register_attribute(__MODULE__, :nb_serializer_config, [])
      Module.register_attribute(__MODULE__, :typescript_name, [])

      @before_compile NbSerializer.Compiler

      def serialize(data, opts \\ [])

      def serialize(nil, _opts), do: nil

      def serialize(data, opts) when is_list(data) do
        Enum.map(data, &serialize(&1, opts))
      end

      def serialize(data, opts) do
        serialize_one(data, opts)
      end

      defp serialize_one(nil, _opts), do: nil

      defp serialize_one(data, opts) do
        __nb_serializer_serialize__(data, opts)
      end
    end
  end
end
