defmodule RetroHexChatWeb.Components.UI.ChannelList do
  @moduledoc """
  Channel list dialog component for the showcase design system.

  Composed from dialog + table + input + button primitives.
  Shows channel table (name/users/topic) with search and Join button.

  ## Usage

      <.channel_list id="channel-list" show={true} channels={@channels} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders the channel list dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :channels, :list, default: []
  attr :search, :string, default: ""

  @spec channel_list(map()) :: Phoenix.LiveView.Rendered.t()
  def channel_list(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header>
        <.dialog_icon>
          <Icons.icon_channels class="w-4 h-4" />
        </.dialog_icon>
        <.dialog_title>Channel List</.dialog_title>
        <.dialog_close id={@id} />
      </.dialog_header>

      <.dialog_body class="space-y-retro-8">
        <%!-- Search --%>
        <div class="flex items-center gap-retro-4">
          <.input type="text" value={@search} placeholder="Filter channels..." class="flex-1" />
          <.button size="sm" variant="outline">
            <:icon><Icons.icon_btn_find class="w-4 h-4" /></:icon>
            Search
          </.button>
        </div>

        <%!-- Channel table --%>
        <div class="max-h-[300px] overflow-y-auto retro-scrollbar">
          <.table>
            <.table_header>
              <.table_row>
                <.table_head>Channel</.table_head>
                <.table_head>Users</.table_head>
                <.table_head>Topic</.table_head>
              </.table_row>
            </.table_header>
            <.table_body>
              <.table_row :for={ch <- @channels}>
                <.table_cell class="font-bold">{ch.name}</.table_cell>
                <.table_cell>{ch.users}</.table_cell>
                <.table_cell class="truncate max-w-[200px]">{ch.topic}</.table_cell>
              </.table_row>
            </.table_body>
          </.table>
        </div>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="default">
          <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
          Join
        </.button>
        <.button variant="outline" phx-click={hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          Close
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end
end
