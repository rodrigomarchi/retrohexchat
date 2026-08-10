defmodule RetroHexChatWeb.HelpContent.Bots do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams, warn: false
  import RetroHexChatWeb.HelpContent.Helpers

  embed_templates "{bot_*,botservice*}"
end
