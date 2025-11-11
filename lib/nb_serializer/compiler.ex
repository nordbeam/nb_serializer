defmodule NbSerializer.Compiler do
  @moduledoc """
  Compiles the serializer DSL into an efficient serialization function.
  """

  defmacro __before_compile__(env) do
    fields = Module.get_attribute(env.module, :nb_serializer_fields) |> Enum.reverse()

    relationships =
      Module.get_attribute(env.module, :nb_serializer_relationships) |> Enum.reverse()

    typescript_name = Module.get_attribute(env.module, :typescript_name)

    # Validate compute functions at compile time
    validate_compute_functions(env.module, fields, relationships)

    # Build type metadata from field definitions
    type_metadata = build_type_metadata(fields, relationships)

    quote do
      @__nb_serializer_fields__ unquote(Macro.escape(fields))
      @__nb_serializer_relationships__ unquote(Macro.escape(relationships))

      def __nb_serializer_serialize__(data, opts) do
        field_map =
          NbSerializer.Compiler.Runtime.process_fields(
            data,
            opts,
            @__nb_serializer_fields__,
            __MODULE__
          )

        rel_map =
          NbSerializer.Compiler.Runtime.process_relationships(
            data,
            opts,
            @__nb_serializer_relationships__,
            __MODULE__
          )

        Map.merge(field_map, rel_map)
      end

      # Expose field metadata for testing and typelizer
      def __nb_serializer_fields__, do: @__nb_serializer_fields__
      def __nb_serializer_relationships__, do: @__nb_serializer_relationships__

      # Expose type metadata for typelizer
      def __nb_serializer_type_metadata__ do
        unquote(Macro.escape(type_metadata))
      end

      # Expose custom TypeScript name if provided
      def __nb_serializer_typescript_name__ do
        unquote(typescript_name)
      end

      # Generate TypeScript interface (moved to nb_ts library)
      def __nb_serializer_typescript_interface__ do
        if Code.ensure_loaded?(NbTs.Interface) do
          NbTs.Interface.build(__MODULE__)
        else
          nil
        end
      end

      # Lazy registration when needed (moved to nb_ts library)
      def __nb_serializer_ensure_registered__ do
        if Code.ensure_loaded?(NbTs.Registry) and
             Process.whereis(NbTs.Registry) do
          NbTs.Registry.register(__MODULE__)
        end

        :ok
      end
    end
  end

  defp validate_compute_functions(module, fields, relationships) do
    # Check for potential circular references (self-referential serializers)
    check_for_circular_references(module, relationships)

    # Validate field compute functions
    Enum.each(fields, fn {name, opts} ->
      if compute = opts[:compute] do
        # Only raise compile error if no error handling is specified
        has_function = Module.defines?(module, {compute, 2})
        has_error_handler = opts[:on_error] != nil

        if not has_function and not has_error_handler do
          raise NbSerializer.CompileError,
            module: module,
            field: name,
            function: compute,
            arity: 2,
            type: :compute
        end
      end

      if transform = opts[:transform] do
        if not Module.defines?(module, {transform, 1}) do
          raise NbSerializer.CompileError,
            module: module,
            field: name,
            function: transform,
            arity: 1,
            type: :transform
        end
      end
    end)

    # Validate relationship compute functions
    Enum.each(relationships, fn {_type, name, opts} ->
      if compute = opts[:compute] do
        # Only raise compile error if no error handling is specified
        has_function = Module.defines?(module, {compute, 2})
        has_error_handler = opts[:on_error] != nil

        if not has_function and not has_error_handler do
          raise NbSerializer.CompileError,
            module: module,
            field: name,
            function: compute,
            arity: 2,
            type: :compute
        end
      end
    end)
  end

  defp build_type_metadata(fields, relationships) do
    field_types =
      Enum.map(fields, fn {name, opts} ->
        if Code.ensure_loaded?(NbTs.TypeMapper) do
          type_info = NbTs.TypeMapper.normalize_type_opts(opts)

          # Preserve typescript_validated flag from DSL
          type_info =
            if Keyword.get(opts, :typescript_validated, false) do
              Map.put(type_info, :typescript_validated, true)
            else
              type_info
            end

          {name, type_info}
        else
          {name, %{}}
        end
      end)

    relationship_types =
      Enum.map(relationships, fn {type, name, opts} ->
        serializer = Keyword.get(opts, :serializer)
        # Mark as optional if the relationship has an `if:` condition
        has_condition = Keyword.has_key?(opts, :if)

        type_info =
          case type do
            :has_one ->
              %{type: :custom, custom: true, serializer: serializer, optional: has_condition}

            :has_many ->
              %{
                type: :custom,
                custom: true,
                list: true,
                serializer: serializer,
                optional: has_condition
              }
          end

        {name, type_info}
      end)

    Enum.into(field_types ++ relationship_types, %{})
  end

  defp check_for_circular_references(module, relationships) do
    # Check if any relationship points back to the same module (self-referential)
    self_refs =
      Enum.filter(relationships, fn
        {_type, _name, opts} ->
          serializer = Keyword.get(opts, :serializer)
          serializer == module or serializer == {:__MODULE__, [], nil}
      end)

    if not Enum.empty?(self_refs) do
      ref_names = Enum.map(self_refs, fn {_type, name, _opts} -> name end)

      IO.warn(
        """
        Potential circular reference detected in #{inspect(module)}!

        Self-referential associations: #{inspect(ref_names)}

        This can cause infinite recursion when serializing.

        To handle this safely, use the `max_depth` option when serializing:

            NbSerializer.serialize(#{inspect(module)}, data, max_depth: 3)

        Or implement conditional logic in your serializer to break cycles:

            has_one :parent, serializer: __MODULE__, if: :include_parent?

            def include_parent?(_data, opts) do
              # Check depth or other conditions
              opts[:depth] < 3
            end

        Learn more: https://hexdocs.pm/nb_serializer/circular-references.html
        """,
        []
      )
    end
  end
