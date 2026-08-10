defmodule RetroHexChatWeb.HelpContent.ChatFeatures do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.Diagrams, warn: false
  import RetroHexChatWeb.HelpContent.Helpers

  embed_templates "feature_{address_book*,message_layout*,message_attachments*,session_cards*,virtual_spaces*,choose_character*,space_combat*,admin_audit_log*,admin_broadcast*,admin_channels*,admin_console*,admin_danger_zone*,admin_motd*,admin_server_settings*,admin_turn*,admin_users*,aliases*,auto_join_channels*,auto_reconnect*,autocomplete*,autorespond*,away_reply*,ban_exceptions*,channel_central*,channel_invites*,char_counter*,cheatsheet*,command_syntax_tooltip*,connection_states*,context_menus*,contextual_tips*,copy*,copy_feedback*,custom_menus*,display_settings*,emoji*,enhanced_history*,flood_protection*,highlight_words*,ignore_list*,interactive_elements*,invite_exceptions*,key_bindings*,kick_notifications*,lag_indicator*,message_delete*,message_edit*,message_reply*,mute*,nick_colors*}"
end
