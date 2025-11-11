defmodule NbSerializer.Behaviour do
  @moduledoc """
  Defines the behaviour that all serializers must implement.

  This behaviour makes the serializer contract explicit and enables compile-time
  validation and better Dialyzer support.

  ## Callbacks

    * `__nb_serializer_serialize__/2` - Required. The main serialization function
    * `__nb_serializer_fields__/0` - Returns the list of field definitions
    * `__nb_serializer_relationships__/0` - Returns the list of relationship definitions
    * `__nb_serializer_type_metadata__/0` - Returns type metadata for TypeScript generation
    * `__nb_serializer_typescript_name__/0` - Returns custom TypeScript interface name if set

  ## Example

      defmodule UserSerializer do
        use NbSerializer.Serializer

        schema do
          field :id, :number
          field :name, :string
          field :email, :string
        end
      end

  The `use NbSerializer.Serializer` macro automatically implements this behaviour.
  """

  @doc """
  Serializes the given data with the provided options.

  Returns a map representation of the serialized data.
  """
  @callback __nb_serializer_serialize__(data :: any(), opts :: keyword()) :: map()

  @doc """
  Returns the list of field definitions for this serializer.

  Each field is a tuple of `{field_name, field_options}`.
  """
  @callback __nb_serializer_fields__() :: [{atom(), keyword()}]

  @doc """
  Returns the list of relationship definitions for this serializer.

  Each relationship is a tuple of `{type, name, options}`.
  """
  @callback __nb_serializer_relationships__() :: [{atom(), atom(), keyword()}]

  @doc """
  Returns type metadata for TypeScript generation.

  Returns a map where keys are field names and values are type information maps.
  """
  @callback __nb_serializer_type_metadata__() :: %{atom() => map()}

  @doc """
  Returns the custom TypeScript interface name if one was set.

  Returns `nil` if no custom name was configured.
  """
  @callback __nb_serializer_typescript_name__() :: binary() | nil

  @optional_callbacks [
    __nb_serializer_fields__: 0,
    __nb_serializer_relationships__: 0,
    __nb_serializer_type_metadata__: 0,
    __nb_serializer_typescript_name__: 0
  ]
end
