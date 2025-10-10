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

  Applies default values, transformations, and formatting in sequence.

  ## Options

    * `:default` - Default value if input is nil
    * `:transform` - Function name to transform the value
    * `:format` - Function name to format the value

  ## Examples

      NbSerializer.Pipeline.transform(nil, [default: "N/A"], MySerializer)
      # => "N/A"

      NbSerializer.Pipeline.transform("hello", [transform: :upcase], MySerializer)
      # => "HELLO" (if MySerializer.upcase/1 exists)
  """
  @spec transform(value(), field_opts(), module_ref()) :: value()
  def transform(value, field_opts, module) do
    value
    |> handle_default(field_opts[:default])
    |> maybe_transform(field_opts[:transform], module)
    |> maybe_format(field_opts[:format], module)
  end

  defp handle_default(nil, default) when not is_nil(default), do: default
  defp handle_default(value, _default), do: value

  defp maybe_transform(value, nil, _module), do: value

  defp maybe_transform(value, transform, module) when is_atom(transform) do
    apply(module, transform, [value])
  end

  defp maybe_format(value, nil, _module), do: value
  defp maybe_format(nil, _format, _module), do: nil

  defp maybe_format(value, format, module) when is_atom(format) do
    # Check if it's a custom format function in the module
    if function_exported?(module, format, 1) do
      apply(module, format, [value])
    else
      # Use built-in formatter from registry
      NbSerializer.FormatterRegistry.apply_formatter(format, value, [])
    end
  end

  defp maybe_format(value, {format, arg}, module) when is_atom(format) do
    # Check if it's a custom format function in the module
    if function_exported?(module, format, 2) do
      apply(module, format, [value, arg])
    else
      # Use built-in formatter with argument
      NbSerializer.FormatterRegistry.apply_formatter(format, value, arg)
    end
  end

  defp maybe_format(value, _format, _module), do: value
end
