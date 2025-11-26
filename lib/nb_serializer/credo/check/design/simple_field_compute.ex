# Only compile this module if Credo is available
if Code.ensure_loaded?(Credo.Check) do
  defmodule NbSerializer.Credo.Check.Design.SimpleFieldCompute do
    @moduledoc """
    Warns when a compute function simply copies a field value, which should
    use the `from:` option instead.

    ## Example

    Instead of:

        field :total, :number, compute: :compute_total

        def compute_total(pagination, _opts), do: pagination.total_entries

    Use:

        field :total, :number, from: :total_entries

    The `from:` option is simpler, more efficient, and clearer in intent.

    """
    use Credo.Check,
      id: "EX6017",
      base_priority: :low,
      category: :design,
      explanations: [
        check: """
        Use `from:` instead of `compute:` when simply renaming a field.

        The `from:` option is more efficient and clearer:

            # Instead of compute function that copies a field:
            field :total, :number, compute: :compute_total
            def compute_total(data, _), do: data.total_entries

            # Use from: for simple field renaming:
            field :total, :number, from: :total_entries
        """
      ]

    @doc false
    @impl true
    def run(%SourceFile{} = source_file, params) do
      issue_meta = IssueMeta.for(source_file, params)

      initial_state = %{
        issue_meta: issue_meta,
        issues: [],
        compute_fields: %{},
        simple_computes: []
      }

      final_state = Credo.Code.prewalk(source_file, &traverse(&1, &2), initial_state)

      # Cross-reference compute fields with simple compute functions
      find_simple_compute_issues(final_state)
    end

    # Track field declarations with compute option
    defp traverse({:field, meta, [field_name, _type, opts | _rest]} = ast, state)
         when is_atom(field_name) and is_list(opts) do
      case Keyword.get(opts, :compute) do
        nil ->
          {ast, state}

        compute_fn when is_atom(compute_fn) ->
          new_computes = Map.put(state.compute_fields, compute_fn, {field_name, meta[:line]})
          {ast, %{state | compute_fields: new_computes}}

        _ ->
          {ast, state}
      end
    end

    # Detect simple compute functions: def compute_xxx(data, _opts), do: data.field
    defp traverse(
           {:def, _meta,
            [
              {func_name, _, [{var_name, _, var_ctx}, {_, _, _}]},
              [do: {{:., _, [{var_name2, _, var_ctx2}, _source_field]}, _, []}]
            ]} = ast,
           state
         )
         when is_atom(func_name) and var_name == var_name2 and var_ctx == var_ctx2 do
      {ast, %{state | simple_computes: [func_name | state.simple_computes]}}
    end

    defp traverse(ast, state), do: {ast, state}

    defp find_simple_compute_issues(state) do
      issues =
        Enum.flat_map(state.simple_computes, fn compute_fn ->
          case Map.get(state.compute_fields, compute_fn) do
            {field_name, line_no} ->
              [issue_for(state.issue_meta, line_no, field_name, compute_fn)]

            nil ->
              []
          end
        end)

      Enum.reverse(issues)
    end

    defp issue_for(issue_meta, line_no, field_name, compute_fn) do
      format_issue(
        issue_meta,
        message:
          "Field `:#{field_name}` uses `compute: :#{compute_fn}` to copy a field. Consider using `from: :source_field` instead.",
        trigger: "field",
        line_no: line_no
      )
    end
  end
end
