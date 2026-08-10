defmodule RetroHexChatWeb.HelpContent.UI do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams, warn: false
  import RetroHexChatWeb.HelpContent.Helpers

  embed_templates "{ui_*,formatting_*,keyboard_shortcuts*,empty_states*,welcome*,private_messages*,connecting*,connect_authentication*}"
end
