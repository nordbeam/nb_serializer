defmodule Mix.Tasks.NbSerializer.Gen.Types do
  @shortdoc "DEPRECATED: Use nb_ts library instead"
  @moduledoc """
  DEPRECATED: TypeScript type generation has been moved to the `nb_ts` library.

  This Mix task is now empty and only exists to provide deprecation warnings.

  ## Migration

  Please install and use the `nb_ts` library instead:

  ```elixir
  # mix.exs
  def deps do
    [
      {:nb_ts, "~> 0.1.0"}
    ]
  end
  ```

  Then use the new Mix task:

  ```bash
  mix nb_ts.gen.types
  ```

  For more information, see: https://github.com/nordbeam/nb_ts
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.shell().error("""

    ================================================================================
    DEPRECATED: mix nb_serializer.gen.types
    ================================================================================

    TypeScript type generation has been moved to the `nb_ts` library.

    Please install `nb_ts` and use `mix nb_ts.gen.types` instead:

      # In mix.exs
      def deps do
        [
          {:nb_ts, "~> 0.1.0"}
        ]
      end

      # Run mix deps.get
      mix deps.get

      # Use the new task
      mix nb_ts.gen.types

    For more information, see: https://github.com/nordbeam/nb_ts
    ================================================================================
    """)

    Mix.raise("Task deprecated. Use nb_ts library instead.")
  end
end
