defmodule NbSerializer.TypeScript do
  @moduledoc """
  DEPRECATED: TypeScript functionality has been moved to the `nb_ts` library.

  This module is now empty and only exists to provide deprecation warnings.

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

  For more information, see: https://github.com/nordbeam/nb_ts
  """

  @deprecated "TypeScript functionality has been moved to the nb_ts library. Please use NbTs instead."
  def generate_types(_opts \\ []) do
    IO.warn("""
    NbSerializer.TypeScript.generate_types/1 is deprecated.

    TypeScript type generation has been moved to the `nb_ts` library.
    Please install `nb_ts` and use `NbTs.generate_types/1` instead.

    See: https://github.com/nordbeam/nb_ts
    """)

    {:error, :deprecated}
  end
end
