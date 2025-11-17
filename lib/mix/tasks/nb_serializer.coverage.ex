defmodule Mix.Tasks.NbSerializer.Coverage do
  @shortdoc "Reports coverage of NbSerializer serializers and TypeScript generation"

  @moduledoc """
  Reports coverage statistics for NbSerializer serializers and TypeScript type generation.

  ## Usage

      mix nb_serializer.coverage

  ## Options

    * `--output-dir` - Output directory for TypeScript files (default: assets/js/types)
    * `--verbose` - Show detailed output including serializer names

  ## Example

      mix nb_serializer.coverage --output-dir assets/types --verbose

  This task will:
  1. Discover all NbSerializer serializers in your application
  2. Count TypeScript files generated
  3. Show coverage statistics
  4. Provide recommendations for improving type safety
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          output_dir: :string,
          verbose: :boolean
        ],
        aliases: [
          o: :output_dir,
          v: :verbose
        ]
      )

    output_dir = Keyword.get(opts, :output_dir, "assets/js/types")
    verbose? = Keyword.get(opts, :verbose, false)

    Mix.Task.run("compile")

    # Start nb_serializer but not the host application
    {:ok, _} = Application.ensure_all_started(:nb_serializer)

    # Load the host application modules without starting it
    app = Mix.Project.config()[:app]

    if app do
      Application.load(app)
    end

    # Discover serializers
    serializers = discover_serializers()
    total_serializers = length(serializers)

    # Count TypeScript files
    {ts_files, ts_count} = count_typescript_files(output_dir, serializers)

    # Calculate coverage
    coverage_pct = calculate_coverage(total_serializers, ts_count)

    # Generate and print report
    print_report(%{
      total_serializers: total_serializers,
      serializers: serializers,
      ts_count: ts_count,
      ts_files: ts_files,
      coverage_pct: coverage_pct,
      verbose: verbose?
    })
  end

  defp discover_serializers do
    # First try the registry if it's running (moved to nb_ts library)
    registered =
      if Process.whereis(NbTs.Registry) do
        apply(NbTs.Registry, :all_serializers, [])
      else
        []
      end

    if registered == [] do
      # Fallback: scan all available modules
      find_all_serializers()
    else
      registered
    end
  end

  defp find_all_serializers do
    # Get the application name
    app = Mix.Project.config()[:app]

    # Get all beam files from the application
    app_modules =
      if app do
        case :application.get_key(app, :modules) do
          {:ok, modules} -> modules
          _ -> []
        end
      else
        []
      end

    # Also check loaded modules
    loaded_modules = :code.all_loaded() |> Enum.map(&elem(&1, 0))

    # Combine and filter for serializers
    (app_modules ++ loaded_modules)
    |> Enum.uniq()
    |> Enum.filter(fn module ->
      Code.ensure_loaded?(module) &&
        function_exported?(module, :__nb_serializer_serialize__, 2) &&
        function_exported?(module, :__nb_serializer_type_metadata__, 0)
    end)
  end

  defp count_typescript_files(output_dir, serializers) do
    if File.dir?(output_dir) do
      {:ok, files} = File.ls(output_dir)

      # Get TypeScript files (excluding index.ts)
      ts_files =
        files
        |> Enum.filter(&String.ends_with?(&1, ".ts"))
        |> Enum.reject(&(&1 == "index.ts"))

      # Match TypeScript files to serializers
      serializer_names =
        MapSet.new(serializers, fn serializer ->
          serializer
          |> Module.split()
          |> List.last()
          |> String.replace(~r/Serializer$/, "")
        end)

      # Count how many serializers have corresponding TS files
      matched_count =
        ts_files
        |> Enum.map(&String.replace(&1, ".ts", ""))
        |> Enum.count(&MapSet.member?(serializer_names, &1))

      {ts_files, matched_count}
    else
      {[], 0}
    end
  end

  defp calculate_coverage(0, _), do: 0.0

  defp calculate_coverage(total, ts_count) when ts_count > 0 do
    (ts_count / total * 100) |> Float.round(0) |> trunc()
  end

  defp calculate_coverage(_, _), do: 0

  defp print_report(data) do
    Mix.shell().info("")
    Mix.shell().info("NbSerializer Type Coverage Report")
    Mix.shell().info("═══════════════════════════════════════════════════════════")
    Mix.shell().info("")

    print_serializers_section(data)
    print_recommendations_section(data)
    print_coverage_summary(data)

    Mix.shell().info("")
  end

  defp print_serializers_section(data) do
    Mix.shell().info("Serializers")
    Mix.shell().info("───────────────────────────────────────────────────────────")

    total = data.total_serializers
    with_ts = data.ts_count
    without_ts = total - with_ts

    Mix.shell().info("Total: #{total} serializers found")

    if total > 0 do
      Mix.shell().info("  - #{with_ts} with TypeScript generation")
      Mix.shell().info("  - #{without_ts} without TypeScript generation")
    end

    if data.verbose do
      print_serializer_list(data.serializers, data.ts_files)
    end

    Mix.shell().info("")
  end

  defp print_serializer_list(serializers, ts_files) do
    Mix.shell().info("")
    Mix.shell().info("Found serializers:")

    ts_names =
      MapSet.new(ts_files, fn file ->
        String.replace(file, ".ts", "")
      end)

    serializers
    |> Enum.sort_by(&Module.split(&1))
    |> Enum.each(fn serializer ->
      name =
        serializer
        |> Module.split()
        |> List.last()
        |> String.replace(~r/Serializer$/, "")

      indicator = if MapSet.member?(ts_names, name), do: "✓", else: "✗"
      Mix.shell().info("  #{indicator} #{inspect(serializer)}")
    end)
  end

  defp print_recommendations_section(data) do
    Mix.shell().info("Recommendations")
    Mix.shell().info("───────────────────────────────────────────────────────────")

    cond do
      data.total_serializers == 0 ->
        Mix.shell().info("→ No serializers found in the project")
        Mix.shell().info("→ Create serializers using `use NbSerializer.Serializer`")

      data.coverage_pct == 100 ->
        Mix.shell().info("→ Excellent! All serializers have TypeScript generation")
        Mix.shell().info("→ Run `mix nb_serializer.gen.types` after making changes")

      data.coverage_pct > 0 ->
        missing = data.total_serializers - data.ts_count
        Mix.shell().info("→ Enable TypeScript generation for #{missing} serializers")
        Mix.shell().info("→ Run `mix nb_serializer.gen.types` to update types")

      true ->
        Mix.shell().info("→ No TypeScript files found")
        Mix.shell().info("→ Run `mix nb_serializer.gen.types` to generate types")
    end

    Mix.shell().info("")
  end

  defp print_coverage_summary(data) do
    coverage = data.coverage_pct
    indicator = coverage_indicator(coverage)

    Mix.shell().info("Overall Coverage: #{indicator} #{coverage}%")
  end

  defp coverage_indicator(coverage) when coverage == 100, do: "✓"
  defp coverage_indicator(coverage) when coverage >= 80, do: "⚠"
  defp coverage_indicator(_), do: "✗"
end
