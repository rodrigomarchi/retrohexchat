defmodule RetroHexChatWeb.HelpContent.ChatStatusFeatures do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams, warn: false
  import RetroHexChatWeb.HelpContent.Helpers

  embed_templates "feature_{identity_presence*,link_previews*,nick_alignment*,nick_expiry*,notices*,notify_list*,paste_dialog*,perform*,pm_persistence*,quit_message*,search*,server_broadcasts*,smart_input*,sounds*,special_messages*,status_bar*,timers*,timestamp_format*,typing_indicator*,unread_indicators*,url_catcher*,user_lookup*}"
end
