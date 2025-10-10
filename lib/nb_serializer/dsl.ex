defmodule NbSerializer.DSL do
  @moduledoc """
  Provides the DSL macros for defining serializer schemas.

  Following best practices from the Elixir community, this DSL avoids
  anonymous functions in favor of named module functions for better
  maintainability and clearer code.
  """

  # Type definitions for field options
  @type field_opts :: [
          type: atom() | binary(),
          enum: list(any()),
          nullable: boolean(),
          optional: boolean(),
          array: boolean(),
          from: atom(),
          default: any(),
          compute: atom(),
          transform: atom(),
          format: atom(),
          if: atom(),
          unless: atom(),
          on_error: :raise | :ignore | {:default, any()}
        ]

  @type relationship_opts :: [
          serializer: module(),
          key: atom() | binary(),
          if: atom(),
          compute: atom()
        ]

  @doc """
  Sets a custom TypeScript interface name for this serializer.

  By default, the TypeScript interface name is derived from the module name
  by taking the last segment and removing "Serializer" suffix. Use this macro
  to override the default behavior and provide a custom name.

  ## Examples

      defmodule MyApp.Serializers.Analytics.ShopSerializer do
        use NbSerializer.Serializer

        typescript_name "AnalyticsShop"

        schema do
          field :domain, :string
        end
      end

      # Generates: export interface AnalyticsShop { ... }
      # Instead of: export interface Shop { ... }
  """
  defmacro typescript_name(name) when is_binary(name) do
    quote do
      @typescript_name unquote(name)
    end
  end

  @doc """
  Defines the schema block for field definitions.
  """
  defmacro schema(do: block) do
    quote do
      unquote(block)
    end
  end

  @doc """
  Defines a single field to be serialized with optional TypeScript type.

  ## Type Options

    * `:type` - TypeScript type (:string, :number, :boolean, :any, or custom string)
    * `:enum` - List of allowed values for TypeScript enum type
    * `:nullable` - Whether the field can be null (default: false)
    * `:optional` - Whether the field is optional in TypeScript (default: false)
    * `:array` - Whether this is an array type (can be combined with :type)

  ## Options

    * `:from` - The source field name if different from the output name
    * `:default` - Default value if the field is nil or missing
    * `:compute` - Atom name of a function in this module that computes the value
    * `:transform` - Atom name of a function to transform the field value
    * `:format` - Format the field value using built-in or custom formatters
    * `:if` - Atom name of a function that returns boolean for conditional inclusion
    * `:on_error` - How to handle errors: :null, :skip, {:default, value}, or :reraise

  ## Examples

      # Simple types
      field :id, type: :number
      field :name, type: :string
      field :active, type: :boolean

      # Shorthand for common types (second parameter as atom)
      field :id, :number
      field :name, :string
      field :metadata, :any

      # Enum type
      field :status, enum: ["active", "inactive", "pending"]

      # Custom TypeScript type
      field :metadata, type: "Record<string, unknown>"

      # Nullable and optional
      field :email, :string, nullable: true
      field :phone, :string, optional: true

      # Array types
      field :tags, type: :string, array: true
      field :scores, :number, array: true

      # Combined with other field options
      field :full_name, :string, compute: :build_full_name
      field :admin_notes, :string, if: :admin?
  """
  # Original field macro without type (backward compatibility)
  defmacro field(name) when is_atom(name) do
    quote do
      @nb_serializer_fields {unquote(name), []}
    end
  end

  # Handle shorthand: field :name, :string (fixed guard issue)
  defmacro field(name, type_or_opts) when is_atom(name) do
    quote do
      opts =
        case unquote(type_or_opts) do
          atom when is_atom(atom) ->
            # Handle :typescript as special type that requires 3-arity form
            if atom == :typescript do
              raise CompileError,
                file: __ENV__.file,
                line: __ENV__.line,
                description: """
                :typescript type requires explicit type option with ~TS sigil:

                  field #{inspect(unquote(name))}, :typescript, type: ~TS"YourType"

                Example:
                  field :metadata, :typescript, type: ~TS"Record<string, any>"
                  field :config, :typescript, type: ~TS"{ enabled: boolean }"

                The ~TS sigil validates TypeScript syntax at compile time.
                """
            end

            type_opts = [type: atom]

            # Validate the type atom with context
            if Code.ensure_loaded?(NbSerializer.Typelizer.TypeValidator) do
              opts_with_context =
                type_opts
                |> Keyword.put(:__field__, unquote(name))
                |> Keyword.put(:__serializer__, __MODULE__)

              NbSerializer.Typelizer.TypeValidator.validate_field_opts(opts_with_context)
            end

            if atom in [:string, :number, :boolean, :decimal, :uuid, :date, :datetime, :any] do
              type_opts
            else
              # Treat as option key if not a valid type
              [atom]
            end

          opts when is_list(opts) ->
            # Add context for better error messages
            opts_with_context =
              opts
              |> Keyword.put(:__field__, unquote(name))
              |> Keyword.put(:__serializer__, __MODULE__)

            # Runtime validation if typelizer is available
            if Code.ensure_loaded?(NbSerializer.Typelizer.TypeValidator) do
              NbSerializer.Typelizer.TypeValidator.validate_field_opts(opts_with_context)
            end

            opts
        end

      @nb_serializer_fields {unquote(name), opts}
    end
  end

  # Handle field :name, :typescript, opts (special handling for :typescript type)
  defmacro field(name, :typescript, opts) when is_atom(name) and is_list(opts) do
    quote bind_quoted: [name: name, opts: opts] do
      # Validate that type option exists
      unless Keyword.has_key?(opts, :type) do
        raise CompileError,
          file: __ENV__.file,
          line: __ENV__.line,
          description: """
          :typescript type requires :type option with ~TS sigil:

            field #{inspect(name)}, :typescript, type: ~TS"YourType"

          Example:
            field :metadata, :typescript, type: ~TS"Record<string, any>"
          """
      end

      type_value = Keyword.get(opts, :type)

      # Verify it's a string (which means it went through ~TS or is a plain string)
      unless is_binary(type_value) do
        raise CompileError,
          file: __ENV__.file,
          line: __ENV__.line,
          description: """
          :typescript type must use ~TS sigil for validation:

            field #{inspect(name)}, :typescript, type: ~TS"YourType"

          Got: #{inspect(type_value)}

          The ~TS sigil validates TypeScript syntax at compile time.
          """
      end

      # Check if it's validated TypeScript (from ~TS sigil)
      # The ~TS sigil returns a plain string, so we need to check if it came from
      # the TypeScript module. We'll use a marker to distinguish validated types.
      # For now, we'll mark strings as validated if they pass basic checks.

      # Mark as validated TypeScript type
      merged_opts =
        opts
        |> Keyword.put(:typescript_validated, true)
        |> Keyword.put(:custom, true)

      @nb_serializer_fields {name, merged_opts}
    end
  end

  # Handle field :name, :string, opts (3-arity for backwards compat)
  defmacro field(name, type, opts) when is_atom(name) and is_atom(type) and is_list(opts) do
    quote do
      merged_opts =
        unquote(opts)
        |> Keyword.put(:type, unquote(type))
        |> Keyword.put(:__field__, unquote(name))
        |> Keyword.put(:__serializer__, __MODULE__)

      validated_opts =
        if Code.ensure_loaded?(NbSerializer.Typelizer.TypeValidator) do
          NbSerializer.Typelizer.TypeValidator.validate_field_opts(merged_opts)
        else
          Keyword.drop(merged_opts, [:__field__, :__serializer__])
        end

      # Remove context keys before storing
      clean_opts = Keyword.drop(validated_opts, [:__field__, :__serializer__])

      @nb_serializer_fields {unquote(name), clean_opts}
    end
  end

  @doc """
  Defines a has_one relationship.

  ## Options

    * `:serializer` - The serializer module to use
    * `:key` - Custom key name in the output
    * `:if` - Atom name of a conditional function
    * `:compute` - Atom name of a function that computes the association

  ## Example

      # Traditional approach with external serializer
      has_one :author, serializer: AuthorSerializer
      has_one :profile, serializer: ProfileSerializer, if: :include_profile?

      # Inline approach with block
      has_one :author do
        field :id
        field :name
        field :email
      end
  """
  defmacro has_one(name, opts \\ []) do
    quote do
      @nb_serializer_relationships {:has_one, unquote(name), unquote(opts)}
    end
  end

  @doc """
  Defines a has_many relationship.

  ## Options

    * `:serializer` - The serializer module to use
    * `:key` - Custom key name in the output
    * `:if` - Atom name of a conditional function
    * `:compute` - Atom name of a function that computes the association

  ## Example

      # Traditional approach with external serializer
      has_many :comments, serializer: CommentSerializer
      has_many :tags, serializer: TagSerializer, if: :include_tags?

      # Inline approach with block
      has_many :posts do
        field :id
        field :title
        field :published
      end
  """
  defmacro has_many(name, opts \\ []) do
    quote do
      @nb_serializer_relationships {:has_many, unquote(name), unquote(opts)}
    end
  end

  @doc """
  Defines a belongs_to relationship (alias for has_one).

  ## Options

    * `:serializer` - The serializer module to use
    * `:key` - Custom key name in the output
    * `:if` - Atom name of a conditional function
    * `:compute` - Atom name of a function that computes the association

  ## Example

      # Traditional approach
      belongs_to :user, serializer: UserSerializer

      # Inline approach
      belongs_to :user do
        field :id
        field :name
      end
  """
  defmacro belongs_to(name, opts \\ []) do
    quote do
      @nb_serializer_relationships {:has_one, unquote(name), unquote(opts)}
    end
  end
end
