defmodule NbSerializer.MixProject do
  use Mix.Project

  def project do
    [
      app: :nb_serializer,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "A fast and simple JSON serializer for Elixir inspired by Alba for Ruby",
      package: package(),
      docs: docs(),
      source_url: "https://github.com/nordbeam/nb_serializer",
      homepage_url: "https://github.com/nordbeam/nb_serializer",
      name: "NbSerializer",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      compilers: Mix.compilers(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {NbSerializer.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4", optional: true},
      {:ecto, "~> 3.10", optional: true},
      {:phoenix, "~> 1.7", optional: true},
      {:plug, "~> 1.14", optional: true},
      {:telemetry, "~> 1.2"},
      {:igniter, "~> 0.6", optional: true},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:benchee, "~> 1.3", only: :dev},
      {:stream_data, "~> 1.0", only: [:test, :dev]}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/nordbeam/nb_serializer",
        "Documentation" => "https://hexdocs.pm/nb_serializer"
      },
      maintainers: ["assim"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "usage-rules.md"
      ],
      groups_for_extras: [
        Guides: ["usage-rules.md"]
      ],
      source_ref: "main",
      formatters: ["html"]
    ]
  end

  defp aliases do
    []
  end
end
