# Only compile this module if Credo is available
if Code.ensure_loaded?(Credo.Check) do
  defmodule NbSerializer.Credo.Check.Warning.GenericMapType do
    @moduledoc """
    Warns when using `:map` as a field type instead of a proper serializer
    in NbSerializer schemas.

    This check only applies to modules that use `NbSerializer.Serializer`.
    Ecto schemas and other modules are not affected (`:map` is valid for JSONB columns).

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

        Note: This check only applies to NbSerializer schemas, not Ecto schemas.
        """
      ]

    @doc false
    @impl true
    def run(%SourceFile{} = source_file, params) do
      issue_meta = IssueMeta.for(source_file, params)

      initial_state = %{
        issue_meta: issue_meta,
        issues: [],
        uses_nb_serializer: false
      }

      final_state = Credo.Code.prewalk(source_file, &traverse(&1, &2), initial_state)

      # Only return issues if this is an NbSerializer module
      if final_state.uses_nb_serializer do
        Enum.reverse(final_state.issues)
      else
        []
      end
    end

    # Track use NbSerializer.Serializer
    defp traverse({:use, _, [{:__aliases__, _, [:NbSerializer, :Serializer]} | _]} = ast, state) do
      {ast, %{state | uses_nb_serializer: true}}
    end

    # Match field :name, :map
    defp traverse({:field, meta, [field_name, :map | _rest]} = ast, state)
         when is_atom(field_name) do
      new_issue = issue_for(state.issue_meta, meta[:line], field_name)
      {ast, %{state | issues: [new_issue | state.issues]}}
    end

    defp traverse(ast, state), do: {ast, state}

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
