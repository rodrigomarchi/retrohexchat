defmodule RetroHexChatWeb.Components.UI.ChannelDialog do
  @moduledoc """
  Channel dialog component for the showcase design system.

  Composed from dialog + tabs + table + button + form controls.
  Tabs: General/Modes/Bans/Ban Exceptions/Invite Exceptions.

  ## Usage

      <.channel_dialog id="channel-settings" channel="#lobby" show={true} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Tabs
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Checkbox

  alias RetroHexChatWeb.Icons

  @doc "Renders the channel settings dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :channel, :string, default: "#channel"
  attr :topic, :string, default: ""
  attr :bans, :list, default: []
  attr :ban_exceptions, :list, default: []
  attr :invite_exceptions, :list, default: []

  @spec channel_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def channel_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header>
        <.dialog_icon>
          <Icons.icon_tab_channel class="w-4 h-4" />
        </.dialog_icon>
        <.dialog_title>{@channel} Settings</.dialog_title>
        <.dialog_close id={@id} />
      </.dialog_header>

      <.dialog_body>
        <.tabs :let={builder} id={"#{@id}-tabs"} default="general">
          <.tabs_list>
            <.tabs_trigger builder={builder} value="general">
              <:icon><Icons.icon_tab_general class="w-4 h-4" /></:icon>
              General
            </.tabs_trigger>
            <.tabs_trigger builder={builder} value="modes">
              <:icon><Icons.icon_tab_modes class="w-4 h-4" /></:icon>
              Modes
            </.tabs_trigger>
            <.tabs_trigger builder={builder} value="bans">
              <:icon><Icons.icon_ban class="w-4 h-4" /></:icon>
              Bans
            </.tabs_trigger>
          </.tabs_list>

          <.tabs_content value="general">
            <div class="space-y-retro-8 p-retro-4">
              <div>
                <label class="text-xs font-bold block mb-retro-2">Topic</label>
                <.input type="text" value={@topic} class="w-full" />
              </div>
            </div>
          </.tabs_content>

          <.tabs_content value="modes">
            <div class="space-y-retro-4 p-retro-4 text-xs">
              <label class="flex items-center gap-retro-4 cursor-pointer">
                <.checkbox name="mode_n" value={true} />
                No external messages (+n)
              </label>
              <label class="flex items-center gap-retro-4 cursor-pointer">
                <.checkbox name="mode_t" value={true} />
                Topic settable by ops only (+t)
              </label>
              <label class="flex items-center gap-retro-4 cursor-pointer">
                <.checkbox name="mode_m" />
                Moderated (+m)
              </label>
              <label class="flex items-center gap-retro-4 cursor-pointer">
                <.checkbox name="mode_i" />
                Invite only (+i)
              </label>
            </div>
          </.tabs_content>

          <.tabs_content value="bans">
            <div class="space-y-retro-4 p-retro-4">
              <.table>
                <.table_header>
                  <.table_row>
                    <.table_head>Mask</.table_head>
                    <.table_head>Set by</.table_head>
                    <.table_head>Date</.table_head>
                  </.table_row>
                </.table_header>
                <.table_body>
                  <.table_row :for={ban <- @bans}>
                    <.table_cell>{ban.mask}</.table_cell>
                    <.table_cell>{ban.set_by}</.table_cell>
                    <.table_cell>{ban.date}</.table_cell>
                  </.table_row>
                </.table_body>
              </.table>
              <div class="flex gap-retro-4">
                <.button size="sm" variant="outline">
                  <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
                  Add
                </.button>
                <.button size="sm" variant="outline">
                  <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
                  Remove
                </.button>
              </div>
            </div>
          </.tabs_content>
        </.tabs>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="default">
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          OK
        </.button>
        <.button variant="outline" phx-click={hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          Cancel
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end
end
