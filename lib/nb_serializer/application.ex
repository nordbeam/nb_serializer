defmodule NbSerializer.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children =
      if typelizer_enabled?() do
        [{NbSerializer.Typelizer.Registry, []}]
      else
        []
      end

    opts = [strategy: :one_for_one, name: NbSerializer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp typelizer_enabled? do
    Mix.env() in [:dev, :test] &&
      Application.get_env(:nb_serializer, :typelizer_enabled, false)
  end
end
