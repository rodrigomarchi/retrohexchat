defmodule RetroHexChatWeb.Components.UI.ChannelList do
  @moduledoc """
  Channel list dialog component for the showcase design system.

  Composed from dialog + table + input + button primitives.
  Shows channel table (name/users/topic) with search and Join button.

  ## Usage

      <.channel_list id="channel-list" show={true} channels={@channels} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Table
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.ActivityIndicator

  alias RetroHexChatWeb.Icons

  @doc "Renders the channel list dialog."
  attr :id, :string, required: true
  attr :channels, :list, default: []
  attr :search, :string, default: ""
  attr :selected_channel, :string, default: nil, doc: "Currently selected channel name"
  attr :loading, :boolean, default: false, doc: "Show loading state"
  attr :on_search, :any, default: nil, doc: "Search input change callback"
  attr :on_select, :any, default: nil, doc: "Row click callback"
  attr :on_join, :any, default: nil, doc: "Join button callback"
  attr :on_knock, :any, default: nil, doc: "Request-access button callback"

  @spec channel_list_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def channel_list_panel(assigns) do
    assigns =
      assign(
        assigns,
        :request_access?,
        request_access?(assigns.channels, assigns.selected_channel)
      )

    ~H"""
    <div
      id={"#{@id}-content"}
      data-testid="channel-list-panel"
      class="flex h-full min-h-0 flex-col gap-retro-8"
    >
      <%!-- Search --%>
      <form
        class="flex items-center gap-retro-4"
        phx-change={@on_search}
        phx-submit={@on_search}
      >
        <.input
          type="text"
          value={@search}
          placeholder={dgettext("dialogs", "Filter channels...")}
          class="flex-1"
          phx-debounce="300"
          name="search"
          data-testid="channel-list-search"
        />
        <.button size="sm" variant="outline" type="submit">
          <:icon><Icons.icon_btn_find class="w-4 h-4" /></:icon>
          {dgettext("dialogs", "Search")}
        </.button>
      </form>

      <%!-- Channel table --%>
      <div class="max-h-[300px] overflow-y-auto retro-scrollbar">
        <%= if @loading do %>
          <div class="flex items-center justify-center py-retro-24">
            <.activity_indicator
              icon={:channels}
              variant="panel"
              text={dgettext("dialogs", "Searching...")}
            />
          </div>
        <% else %>
          <.table>
            <.table_header>
              <.table_row>
                <.table_head>{dgettext("dialogs", "Channel")}</.table_head>
                <.table_head>{dgettext("dialogs", "Users")}</.table_head>
                <.table_head>{dgettext("dialogs", "Topic")}</.table_head>
              </.table_row>
            </.table_header>
            <.table_body>
              <.table_row :if={@channels == []}>
                <.table_cell colspan="3" class="text-center text-muted-foreground py-4">
                  {dgettext("dialogs", "No channels found")}
                </.table_cell>
              </.table_row>
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
                <.table_cell class="font-bold">
                  <span class="inline-flex items-center gap-retro-4">
                    <span>{ch.name}</span>
                    <.badge
                      :if={invite_only?(ch)}
                      variant="secondary"
                      data-testid={"channel-list-invite-only-#{ch.name}"}
                    >
                      +i
                    </.badge>
                  </span>
                </.table_cell>
                <.table_cell>{ch.user_count}</.table_cell>
                <.table_cell class="truncate max-w-[200px]">{ch.topic}</.table_cell>
              </.table_row>
            </.table_body>
          </.table>
        <% end %>
      </div>

      <div class="flex justify-end gap-retro-4">
        <.button
          variant="default"
          phx-click={if @request_access?, do: @on_knock, else: @on_join}
          phx-value-channel={@selected_channel}
          disabled={@selected_channel == nil}
          data-testid={if @request_access?, do: "channel-list-knock", else: "channel-list-join"}
        >
          <:icon>
            <%= if @request_access? do %>
              <Icons.icon_dialog_invite class="w-4 h-4" />
            <% else %>
              <Icons.icon_btn_add class="w-4 h-4" />
            <% end %>
          </:icon>
          {if @request_access?,
            do: dgettext("dialogs", "Request Access..."),
            else: dgettext("dialogs", "Join")}
        </.button>
      </div>
    </div>
    """
  end

  defp selected_entry(channels, selected_channel) do
    Enum.find(channels, &(Map.get(&1, :name) == selected_channel))
  end

  defp request_access?(channels, selected_channel) do
    case selected_entry(channels, selected_channel) do
      nil -> false
      channel -> invite_only?(channel) and not joined?(channel)
    end
  end

  defp invite_only?(channel), do: Map.get(channel, :invite_only?, false)
  defp joined?(channel), do: Map.get(channel, :joined?, false)
end
