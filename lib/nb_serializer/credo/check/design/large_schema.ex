# Only compile this module if Credo is available
if Code.ensure_loaded?(Credo.Check) do
  defmodule NbSerializer.Credo.Check.Design.LargeSchema do
    @moduledoc """
    Warns when a serializer schema has too many fields.

    Large schemas can indicate that a serializer is doing too much and should
    be split into smaller, more focused serializers.

    ## Example

    Instead of one large serializer with 50+ fields:

        defmodule MyApp.UserSerializer do
          schema do
            field :id, :number
            field :name, :string
            # ... 48 more fields
          end
        end

    Consider splitting into focused serializers:

        defmodule MyApp.UserSummarySerializer do
          schema do
            field :id, :number
            field :name, :string
          end
        end

        defmodule MyApp.UserDetailSerializer do
          schema do
            has_one :summary, UserSummarySerializer
            field :email, :string
            # ... other detail fields
          end
        end

    ## Configuration

    You can customize the maximum field count:

        {NbSerializer.Credo.Check.Design.LargeSchema, [max_fields: 30]}

    """
    use Credo.Check,
      id: "EX6016",
      base_priority: :low,
      category: :design,
      param_defaults: [
        max_fields: 40
      ],
      explanations: [
        check: """
        Serializer schemas should not have too many fields.

        Large schemas are harder to maintain and may indicate the need for
        composition with nested serializers.

        Consider splitting large serializers into smaller, focused ones:
        - UserSummarySerializer for list views
        - UserDetailSerializer for detail views
        """,
        params: [
          max_fields: "Maximum number of fields before warning (default: 40)"
        ]
      ]

    @doc false
    @impl true
    def run(%SourceFile{} = source_file, params) do
      max_fields = Params.get(params, :max_fields, __MODULE__)
      issue_meta = IssueMeta.for(source_file, params)

      initial_state = %{
        issue_meta: issue_meta,
        issues: [],
        max_fields: max_fields,
        current_module: nil,
        module_line: nil,
        has_serializer_use: false,
        field_count: 0
      }

      final_state = Credo.Code.prewalk(source_file, &traverse(&1, &2), initial_state)

      check_large_schema(final_state)
    end

    # Track module definition
    defp traverse({:defmodule, meta, [{:__aliases__, _, parts} | _]} = ast, state) do
      state = maybe_add_issues_for_previous_module(state)

      module_name = Module.concat(parts)

      {ast,
       %{
         state
         | current_module: module_name,
           module_line: meta[:line],
           has_serializer_use: false,
           field_count: 0
       }}
    end

    # Track use NbSerializer.Serializer
    defp traverse(
           {:use, _meta, [{:__aliases__, _, [:NbSerializer, :Serializer]} | _]} = ast,
           state
         ) do
      {ast, %{state | has_serializer_use: true}}
    end

    # Count field declarations
    defp traverse({:field, _meta, [name | _rest]} = ast, state) when is_atom(name) do
      {ast, %{state | field_count: state.field_count + 1}}
    end

    # Count has_one declarations
    defp traverse({:has_one, _meta, [name | _rest]} = ast, state) when is_atom(name) do
      {ast, %{state | field_count: state.field_count + 1}}
    end

    # Count has_many declarations
    defp traverse({:has_many, _meta, [name | _rest]} = ast, state) when is_atom(name) do
      {ast, %{state | field_count: state.field_count + 1}}
    end

    defp traverse(ast, state), do: {ast, state}

    defp maybe_add_issues_for_previous_module(state) do
      if state.has_serializer_use and state.field_count > state.max_fields and
           state.current_module do
        issue =
          issue_for(state.issue_meta, state.module_line, state.current_module, state.field_count)

        %{state | issues: [issue | state.issues]}
      else
        state
      end
    end

    defp check_large_schema(state) do
      issues =
        if state.has_serializer_use and state.field_count > state.max_fields and
             state.current_module do
          [
            issue_for(
              state.issue_meta,
              state.module_line,
              state.current_module,
              state.field_count
            )
            | state.issues
          ]
        else
          state.issues
        end

      Enum.reverse(issues)
    end

    defp issue_for(issue_meta, line_no, module_name, field_count) do
      format_issue(
        issue_meta,
        message:
          "Serializer `#{inspect(module_name)}` has #{field_count} fields. Consider splitting into smaller serializers.",
        trigger: "defmodule",
        line_no: line_no
      )
    end
  end
end
