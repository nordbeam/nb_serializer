defmodule NbSerializer.Inertia do
  @moduledoc """
  DEPRECATED: Inertia.js integration has been moved to the `nb_inertia` library.

  This module is now empty and only exists to provide deprecation warnings.

  ## Migration

  Please install and use the `nb_inertia` library instead:

  ```elixir
  # mix.exs
  def deps do
    [
      {:nb_inertia, "~> 0.1.0"}
    ]
  end
  ```

  For more information, see: https://github.com/nordbeam/nb_inertia
  """

  @deprecated "Inertia.js integration has been moved to the nb_inertia library. Please use NbInertia instead."
  def render_inertia(_conn, _component, _props \\ []) do
    IO.warn("""
    NbSerializer.Inertia.render_inertia/3 is deprecated.

    Inertia.js integration has been moved to the `nb_inertia` library.
    Please install `nb_inertia` and use `NbInertia.render_inertia/3` instead.

    See: https://github.com/nordbeam/nb_inertia
    """)

    raise "NbSerializer.Inertia has been deprecated. Use nb_inertia library instead."
  end

  @deprecated "Inertia.js integration has been moved to the nb_inertia library. Please use NbInertia instead."
  def assign_serialized(_conn, _key, _serializer, _data, _opts \\ []) do
    IO.warn("""
    NbSerializer.Inertia.assign_serialized/5 is deprecated.

    Inertia.js integration has been moved to the `nb_inertia` library.
    Please install `nb_inertia` and use `NbInertia.assign_serialized/5` instead.

    See: https://github.com/nordbeam/nb_inertia
    """)

    raise "NbSerializer.Inertia has been deprecated. Use nb_inertia library instead."
  end

  @deprecated "Inertia.js integration has been moved to the nb_inertia library. Please use NbInertia instead."
  def render_inertia_serialized(_conn, _component, _props) do
    IO.warn("""
    NbSerializer.Inertia.render_inertia_serialized/3 is deprecated.

    Inertia.js integration has been moved to the `nb_inertia` library.
    Please install `nb_inertia` and use `NbInertia.render_inertia_serialized/3` instead.

    See: https://github.com/nordbeam/nb_inertia
    """)

    raise "NbSerializer.Inertia has been deprecated. Use nb_inertia library instead."
  end
end
