defmodule RetroHexChat.MixProject do
  use Mix.Project

  def project do
    [
      app: :retro_hex_chat,
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
      test_coverage: [
        summary: [threshold: 60],
        ignore_modules: [
          RetroHexChat.Chat.HelpTopics.ChannelModes,
          RetroHexChat.Chat.HelpTopics.Commands,
          RetroHexChat.Chat.HelpTopics.Features,
          RetroHexChat.Chat.HelpTopics.GettingStarted,
          RetroHexChat.Chat.HelpTopics.KeyboardShortcuts,
          RetroHexChat.Chat.HelpTopics.Services,
          RetroHexChat.Chat.HelpTopics.SpecialMessages,
          RetroHexChat.Chat.HelpTopics.TextFormatting,
          RetroHexChat.Chat.HelpTopics.UserInterface,
          RetroHexChat.Gettext
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {RetroHexChat.Application, []},
      extra_applications: [:logger, :runtime_tools, :xmerl]
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
      {:dns_cluster, "~> 0.2.0"},
      {:phoenix, "~> 1.8"},
      {:phoenix_pubsub, "~> 2.1"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:jason, "~> 1.2"},
      {:bcrypt_elixir, "~> 3.0"},
      {:phoenix_html, "~> 4.0"},
      {:gettext, "~> 1.0"},
      {:req, "~> 0.5"},
      {:ex_stun, "~> 0.2.0"},
      {:ecto_psql_extras, "~> 0.8"},
      {:tz, "~> 0.28"},

      # Test dependencies
      {:mox, "~> 1.0", only: :test},
      {:ex_machina, "~> 2.8", only: :test},
      {:stream_data, "~> 1.0", only: [:test, :dev]}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run #{__DIR__}/priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