end

defmodule NbSerializer.Compiler.Runtime do
  @moduledoc false

  alias NbSerializer.Utils
  alias NbSerializer.Pipeline

  # Helper to get option from both maps and keyword lists
  defp get_opt(opts, key, default) when is_map(opts) do
    Map.get(opts, key, default)
  end

  defp get_opt(opts, key, default) when is_list(opts) do
    Keyword.get(opts, key, default)
  end

  defp get_opt(_, _, default), do: default

  # Helper to put option in both maps and keyword lists
  defp put_opt(opts, key, value) when is_map(opts) do
    Map.put(opts, key, value)
  end

  defp put_opt(opts, key, value) when is_list(opts) do
    Keyword.put(opts, key, value)
  end

  defp put_opt(opts, _, _), do: opts

  def process_fields(data, opts, fields, module) do
    fields
    |> Enum.filter(&should_include?(data, opts, elem(&1, 1), module))
    |> Enum.reduce(%{}, fn {field_name, field_opts}, acc ->
      with {:ok, value} <- safe_get_field_value(data, field_name, field_opts, opts, module) do
        Map.put(acc, field_name, value)
      else
        {:skip, _} -> acc
      end
    end)
  end

  def process_relationships(data, opts, relationships, module) do
    # Use parallel processing for multiple relationships to improve performance
    parallel_threshold = get_opt(opts, :parallel_threshold, 3)

    if length(relationships) >= parallel_threshold do
      process_relationships_parallel(data, opts, relationships, module)
    else
      process_relationships_sequential(data, opts, relationships, module)
    end
  end

  defp process_relationships_sequential(data, opts, relationships, module) do
    Enum.reduce(relationships, %{}, &process_relationship(&1, data, opts, &2, module))
  end

  defp process_relationships_parallel(data, opts, relationships, module) do
    max_concurrency = System.schedulers_online()

    relationships
    |> Task.async_stream(
      fn rel ->
        {get_relationship_key(rel), process_relationship_value(rel, data, opts, module)}
      end,
      max_concurrency: max_concurrency,
      timeout: get_opt(opts, :relationship_timeout, 30_000)
    )
    |> Enum.reduce(%{}, fn
      {:ok, {key, {:ok, value}}}, acc ->
        Map.put(acc, key, value)

      {:ok, {_key, {:skip, _}}}, acc ->
        acc

      {:exit, reason}, acc ->
        # Log error but continue with other relationships
        require Logger
        Logger.warning("Relationship processing failed: #{inspect(reason)}")
        acc
    end)
  end

  defp get_relationship_key({:has_one, name, opts}), do: opts[:key] || name
  defp get_relationship_key({:has_many, name, opts}), do: opts[:key] || name

  defp process_relationship_value(rel, data, opts, module) do
    case rel do
      {:has_one, name, rel_opts} ->
        if should_include?(data, opts, rel_opts, module) do
          safe_get_relationship_value(:has_one, name, rel_opts, data, opts, module)
        else
          {:skip, nil}
        end

      {:has_many, name, rel_opts} ->
        if should_include?(data, opts, rel_opts, module) do
          safe_get_relationship_value(:has_many, name, rel_opts, data, opts, module)
        else
          {:skip, nil}
        end
    end
  end

  defp process_relationship({:has_one, name, rel_opts}, data, opts, acc, module) do
    key = rel_opts[:key] || name

    if should_include?(data, opts, rel_opts, module) do
      result =
        safe_get_relationship_value(:has_one, name, rel_opts, data, opts, module)

      case result do
        {:ok, value} -> Map.put(acc, key, value)
        {:skip, _} -> acc
      end
    else
      acc
    end
  end

  defp process_relationship({:has_many, name, rel_opts}, data, opts, acc, module) do
    key = rel_opts[:key] || name

    if should_include?(data, opts, rel_opts, module) do
      result =
        safe_get_relationship_value(:has_many, name, rel_opts, data, opts, module)

      case result do
        {:ok, value} -> Map.put(acc, key, value)
        {:skip, _} -> acc
      end
    else
      acc
    end
  end

  defp safe_get_field_value(data, field_name, field_opts, opts, module) do
    on_error = field_opts[:on_error]

    try do
      value = get_field_value(data, field_name, field_opts, opts, module)
      {:ok, value}
    rescue
      error ->
        handle_field_error(error, field_name, on_error, data, opts, module)
    end
  end

  defp get_field_value(data, field_name, field_opts, opts, module) do
    cond do
      # Computed field
      compute = field_opts[:compute] ->
        value = apply(module, compute, [data, opts])
        Pipeline.transform(value, field_opts, module)

      # Field with different source name
      from = field_opts[:from] ->
        value = get_data_value(data, from)
        Pipeline.transform(value, field_opts, module)

      # Simple field
      true ->
        value = get_data_value(data, field_name)
        Pipeline.transform(value, field_opts, module)
    end
  end

  defp handle_field_error(error, field_name, on_error, data, opts, module) do
    case on_error do
      nil ->
        # No error handler specified - reraise original error
        raise error

      :null ->
        {:ok, nil}

      :skip ->
        {:skip, nil}

      {:default, value} ->
        {:ok, value}

      :reraise ->
        raise NbSerializer.SerializationError, field: field_name, original_error: error

      # If it's an atom but not a special keyword, treat it as a function name
      handler when is_atom(handler) and not is_nil(module) ->
        {:ok, apply(module, handler, [error, data, opts])}

      # Default behavior - reraise original error
      _ ->
        raise error
    end
  end

  defp safe_get_relationship_value(type, name, rel_opts, data, opts, module) do
    on_error = rel_opts[:on_error]
    on_missing = rel_opts[:on_missing]

    try do
      value =
        cond do
          compute = rel_opts[:compute] ->
            computed_data = apply(module, compute, [data, opts])
            # Apply serializer to computed association data
            if serializer = rel_opts[:serializer] do
              association_type = if type == :has_one, do: :one, else: :many

              handle_missing_association(
                computed_data,
                serializer,
                opts,
                association_type,
                on_missing,
                name
              )
            else
              computed_data
            end

          polymorphic = rel_opts[:polymorphic] ->
            assoc_data = get_data_value(data, name)
            association_type = if type == :has_one, do: :one, else: :many
            serialize_polymorphic(assoc_data, polymorphic, opts, association_type, module)

          true ->
            assoc_data = get_data_value(data, name)
            association_type = if type == :has_one, do: :one, else: :many

            handle_missing_association(
              assoc_data,
              rel_opts[:serializer],
              opts,
              association_type,
              on_missing,
              name
            )
        end

      {:ok, value}
    rescue
      error ->
        handle_field_error(error, name, on_error, data, opts, module)
    end
  end

  defp handle_missing_association(
         data,
         serializer,
         opts,
         association_type,
         on_missing,
         field_name
       ) do
    case data do
      nil when on_missing == :null ->
        nil

      nil when on_missing == :empty and association_type == :many ->
        []

      %Ecto.Association.NotLoaded{} when on_missing == :null ->
        nil

      %Ecto.Association.NotLoaded{} when on_missing == :empty and association_type == :many ->
        []

      _ ->
        serialize_association(data, serializer, opts, association_type, field_name)
    end
  end

  # Note: The transformation pipeline has been moved to NbSerializer.Pipeline module
  # for better code organization and reusability

  defp get_data_value(data, key) when is_map(data) do
    case data do
      %{^key => value} ->
        value

      %{} ->
        # Use safe key access utility to avoid ArgumentError
        NbSerializer.Utils.safe_key_access(data, key)
    end
  end

  defp get_data_value(data, key) when is_list(data) do
    Keyword.get(data, key)
  end

  defp get_data_value(_data, _key), do: nil

  defp should_include?(data, opts, field_opts, module) do
    if if_condition = field_opts[:if] do
      evaluate_condition(if_condition, data, opts, module)
    else
      true
    end
  end

  defp evaluate_condition(conditions, data, opts, module) when is_list(conditions) do
    Enum.all?(conditions, &evaluate_condition(&1, data, opts, module))
  end

  defp evaluate_condition(condition, data, opts, module) when is_atom(condition) do
    apply(module, condition, [data, opts])
  end

  defp evaluate_condition(_condition, _data, _opts, _module), do: true

  # Check if an association is allowed by the within option
  # Returns {should_serialize, nested_within}
  defp check_within_permission(nil, _field_name), do: {true, nil}

  # Handler for keyword lists (the idiomatic Elixir way)
  defp check_within_permission(within, field_name) when is_list(within) do
    # Empty list means no associations should be serialized
    if within == [] do
      {false, nil}
    else
      # Check if field_name is in the keyword list
      case Keyword.get(within, field_name) do
        # Field not in within, check if it's present as a plain atom
        nil ->
          if field_name in within do
            # Field found as atom, serialize without nested
            {true, []}
          else
            # Field not found, don't serialize
            {false, nil}
          end

        # Field has nested within options (must be a list)
        nested when is_list(nested) ->
          {true, nested}

        # Any other value means serialize but no nested associations
        _ ->
          {true, []}
      end
    end
  end

  defp check_within_permission(_within, _field_name), do: {true, nil}

  defp serialize_association(nil, _serializer, _opts, :one, _field_name), do: nil
  defp serialize_association(nil, _serializer, _opts, :many, _field_name), do: []
  defp serialize_association([], _serializer, _opts, :many, _field_name), do: []

  # Handle Ecto.Association.NotLoaded
  defp serialize_association(
         %Ecto.Association.NotLoaded{},
         _serializer,
         _opts,
         :one,
         _field_name
       ),
       do: nil

  defp serialize_association(
         %Ecto.Association.NotLoaded{},
         _serializer,
         _opts,
         :many,
         _field_name
       ),
       do: []

  defp serialize_association(data, nil, _opts, _cardinality, _field_name), do: data

  defp serialize_association(data, serializer, opts, cardinality, field_name)
       when not is_nil(serializer) do
    # Check within option to control circular references
    within = get_opt(opts, :within, nil)

    # Check if this association should be serialized based on within option
    {should_serialize, nested_within} = check_within_permission(within, field_name)

    if not should_serialize do
      # This association is not in the within path, don't serialize it
      case cardinality do
        :one -> nil
        :many -> []
        _ -> nil
      end
    else
      # Check for max_depth to prevent infinite recursion
      current_depth = get_opt(opts, :_depth, 0)
      max_depth = get_opt(opts, :max_depth, nil) || 10

      if max_depth && current_depth >= max_depth do
        # At max depth, return appropriate empty value for associations to stop recursion
        case cardinality do
          :one -> nil
          :many -> []
          _ -> nil
        end
      else
        # Prepare nested options with updated within and depth
        nested_opts = opts

        nested_opts =
          if max_depth, do: put_opt(nested_opts, :_depth, current_depth + 1), else: nested_opts

        # Update options with nested within configuration
        nested_opts =
          if nested_within != nil do
            put_opt(nested_opts, :within, nested_within)
          else
            nested_opts
          end

        case Utils.handle_nil_or_empty(data, cardinality) do
          nil ->
            nil

          [] ->
            []

          data ->
            case cardinality do
              :one -> serializer.serialize(data, nested_opts)
              :many when is_list(data) -> Enum.map(data, &serializer.serialize(&1, nested_opts))
              _ -> data
            end
        end
      end
    end
  end

  defp serialize_polymorphic(nil, _polymorphic, _opts, :one, _module), do: nil
  defp serialize_polymorphic(nil, _polymorphic, _opts, :many, _module), do: []

  defp serialize_polymorphic(%Ecto.Association.NotLoaded{}, _polymorphic, _opts, :one, _module),
    do: nil

  defp serialize_polymorphic(%Ecto.Association.NotLoaded{}, _polymorphic, _opts, :many, _module),
    do: []

  defp serialize_polymorphic(data, polymorphic, opts, :one, module) do
    # Check max_depth for polymorphic associations too
    current_depth = get_opt(opts, :_depth, 0)
    max_depth = get_opt(opts, :max_depth, nil) || 10

    if max_depth && current_depth >= max_depth do
      nil
    else
      serializer = detect_polymorphic_serializer(data, polymorphic, opts, module)

      if serializer do
        nested_opts =
          if max_depth do
            put_opt(opts, :_depth, current_depth + 1)
          else
            opts
          end

        serializer.serialize(data, nested_opts)
      else
        data
      end
    end
  end

  defp serialize_polymorphic(data, polymorphic, opts, :many, module) when is_list(data) do
    Enum.map(data, fn item ->
      serialize_polymorphic(item, polymorphic, opts, :one, module)
    end)
  end

  defp detect_polymorphic_serializer(data, type_map, _opts, _module) when is_list(type_map) do
    # Find matching serializer based on struct type
    struct_type =
      case data do
        %{__struct__: type} -> type
        _ -> nil
      end

    if struct_type do
      Enum.find_value(type_map, fn
        {^struct_type, serializer} -> serializer
        _ -> nil
      end)
    else
      nil
    end
  end

  defp detect_polymorphic_serializer(data, detector, _opts, _module)
       when is_function(detector, 1) do
    # Use custom detection function
    detector.(data)
  end

  defp detect_polymorphic_serializer(data, detector, opts, module) when is_atom(detector) do
    # Call module function for detection
    apply(module, detector, [data, opts])
  end
end
