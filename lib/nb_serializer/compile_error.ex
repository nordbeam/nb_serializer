defmodule NbSerializer.CompileError do
  @moduledoc """
  Exception raised when a serializer fails to compile due to DSL errors.
  """

  defexception [:message, :module, :field, :function, :arity, :type]

  @impl true
  def exception(opts) when is_list(opts) do
    module = Keyword.fetch!(opts, :module)
    field = Keyword.fetch!(opts, :field)
    function = Keyword.fetch!(opts, :function)
    arity = Keyword.get(opts, :arity, 2)
    type = Keyword.get(opts, :type, :compute)

    message = build_message(module, field, function, arity, type)

    %__MODULE__{
      message: message,
      module: module,
      field: field,
      function: function,
      arity: arity,
      type: type
    }
  end

  defp build_message(module, field, function, arity, :compute) do
    # Get the file path for the module
    file_path = get_module_file_path(module)
    file_hint = if file_path, do: "\n\nAdd this function to #{file_path}", else: ""

    """
    Compute function `#{function}/#{arity}` not defined in #{inspect(module)}

    Field #{inspect(field)} requires a compute function that doesn't exist.

    Expected function signature:

        def #{function}(data, opts) do
          # Compute and return the field value
          # - data: The struct/map being serialized
          # - opts: Options passed to serialize/3
          value
        end
    #{file_hint}

    Or remove the compute option from the field definition:

        field #{inspect(field)}  # Remove: compute: #{inspect(function)}

    Or add error handling to the field definition:

        field #{inspect(field)}, compute: #{inspect(function)}, on_error: :null

    Available on_error options:
    - :null - Return nil on error
    - :skip - Omit the field entirely
    - {:default, value} - Return a default value
    - :reraise - Wrap in NbSerializer.SerializationError

    See: https://hexdocs.pm/nb_serializer/NbSerializer.DSL.html#field/2
    """
  end

  defp build_message(module, field, function, arity, :transform) do
    file_path = get_module_file_path(module)
    file_hint = if file_path, do: "\n\nAdd this function to #{file_path}", else: ""

    """
    Transform function `#{function}/#{arity}` not defined in #{inspect(module)}

    Field #{inspect(field)} requires a transform function that doesn't exist.

    Expected function signature:

        def #{function}(value) do
          # Transform and return the modified value
          transformed_value
        end
    #{file_hint}

    Or remove the transform option from the field definition:

        field #{inspect(field)}  # Remove: transform: #{inspect(function)}

    See: https://hexdocs.pm/nb_serializer/NbSerializer.DSL.html#field/2
    """
  end

  defp get_module_file_path(module) do
    case Code.ensure_loaded(module) do
      {:module, _} ->
        case module.__info__(:compile)[:source] do
          source when is_binary(source) or is_list(source) ->
            to_string(source)

          _ ->
            nil
        end

      _ ->
        nil
    end
  rescue
    _ -> nil
  end
end
