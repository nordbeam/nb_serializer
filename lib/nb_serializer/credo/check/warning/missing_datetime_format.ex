# Only compile this module if Credo is available
if Code.ensure_loaded?(Credo.Check) do
  defmodule NbSerializer.Credo.Check.Warning.MissingDatetimeFormat do
    @moduledoc """
    Warns when `:datetime` fields don't specify a format option.

    Datetime fields should explicitly declare their serialization format
    to ensure consistent output across the application.

    ## Example

    Instead of:

        field :created_at, :datetime

    Use:

        field :created_at, :datetime, format: :iso8601

    Explicit formats prevent unexpected serialization behavior.

    """
    use Credo.Check,
      id: "EX6014",
      base_priority: :normal,
      category: :warning,
      explanations: [
        check: """
        Datetime fields should specify a format for consistent serialization.

        Add `format: :iso8601` to datetime fields:

            field :created_at, :datetime, format: :iso8601

        This ensures the datetime is serialized consistently as an ISO 8601 string.
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

    # Match field :name, :datetime without format option
    defp traverse({:field, meta, [field_name, :datetime]} = ast, issues, issue_meta)
         when is_atom(field_name) do
      new_issue = issue_for(issue_meta, meta[:line], field_name)
      {ast, [new_issue | issues]}
    end

    # Match field :name, :datetime, opts without format
    defp traverse({:field, meta, [field_name, :datetime, opts | _rest]} = ast, issues, issue_meta)
         when is_atom(field_name) and is_list(opts) do
      if Keyword.has_key?(opts, :format) do
        {ast, issues}
      else
        new_issue = issue_for(issue_meta, meta[:line], field_name)
        {ast, [new_issue | issues]}
      end
    end

    defp traverse(ast, issues, _issue_meta), do: {ast, issues}

    defp issue_for(issue_meta, line_no, field_name) do
      format_issue(
        issue_meta,
        message:
          "Field `:#{field_name}` is `:datetime` without a format. Add `format: :iso8601` for consistent serialization.",
        trigger: "field",
        line_no: line_no
      )
    end
  end
end
