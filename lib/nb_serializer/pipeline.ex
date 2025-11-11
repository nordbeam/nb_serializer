defmodule NbSerializer.Pipeline do
  @moduledoc """
  Field value transformation pipeline.

  Provides a consistent transformation pipeline for field values,
  handling defaults, transformations, and formatting.
  """

  # Type definitions
  @type value :: any()
  @type field_opts :: keyword()
  @type module_ref :: module()

  @doc """
  Transforms a value through the configured pipeline.

  Applies default values, protocol-based transformations, and protocol-based formatting in sequence.

  The pipeline order is:
  1. Apply default value if input is nil
  2. Apply protocol-based transformation (NbSerializer.Transformer)
  3. Apply custom transformation function if specified
  4. Apply protocol-based formatting (NbSerializer.Formatter)
  5. Apply custom formatting function if specified

  ## Options

    * `:default` - Default value if input is nil
    * `:transform` - Function name to transform the value (custom)
    * `:format` - Function name to format the value (custom)
    * `:use_protocol` - Whether to use protocol-based transformation (default: true)

  ## Examples

      NbSerializer.Pipeline.transform(nil, [default: "N/A"], MySerializer)
      # => "N/A"

      NbSerializer.Pipeline.transform("hello", [transform: :upcase], MySerializer)
      # => "HELLO" (if MySerializer.upcase/1 exists)

      # With protocol-based formatting (automatic for DateTime, etc.)
      NbSerializer.Pipeline.transform(~U[2024-01-15 10:30:00Z], [], MySerializer)
      # => "2024-01-15T10:30:00Z"
  """
  @spec transform(value(), field_opts(), module_ref()) :: value()
  def transform(value, field_opts, module) do
    value
    |> handle_default(field_opts[:default])
    |> maybe_protocol_transform(field_opts)
    |> maybe_transform(field_opts[:transform], module)
    |> maybe_protocol_format(field_opts, module)
    |> maybe_format(field_opts[:format], module)
  end

  defp handle_default(nil, default) when not is_nil(default), do: default
  defp handle_default(value, _default), do: value

  # Protocol-based transformation
  # Disabled by default to maintain backwards compatibility
  defp maybe_protocol_transform(value, opts) do
    if Keyword.get(opts, :use_protocol, false) && Code.ensure_loaded?(NbSerializer.Transformer) do
      NbSerializer.Transformer.transform(value, opts)
    else
      value
    end
  end

  # Custom transformation function
  defp maybe_transform(value, nil, _module), do: value

  defp maybe_transform(value, transform, module) when is_atom(transform) do
    apply(module, transform, [value])
  end

  # Protocol-based formatting
  # Disabled by default to maintain backwards compatibility
  # Only apply if there's no custom formatter specified
  defp maybe_protocol_format(value, opts, module) do
    has_custom_format = opts[:format] != nil

    if not has_custom_format &&
         Keyword.get(opts, :use_protocol, false) &&
         Code.ensure_loaded?(NbSerializer.Formatter) do
      NbSerializer.Formatter.format(value, opts)
    else
      value
    end
  end

  # Custom formatting function
  defp maybe_format(value, nil, _module), do: value
  defp maybe_format(nil, _format, _module), do: nil

  defp maybe_format(value, format, module) when is_atom(format) do
    # Check if it's a custom format function in the module
    if function_exported?(module, format, 1) do
      apply(module, format, [value])
    else
      # Fallback to built-in formatter from registry (for backwards compatibility)
      if Code.ensure_loaded?(NbSerializer.FormatterRegistry) do
        NbSerializer.FormatterRegistry.apply_formatter(format, value, [])
      else
        value
      end
    end
  end

  defp maybe_format(value, {format, arg}, module) when is_atom(format) do
    # Check if it's a custom format function in the module
    if function_exported?(module, format, 2) do
      apply(module, format, [value, arg])
    else
      # Fallback to built-in formatter with argument (for backwards compatibility)
      if Code.ensure_loaded?(NbSerializer.FormatterRegistry) do
        NbSerializer.FormatterRegistry.apply_formatter(format, value, arg)
      else
        value
      end
    end
  end

  defp maybe_format(value, _format, _module), do: value
end
