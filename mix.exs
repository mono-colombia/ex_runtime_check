defmodule RuntimeCheck.MixProject do
  use Mix.Project

  @source_url "https://github.com/mono-colombia/ex_runtime_check"
  @version "0.1.0"

  def project do
    [
      app: :runtime_check,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Run a set of system checks on application start up",
      package: package(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: ["coveralls.html": :test],
      dialyzer: [
        plt_add_apps: [
          :fun_with_flags,
          :mix
        ],
        list_unused_filters: true
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:fun_with_flags, "~> 1.12", optional: true, runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Jhon Pedroza"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => @source_url <> "/blob/master/CHANGELOG.md"
      }
    ]
  end

  defp docs do
    [
      main: "RuntimeCheck",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["CHANGELOG.md"]
    ]
  end
end
