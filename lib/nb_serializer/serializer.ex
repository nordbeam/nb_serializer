defmodule NbSerializer.Serializer do
  @moduledoc """
  Provides the DSL for defining serializers.

  This module is used via `use NbSerializer.Serializer` and provides
  macros for defining fields, relationships, and computed attributes.

  ## Options

    * `:for` - Struct module to automatically register this serializer for.
      Enables `NbSerializer.serialize_inferred/2` to work automatically.

  ## Examples

      # Without auto-registration
      defmodule UserSerializer do
        use NbSerializer.Serializer

        schema do
          field :id, :number
          field :name, :string
        end
      end

      # With auto-registration
      defmodule UserSerializer do
        use NbSerializer.Serializer, for: User

        schema do
          field :id, :number
          field :name, :string
        end
      end

  """

  defmacro __using__(opts) do
    struct_module = Keyword.get(opts, :for)

    quote do
      @behaviour NbSerializer.Behaviour

      import NbSerializer.DSL

      Module.register_attribute(__MODULE__, :nb_serializer_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :nb_serializer_relationships, accumulate: true)
      Module.register_attribute(__MODULE__, :nb_serializer_config, [])
      Module.register_attribute(__MODULE__, :nb_serializer_struct_module, [])
      Module.register_attribute(__MODULE__, :typescript_name, [])
      Module.register_attribute(__MODULE__, :typescript_namespace, [])

      # Store the struct module for validation and registration
      if unquote(struct_module) do
        @nb_serializer_struct_module unquote(struct_module)
      end

      @before_compile NbSerializer.Compiler

      # Register with the serializer registry after compilation
      if unquote(struct_module) do
        @after_compile {NbSerializer.Serializer, :__register__}
      end

      # Optional: Register after-compile hook for real-time TypeScript type generation
      # This only runs if nb_ts is available (it's an optional dependency)
      # Enables automatic type regeneration during development when serializers are recompiled
      if Code.ensure_loaded?(NbTs.CompileHooks) do
        @after_compile {NbTs.CompileHooks, :__after_compile__}
      end

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

  @doc false
  def __register__(env, _bytecode) do
    struct_module = Module.get_attribute(env.module, :nb_serializer_struct_module)

    if struct_module && Process.whereis(NbSerializer.Registry) do
      NbSerializer.Registry.register(struct_module, env.module)
    end

    :ok
  end
end
