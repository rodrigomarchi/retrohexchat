defmodule RetroHexChat.Bots.Capabilities.LLM do
  @moduledoc "LLM-powered intelligent responses (Coming soon)"
  use Gettext, backend: RetroHexChat.Gettext

  use RetroHexChat.Bots.Capabilities.Placeholder,
    name: :llm,
    description: dgettext("bots", "LLM-powered intelligent responses (Coming soon)"),
    default_config: %{
      "provider" => nil,
      "model" => nil,
      "system_prompt" => "",
      "max_tokens" => 150,
      "temperature" => 0.7
    }
end
