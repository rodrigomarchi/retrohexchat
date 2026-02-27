defmodule RetroHexChatWeb.Components.UI.BotManager do
  @moduledoc """
  Bot manager dialog component for the showcase design system.

  Composed from dialog + table + button + form controls.
  Bot list with creation/edit form.

  ## Usage

      <.bot_manager id="bot-manager" show={true} bots={@bots} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Badge

  alias RetroHexChatWeb.Icons

  @doc "Renders the bot manager dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :bots, :list, default: []

  @spec bot_manager(map()) :: Phoenix.LiveView.Rendered.t()
  def bot_manager(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header>
        <.dialog_icon>
          <Icons.icon_dialog_bot_management class="w-4 h-4" />
        </.dialog_icon>
        <.dialog_title>Bot Manager</.dialog_title>
        <.dialog_close id={@id} />
      </.dialog_header>

      <.dialog_body class="flex gap-retro-8 min-h-[250px]">
        <%!-- Bot list --%>
        <div class="flex-1 space-y-retro-4">
          <.table>
            <.table_header>
              <.table_row>
                <.table_head>Name</.table_head>
                <.table_head>Status</.table_head>
                <.table_head>Channels</.table_head>
              </.table_row>
            </.table_header>
            <.table_body>
              <.table_row :for={bot <- @bots}>
                <.table_cell class="font-bold">{bot.name}</.table_cell>
                <.table_cell>
                  <.badge variant={if bot.active, do: "default", else: "outline"}>
                    {if bot.active, do: "Active", else: "Inactive"}
                  </.badge>
                </.table_cell>
                <.table_cell>{Enum.join(bot.channels, ", ")}</.table_cell>
              </.table_row>
            </.table_body>
          </.table>

          <div class="flex gap-retro-4">
            <.button size="sm" variant="outline">
              <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
              Add
            </.button>
            <.button size="sm" variant="outline">
              <:icon><Icons.icon_btn_edit class="w-4 h-4" /></:icon>
              Edit
            </.button>
            <.button size="sm" variant="outline">
              <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
              Remove
            </.button>
          </div>
        </div>

        <%!-- Edit form --%>
        <div class="w-[180px] shrink-0 shadow-retro-field bg-white p-retro-8 space-y-retro-8">
          <h3 class="font-bold text-xs">Bot Settings</h3>
          <div>
            <label class="text-xs font-bold block mb-retro-2">Name</label>
            <.input type="text" placeholder="Bot name" class="w-full" />
          </div>
          <div>
            <label class="text-xs font-bold block mb-retro-2">Channels</label>
            <.input type="text" placeholder="#channel1, #channel2" class="w-full" />
          </div>
        </div>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="default" phx-click={hide_modal(@id)}>
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
