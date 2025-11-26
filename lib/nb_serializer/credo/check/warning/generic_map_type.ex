# Only compile this module if Credo is available
if Code.ensure_loaded?(Credo.Check) do
  defmodule NbSerializer.Credo.Check.Warning.GenericMapType do
    @moduledoc """
    Warns when using `:map` as a field type instead of a proper serializer.

    The `:map` type loses all structure information and prevents TypeScript
    type generation. Complex nested data should use dedicated serializers
    for type safety and consistent formatting.

    ## Example

    Instead of:

        schema do
          field :config, :map
          field :metadata, :map
        end

    Use:

        schema do
          field :config, serializer: ConfigSerializer
          # or
          has_one :config, ConfigSerializer
        end

    If the map structure is truly dynamic, consider using a custom TypeScript
    type annotation:

        field :metadata, type: ~TS"Record<string, unknown>"

    """
    use Credo.Check,
      id: "EX6018",
      base_priority: :normal,
      category: :warning,
      explanations: [
        check: """
        Avoid using `:map` as a field type. It loses structure information
        and prevents proper TypeScript type generation.

        Use a dedicated serializer instead:

            field :config, serializer: ConfigSerializer
            # or
            has_one :config, ConfigSerializer

        For truly dynamic maps, use an explicit TypeScript type:

            field :metadata, type: ~TS"Record<string, unknown>"
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

    # Match field :name, :map
    defp traverse({:field, meta, [field_name, :map | _rest]} = ast, issues, issue_meta)
         when is_atom(field_name) do
      new_issue = issue_for(issue_meta, meta[:line], field_name)
      {ast, [new_issue | issues]}
    end

    defp traverse(ast, issues, _issue_meta), do: {ast, issues}

    defp issue_for(issue_meta, line_no, field_name) do
      format_issue(
        issue_meta,
        message:
          "Field `:#{field_name}` uses `:map` type. Consider using a serializer for type safety: `field :#{field_name}, serializer: #{suggest_serializer_name(field_name)}`.",
        trigger: "field",
        line_no: line_no
      )
    end

    defp suggest_serializer_name(field_name) do
      field_name
      |> to_string()
      |> Macro.camelize()
      |> Kernel.<>("Serializer")
    end
  end
end
