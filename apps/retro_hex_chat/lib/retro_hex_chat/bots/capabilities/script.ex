defmodule RetroHexChat.Bots.Capabilities.Script do
  @moduledoc "Custom script engine (Coming soon)"
  use Gettext, backend: RetroHexChat.Gettext

  use RetroHexChat.Bots.Capabilities.Placeholder,
    name: :script,
    description: dgettext("bots", "Custom script engine (Coming soon)"),
    default_config: %{
      "language" => "lua",
      "source" => "",
      "sandbox" => true,
      "timeout_ms" => 5000
    }
end
