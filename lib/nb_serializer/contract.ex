defmodule NbSerializer.Contract do
  @moduledoc """
  A dependency-free, inspectable representation of a serializer contract.

  `NbSerializer` deliberately does not depend on `NbTs`, so this module is the
  boundary between the serializer DSL and optional code generators.  The
  returned value is made up of maps, lists, atoms, and module names and can be
  consumed by any generator without loading the TypeScript package.

  The shape is versioned.  Consumers should use the keys documented below and
  ignore keys they do not understand so that adding serializer metadata remains
  backwards compatible.

      %{
        version: 1,
        kind: :serializer,
        module: MyApp.UserSerializer,
        name: "User",
        namespace: nil,
        fields: [
          %{
            name: :id,
            type: :integer,
            serializer: nil,
            list: false,
            optional: false,
            nullable: false,
            source: :id,
            condition: nil,
            on_error: nil,
            transform: nil,
            format: nil,
            default: nil
          }
        ],
        metadata: %{}
      }

  Presence and nullability intentionally describe the serialized wire shape,
  not only the declared Elixir type:

    * `if:`/`unless:` and `on_error: :skip` make a field optional.
    * `on_error: :null` makes a field nullable.
    * `default:` does not make a field optional because the pipeline materializes
      a value when the source is nil.

  The semantic options (`transform`, `format`, `compute`, `from`, and
  `on_error`) are retained verbatim for generators that can model them more
  precisely (for example, a runtime Zod schema).
  """

  @version 1

  @type field :: map()
  @type relationship :: map()
  @type t :: %{
          required(:version) => pos_integer(),
          required(:kind) => :serializer,
          required(:module) => module(),
          required(:name) => String.t(),
          optional(:namespace) => String.t() | nil,
          required(:fields) => [field()],
          optional(:relationships) => [relationship()],
          optional(:metadata) => map()
        }

  @doc "Returns the current serializer contract version."
  @spec version() :: pos_integer()
  def version, do: @version

  @doc "Builds a contract from a compiled serializer module."
  @spec build(module()) :: t()
  def build(module) when is_atom(module) do
    # Prefer the compile-time snapshot when available.  Besides avoiding a
    # second normalization pass, this means generators see exactly the same
    # contract that was compiled with the serializer (including options that a
    # future serializer version may add).
    if function_exported?(module, :__nb_serializer_contract__, 0) do
      module.__nb_serializer_contract__()
    else
      build_from_legacy_metadata(module)
    end
  end

  defp build_from_legacy_metadata(module) do
    fields =
      if function_exported?(module, :__nb_serializer_fields__, 0),
        do: module.__nb_serializer_fields__(),
        else: []

    relationships =
      if function_exported?(module, :__nb_serializer_relationships__, 0),
        do: module.__nb_serializer_relationships__(),
        else: []

    type_metadata =
      if function_exported?(module, :__nb_serializer_type_metadata__, 0),
        do: module.__nb_serializer_type_metadata__(),
        else: %{}

    from_parts(module, fields, relationships, type_metadata,
      name: typescript_name(module),
      namespace: typescript_namespace(module)
    )
  end

  @doc false
  @spec from_parts(module(), list(), list(), map() | list(), keyword()) :: t()
  def from_parts(module, fields, relationships, type_metadata, opts \\ []) do
    metadata = normalize_type_metadata(type_metadata)

    normalized_fields =
      fields
      |> Enum.map(&normalize_field(&1, metadata))
      |> Enum.reject(&is_nil/1)

    normalized_relationships =
      relationships
      |> Enum.map(&normalize_relationship/1)
      |> Enum.reject(&is_nil/1)

    %{
      version: @version,
      kind: :serializer,
      module: module,
      name: Keyword.get(opts, :name, typescript_name(module)),
      namespace: Keyword.get(opts, :namespace, typescript_namespace(module)),
      fields: sort_by_name(normalized_fields),
      relationships: sort_by_name(normalized_relationships),
      metadata: %{
        snake_case: Keyword.get(opts, :snake_case, snake_case?(module)),
        struct_module: Keyword.get(opts, :struct_module, struct_module(module))
      }
    }
  end

  @doc false
  @spec normalize_type_metadata(map() | list()) :: map()
  def normalize_type_metadata(%{fields: fields}) when is_list(fields) do
    Enum.reduce(fields, %{}, fn field, acc ->
      name = Map.get(field, :name)

      if is_nil(name) do
        acc
      else
        Map.put(acc, name, Map.drop(field, [:name]))
      end
    end)
  end

  def normalize_type_metadata(metadata) when is_map(metadata), do: metadata
  def normalize_type_metadata(_metadata), do: %{}

  @doc false
  def field_presence?(opts) when is_list(opts) do
    Keyword.get(opts, :optional, false) or
      Keyword.has_key?(opts, :if) or
      Keyword.has_key?(opts, :unless) or
      Keyword.get(opts, :on_error) == :skip
  end

  @doc false
  def field_nullable?(opts) when is_list(opts) do
    Keyword.get(opts, :nullable, false) or Keyword.get(opts, :on_error) == :null
  end

  @doc false
  def normalize_field({name, opts}, type_metadata) when is_atom(name) and is_list(opts) do
    type_info = Map.get(type_metadata, name, %{})

    %{
      name: name,
      type: Keyword.get(opts, :type, Map.get(type_info, :type)),
      enum: Keyword.get(opts, :enum, Map.get(type_info, :enum)),
      list: Keyword.get(opts, :list, Map.get(type_info, :list, false)),
      serializer: Keyword.get(opts, :serializer, Map.get(type_info, :serializer)),
      polymorphic: Keyword.get(opts, :polymorphic, Map.get(type_info, :polymorphic)),
      typescript_validated:
        Keyword.get(opts, :typescript_validated, Map.get(type_info, :typescript_validated, false)),
      custom: Keyword.get(opts, :custom, Map.get(type_info, :custom, false)),
      optional: field_presence?(opts) or Map.get(type_info, :optional, false),
      nullable: field_nullable?(opts) or Map.get(type_info, :nullable, false),
      source: Keyword.get(opts, :from, name),
      compute: Keyword.get(opts, :compute),
      condition: Keyword.get(opts, :if) || Keyword.get(opts, :unless),
      if: Keyword.get(opts, :if),
      unless: Keyword.get(opts, :unless),
      on_error: Keyword.get(opts, :on_error),
      on_missing: Keyword.get(opts, :on_missing),
      transform: Keyword.get(opts, :transform),
      format: Keyword.get(opts, :format),
      default: Keyword.get(opts, :default),
      raw: Keyword.get(opts, :raw, false),
      opts: opts
    }
  end

  def normalize_field(_field, _type_metadata), do: nil

  @doc false
  def normalize_relationship({kind, name, opts})
      when kind in [:has_one, :has_many] and is_atom(name) and is_list(opts) do
    cardinality = if kind == :has_many, do: :many, else: :one

    %{
      name: Keyword.get(opts, :key, name),
      source: name,
      kind: :relationship,
      cardinality: cardinality,
      serializer: Keyword.get(opts, :serializer),
      polymorphic: Keyword.get(opts, :polymorphic),
      optional: field_presence?(opts),
      nullable: field_nullable?(opts) or Keyword.get(opts, :on_missing) == :null,
      compute: Keyword.get(opts, :compute),
      condition: Keyword.get(opts, :if) || Keyword.get(opts, :unless),
      if: Keyword.get(opts, :if),
      unless: Keyword.get(opts, :unless),
      on_error: Keyword.get(opts, :on_error),
      on_missing: Keyword.get(opts, :on_missing),
      opts: opts
    }
  end

  def normalize_relationship(_relationship), do: nil

  defp sort_by_name(entries), do: Enum.sort_by(entries, &to_string(Map.get(&1, :name, "")))

  @doc false
  def typescript_name(module) when is_atom(module) do
    custom_name =
      if function_exported?(module, :__nb_serializer_typescript_name__, 0),
        do: module.__nb_serializer_typescript_name__(),
        else: nil

    namespace = typescript_namespace(module)
    base_name = default_name(module)

    cond do
      is_binary(custom_name) -> custom_name
      is_binary(namespace) -> namespace <> base_name
      true -> base_name
    end
  end

  @doc false
  def typescript_namespace(module) when is_atom(module) do
    if function_exported?(module, :__nb_serializer_typescript_namespace__, 0),
      do: module.__nb_serializer_typescript_namespace__(),
      else: nil
  end

  defp default_name(module) do
    module |> Module.split() |> List.last() |> String.replace(~r/Serializer$/, "")
  end

  defp snake_case?(module) do
    function_exported?(module, :__nb_serializer_snake_case_ts__, 0) and
      module.__nb_serializer_snake_case_ts__()
  end

  defp struct_module(module) do
    if function_exported?(module, :__nb_serializer_struct_module__, 0),
      do: module.__nb_serializer_struct_module__(),
      else: nil
  end
end
