defmodule RetroHexChatWeb.HelpContent.CommandsAtoM do
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

  embed_templates "{commands_overview*,cmd_alias*,cmd_announce*,cmd_autojoin*,cmd_autorespond*,cmd_away*,cmd_ban*,cmd_bio*,cmd_call*,cmd_clear*,cmd_cs*,cmd_deop*,cmd_devoice*,cmd_game*,cmd_help*,cmd_ignore*,cmd_invite*,cmd_join*,cmd_kick*,cmd_knock*,cmd_list*,cmd_me*,cmd_mode*,cmd_motd*,cmd_msg*,cmd_mute*}"
end
