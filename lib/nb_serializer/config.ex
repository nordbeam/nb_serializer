defmodule NbSerializer.Config do
  @moduledoc """
  Configuration for NbSerializer.

  ## Configuration Options

  - `:camelize_props` - Whether to automatically camelize Inertia props (default: `true`)

  ## Example

      # config/config.exs
      config :nb_serializer,
        camelize_props: true
  """

  @doc """
  Gets the configuration value for the given key.

  ## Examples

      iex> NbSerializer.Config.get(:camelize_props)
      true

      iex> NbSerializer.Config.get(:camelize_props, false)
      true
  """
  def get(key, default \\ nil) do
    Application.get_env(:nb_serializer, key, default)
  end

  @doc """
  Returns whether props should be automatically camelized for Inertia.

  Defaults to `true` to match Inertia.js conventions.
  """
  def camelize_props? do
    get(:camelize_props, true)
  end
end
