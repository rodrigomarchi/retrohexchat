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
  import RetroHexChatWeb.Components.UI.LoadingSpinner

  alias RetroHexChatWeb.Icons

  @doc "Renders the channel list dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :channels, :list, default: []
  attr :search, :string, default: ""
  attr :selected_channel, :string, default: nil, doc: "Currently selected channel name"
  attr :loading, :boolean, default: false, doc: "Show loading state"
  attr :on_search, :any, default: nil, doc: "Search input change callback"
  attr :on_select, :any, default: nil, doc: "Row click callback"
  attr :on_join, :any, default: nil, doc: "Join button callback"
  attr :on_close, :any, default: nil, doc: "Close button callback"

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
          <.input
            type="text"
            value={@search}
            placeholder="Filter channels..."
            class="flex-1"
            phx-change={@on_search}
            phx-debounce="300"
            name="search"
            data-testid="channel-list-search"
          />
          <.button size="sm" variant="outline" phx-click={@on_search}>
            <:icon><Icons.icon_btn_find class="w-4 h-4" /></:icon>
            Search
          </.button>
        </div>

        <%!-- Channel table --%>
        <div class="max-h-[300px] overflow-y-auto retro-scrollbar">
          <%= if @loading do %>
            <div class="flex items-center justify-center py-retro-24">
              <.loading_spinner size="sm" text="Searching..." />
            </div>
          <% else %>
            <.table>
              <.table_header>
                <.table_row>
                  <.table_head>Channel</.table_head>
                  <.table_head>Users</.table_head>
                  <.table_head>Topic</.table_head>
                </.table_row>
              </.table_header>
              <.table_body>
                <.table_row
                  :for={ch <- @channels}
                  class={
                    if(@selected_channel == ch.name,
                      do: "bg-selection-bg text-selection-fg",
                      else: ""
                    )
                  }
                  phx-click={@on_select}
                  phx-value-channel={ch.name}
                  data-testid={"channel-list-row-#{ch.name}"}
                >
                  <.table_cell class="font-bold">{ch.name}</.table_cell>
                  <.table_cell>{ch.users}</.table_cell>
                  <.table_cell class="truncate max-w-[200px]">{ch.topic}</.table_cell>
                </.table_row>
              </.table_body>
            </.table>
          <% end %>
        </div>
      </.dialog_body>

      <.dialog_footer>
        <.button
          variant="default"
          phx-click={@on_join}
          disabled={@selected_channel == nil}
          data-testid="channel-list-join"
        >
          <:icon><Icons.icon_btn_add class="w-4 h-4" /></:icon>
          Join
        </.button>
        <.button variant="outline" phx-click={@on_close || hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          Close
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end
end
