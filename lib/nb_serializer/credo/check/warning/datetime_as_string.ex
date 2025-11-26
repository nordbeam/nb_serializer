# Only compile this module if Credo is available
if Code.ensure_loaded?(Credo.Check) do
  defmodule NbSerializer.Credo.Check.Warning.DatetimeAsString do
    @moduledoc """
    Warns when fields that appear to be datetime fields are declared as `:string`.

    Fields with names ending in `_at`, `_date`, or `_time` should typically use
    `:datetime` type with proper formatting instead of `:string`.

    ## Example

    Instead of:

        field :created_at, :string
        field :joined_at, :string

    Use:

        field :created_at, :datetime, format: :iso8601
        field :joined_at, :datetime, format: :iso8601

    Using `:datetime` ensures proper type safety and consistent serialization.

    """
    use Credo.Check,
      id: "EX6013",
      base_priority: :normal,
      category: :warning,
      explanations: [
        check: """
        Fields with datetime-like names should use `:datetime` type.

        Names ending in `_at`, `_date`, or `_time` typically represent timestamps
        and should be declared as:

            field :created_at, :datetime, format: :iso8601
        """
      ]

    @datetime_suffixes ["_at", "_date", "_time"]

    @doc false
    @impl true
    def run(%SourceFile{} = source_file, params) do
      issue_meta = IssueMeta.for(source_file, params)

      source_file
      |> Credo.Code.prewalk(&traverse(&1, &2, issue_meta))
      |> Enum.reverse()
    end

    # Match field :something_at, :string
    defp traverse({:field, meta, [field_name, :string | _rest]} = ast, issues, issue_meta)
         when is_atom(field_name) do
      field_string = to_string(field_name)

      if looks_like_datetime?(field_string) do
        new_issue = issue_for(issue_meta, meta[:line], field_name)
        {ast, [new_issue | issues]}
      else
        {ast, issues}
      end
    end

    defp traverse(ast, issues, _issue_meta), do: {ast, issues}

    defp looks_like_datetime?(field_name) do
      Enum.any?(@datetime_suffixes, &String.ends_with?(field_name, &1))
    end

    defp issue_for(issue_meta, line_no, field_name) do
      format_issue(
        issue_meta,
        message:
          "Field `:#{field_name}` looks like a datetime but is declared as `:string`. Consider using `:datetime, format: :iso8601`.",
        trigger: "field",
        line_no: line_no
      )
    end
  end
end
