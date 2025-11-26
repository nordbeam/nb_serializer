# Only compile this module if Credo is available
if Code.ensure_loaded?(Credo.Check) do
  defmodule NbSerializer.Credo.Check.Warning.InvalidNestedSerializerType do
    @moduledoc """
    Warns when a serializer module is used directly as a field type instead of
    using `has_one`, `has_many`, or the `serializer:` option.

    ## Example

    Instead of:

        schema do
          field :config, WidgetConfigSerializer  # Wrong!
        end

    Use:

        schema do
          has_one :config, WidgetConfigSerializer
          # or
          field :config, serializer: WidgetConfigSerializer
        end

    Using a serializer module directly as a field type will cause runtime errors
    since the module is not a valid primitive type.

    """
    use Credo.Check,
      id: "EX6010",
      base_priority: :high,
      category: :warning,
      explanations: [
        check: """
        Serializer modules should not be used directly as field types.

        Use `has_one`, `has_many`, or the `serializer:` option instead:

            has_one :config, WidgetConfigSerializer
            # or
            field :config, serializer: WidgetConfigSerializer

        Using a module directly as a type will fail at runtime.
        """
      ]

    @doc false
    @impl true
    def run(%SourceFile{} = source_file, params) do
      issue_meta = IssueMeta.for(source_file, params)

      source_file
      |> Credo.Code.prewalk(&traverse(&1, &2, issue_meta))
      |> Enum.reverse()
    end

    # Match field declarations with module alias as type
    # field :name, SomeSerializer
    defp traverse(
           {:field, meta, [field_name, {:__aliases__, _, parts} | _rest]} = ast,
           issues,
           issue_meta
         )
         when is_atom(field_name) do
      module_name = Module.concat(parts)
      module_string = to_string(module_name)

      if String.ends_with?(module_string, "Serializer") do
        new_issue = issue_for(issue_meta, meta[:line], field_name, module_name)
        {ast, [new_issue | issues]}
      else
        {ast, issues}
      end
    end

    defp traverse(ast, issues, _issue_meta), do: {ast, issues}

    defp issue_for(issue_meta, line_no, field_name, module_name) do
      format_issue(
        issue_meta,
        message:
          "Field `:#{field_name}` uses serializer `#{inspect(module_name)}` directly as type. Use `has_one :#{field_name}, #{inspect(module_name)}` or `field :#{field_name}, serializer: #{inspect(module_name)}` instead.",
        trigger: "field",
        line_no: line_no
      )
    end
  end
end
