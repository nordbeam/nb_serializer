# Only compile this module if Credo is available
if Code.ensure_loaded?(Credo.Check) do
  defmodule NbSerializer.Credo.Check.Warning.InconsistentNumericTypes do
    @moduledoc """
    Warns when using `:integer` or `:float` instead of `:number` for numeric fields.

    For consistency and TypeScript type generation, NbSerializer recommends using
    `:number` as the standard numeric type. This maps to TypeScript's `number` type.

    ## Example

    Instead of:

        field :total_views, :integer
        field :average_rating, :float

    Use:

        field :total_views, :number
        field :average_rating, :number

    The `:number` type is the standard for all numeric values in NbSerializer.

    """
    use Credo.Check,
      id: "EX6012",
      base_priority: :normal,
      category: :warning,
      explanations: [
        check: """
        Use `:number` instead of `:integer` or `:float` for numeric fields.

        This ensures:
        - Consistent TypeScript type generation (`number`)
        - Uniform handling across the codebase
        - Proper JSON serialization

            field :count, :number
            field :rate, :number
        """
      ]

    @inconsistent_types [:integer, :float]

    @doc false
    @impl true
    def run(%SourceFile{} = source_file, params) do
      issue_meta = IssueMeta.for(source_file, params)

      source_file
      |> Credo.Code.prewalk(&traverse(&1, &2, issue_meta))
      |> Enum.reverse()
    end

    # Match field :name, :integer or field :name, :float
    defp traverse({:field, meta, [field_name, type | _rest]} = ast, issues, issue_meta)
         when is_atom(field_name) and type in @inconsistent_types do
      new_issue = issue_for(issue_meta, meta[:line], field_name, type)
      {ast, [new_issue | issues]}
    end

    defp traverse(ast, issues, _issue_meta), do: {ast, issues}

    defp issue_for(issue_meta, line_no, field_name, type) do
      format_issue(
        issue_meta,
        message:
          "Field `:#{field_name}` uses `:#{type}`. Consider using `:number` for consistency.",
        trigger: "field",
        line_no: line_no
      )
    end
  end
end
