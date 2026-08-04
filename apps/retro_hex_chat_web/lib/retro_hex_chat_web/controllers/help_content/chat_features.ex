defmodule RetroHexChatWeb.HelpContent.ChatFeatures do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChatWeb.Icons

  import RetroHexChatWeb.Components.Diagrams, warn: false

  def help_h4(assigns) do
    ~H"""
    <h4 class="flex items-center gap-1.5 text-sm font-bold mt-4 mb-1.5 text-text">
      <.help_icon name={@icon} class="w-3.5 h-3.5 flex-shrink-0" />
      {render_slot(@inner_block)}
    </h4>
    """
  end

  def help_link(assigns) do
    ~H"""
    <.link navigate={"/chat/help/#{@topic}"} class="text-link hover:underline">
      {render_slot(@inner_block)}
    </.link>
    """
  end

  def help_icon(assigns), do: apply(Icons, assigns.name, [%{class: assigns.class}])

  embed_templates "feature_{address_book*,message_layout*,message_attachments*,session_cards*,virtual_spaces*,choose_character*,space_combat*,admin_audit_log*,admin_broadcast*,admin_channels*,admin_console*,admin_danger_zone*,admin_motd*,admin_server_settings*,admin_turn*,admin_users*,aliases*,auto_join_channels*,auto_reconnect*,autocomplete*,autorespond*,away_reply*,ban_exceptions*,channel_central*,channel_invites*,char_counter*,cheatsheet*,command_syntax_tooltip*,connection_states*,context_menus*,contextual_tips*,copy*,copy_feedback*,custom_menus*,display_settings*,emoji*,enhanced_history*,flood_protection*,highlight_words*,ignore_list*,interactive_elements*,invite_exceptions*,key_bindings*,kick_notifications*,lag_indicator*,message_delete*,message_edit*,message_reply*,mute*,nick_colors*}"
end
