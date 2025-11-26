# Only compile this module if Credo is available
if Code.ensure_loaded?(Credo.Check) do
  defmodule NbSerializer.Credo.Check.Readability.MissingModuledoc do
    @moduledoc """
    Warns when serializer modules don't have a @moduledoc.

    Serializers should be documented to explain what data they serialize
    and any important behavior or options.

    ## Example

    Instead of:

        defmodule MyApp.UserSerializer do
          use NbSerializer.Serializer

          schema do
            field :id, :number
          end
        end

    Use:

        defmodule MyApp.UserSerializer do
          @moduledoc \"\"\"
          Serializes user data for API responses.

          Includes basic user information suitable for list views.
          \"\"\"
          use NbSerializer.Serializer

          schema do
            field :id, :number
          end
        end

    """
    use Credo.Check,
      id: "EX6015",
      base_priority: :low,
      category: :readability,
      explanations: [
        check: """
        Serializer modules should have @moduledoc documentation.

        Good documentation explains:
        - What data the serializer handles
        - When to use this serializer vs others
        - Any computed fields or special behavior
        """
      ]

    @doc false
    @impl true
    def run(%SourceFile{} = source_file, params) do
      issue_meta = IssueMeta.for(source_file, params)

      initial_state = %{
        issue_meta: issue_meta,
        issues: [],
        current_module: nil,
        module_line: nil,
        has_serializer_use: false,
        has_moduledoc: false
      }

      final_state = Credo.Code.prewalk(source_file, &traverse(&1, &2), initial_state)

      check_missing_moduledoc(final_state)
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
           has_moduledoc: false
       }}
    end

    # Track use NbSerializer.Serializer
    defp traverse(
           {:use, _meta, [{:__aliases__, _, [:NbSerializer, :Serializer]} | _]} = ast,
           state
         ) do
      {ast, %{state | has_serializer_use: true}}
    end

    # Track @moduledoc
    defp traverse({:@, _meta, [{:moduledoc, _, [doc]}]} = ast, state)
         when doc != false do
      {ast, %{state | has_moduledoc: true}}
    end

    defp traverse(ast, state), do: {ast, state}

    defp maybe_add_issues_for_previous_module(state) do
      if state.has_serializer_use and not state.has_moduledoc and state.current_module do
        issue = issue_for(state.issue_meta, state.module_line, state.current_module)
        %{state | issues: [issue | state.issues]}
      else
        state
      end
    end

    defp check_missing_moduledoc(state) do
      issues =
        if state.has_serializer_use and not state.has_moduledoc and state.current_module do
          [issue_for(state.issue_meta, state.module_line, state.current_module) | state.issues]
        else
          state.issues
        end

      Enum.reverse(issues)
    end

    defp issue_for(issue_meta, line_no, module_name) do
      format_issue(
        issue_meta,
        message: "Serializer `#{inspect(module_name)}` is missing @moduledoc documentation.",
        trigger: "defmodule",
        line_no: line_no
      )
    end
  end
end
