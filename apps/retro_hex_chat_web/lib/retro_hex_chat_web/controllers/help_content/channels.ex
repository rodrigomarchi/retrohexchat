defmodule RetroHexChatWeb.HelpContent.Channels do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Chat.TimeFormatter
  alias RetroHexChat.Services.ChanExpiry
  alias RetroHexChat.Services.NickExpiry

  import RetroHexChatWeb.Components.Diagrams, warn: false
  import RetroHexChatWeb.HelpContent.Helpers

  embed_templates "{channel_*,channels*,chanserv*,nickserv*,mode_*}"
end
