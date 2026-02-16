defmodule RetroHexChatWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :retro_hex_chat_web,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [summary: [threshold: 70]],
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {RetroHexChatWeb.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.3"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:retro_hex_chat, in_umbrella: true},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.5"},

      # Test dependencies
      {:floki, "~> 0.37", only: :test},
      {:lazy_html, ">= 0.1.0", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["esbuild.install --if-missing"],
      "assets.build": [
        "compile",
        "esbuild retro_hex_chat_web",
        "esbuild retro_hex_chat_web_css",
        "esbuild retro_hex_chat_web_landing",
        "esbuild retro_hex_chat_web_landing_css"
      ],
      "assets.deploy": [
        "esbuild retro_hex_chat_web --minify",
        "esbuild retro_hex_chat_web_css --minify",
        "esbuild retro_hex_chat_web_landing --minify",
        "esbuild retro_hex_chat_web_landing_css --minify",
        "phx.digest"
      ]
    ]
  end
end
