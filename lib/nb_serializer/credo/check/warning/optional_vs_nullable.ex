# Only compile this module if Credo is available
if Code.ensure_loaded?(Credo.Check) do
  defmodule NbSerializer.Credo.Check.Warning.OptionalVsNullable do
    @moduledoc """
    Warns when using `optional: true` instead of `nullable: true` in serializer schema fields.

    In NbSerializer, `nullable: true` is the correct option to indicate a field
    can be null. Using `optional: true` may not work as expected and creates
    inconsistency in the codebase.

    This check only applies to fields inside `schema do` blocks in serializers,
    NOT to `form_inputs`, `inertia_page`, or other contexts where `optional: true`
    is valid.

    ## Example

    Instead of:

        schema do
          field :visitor_id, :string, optional: true
        end

    Use:

        schema do
          field :visitor_id, :string, nullable: true
        end

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

            schema do
              field :name, :string, nullable: true
            end

        Note: This check only applies to serializer `schema` blocks, not to
        `form_inputs`, `inertia_page`, or other contexts.
        """
      ]

    @doc false
    @impl true
    def run(%SourceFile{} = source_file, params) do
      issue_meta = IssueMeta.for(source_file, params)

      initial_state = %{
        issue_meta: issue_meta,
        issues: [],
        in_schema_block: false
      }

      final_state = Credo.Code.prewalk(source_file, &traverse(&1, &2), initial_state)

      Enum.reverse(final_state.issues)
    end

    # Enter schema block
    defp traverse({:schema, _meta, [[do: _block]]} = ast, state) do
      {ast, %{state | in_schema_block: true}}
    end

    defp traverse({:schema, _meta, [_opts, [do: _block]]} = ast, state) do
      {ast, %{state | in_schema_block: true}}
    end

    # Match field declarations with optional: true ONLY inside schema blocks
    defp traverse({:field, meta, [field_name, _type, opts | _rest]} = ast, state)
         when is_atom(field_name) and is_list(opts) do
      if state.in_schema_block and Keyword.get(opts, :optional) == true do
        new_issue = issue_for(state.issue_meta, meta[:line], field_name)
        {ast, %{state | issues: [new_issue | state.issues]}}
      else
        {ast, state}
      end
    end

    defp traverse(ast, state), do: {ast, state}

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
