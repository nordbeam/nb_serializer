# Only compile this module if Credo is available
if Code.ensure_loaded?(Credo.Check) do
  defmodule NbSerializer.Credo.Check.Warning.OptionalVsNullable do
    @moduledoc """
    Warns when using `optional: true` instead of `nullable: true` in field declarations.

    In NbSerializer, `nullable: true` is the correct option to indicate a field
    can be null. Using `optional: true` may not work as expected and creates
    inconsistency in the codebase.

    ## Example

    Instead of:

        field :visitor_id, :string, optional: true

    Use:

        field :visitor_id, :string, nullable: true

    """
    use Credo.Check,
      id: "EX6011",
      base_priority: :high,
      category: :warning,
      explanations: [
        check: """
        Use `nullable: true` instead of `optional: true` for fields that can be null.

        The `nullable:` option is the standard way to indicate nullable fields in
        NbSerializer and ensures proper TypeScript type generation.

            field :name, :string, nullable: true
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

    # Match field declarations with optional: true
    defp traverse({:field, meta, [field_name, _type, opts | _rest]} = ast, issues, issue_meta)
         when is_atom(field_name) and is_list(opts) do
      if Keyword.get(opts, :optional) == true do
        new_issue = issue_for(issue_meta, meta[:line], field_name)
        {ast, [new_issue | issues]}
      else
        {ast, issues}
      end
    end

    defp traverse(ast, issues, _issue_meta), do: {ast, issues}

    defp issue_for(issue_meta, line_no, field_name) do
      format_issue(
        issue_meta,
        message:
          "Field `:#{field_name}` uses `optional: true`. Use `nullable: true` instead for nullable fields.",
        trigger: "field",
        line_no: line_no
      )
    end
  end
end
