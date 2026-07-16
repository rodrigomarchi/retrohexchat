defmodule RetroHexChatWeb.Components.UI.ChannelList do
  @moduledoc """
  Channel list dialog component for the showcase design system.

  Composed from dialog + table + input + button primitives.
  Shows channel table (name/users/topic) with search and Join button.

  ## Usage

      <.channel_list id="channel-list" show={true} channels={@channels} />
  """
  use RetroHexChatWeb.Component

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
      class="cl-dialog"
    >
      <%!-- Search --%>
      <form
        class="cl-search-form"
        phx-change={@on_search}
        phx-submit={@on_search}
      >
        <.input
          type="text"
          value={@search}
          placeholder={dgettext("dialogs", "Filter channels...")}
          class="cl-search-input"
          phx-debounce="300"
          name="search"
          data-testid="channel-list-search"
        />
        <.button size="sm" variant="outline" type="submit" class="cl-search-button">
          <:icon><Icons.icon_btn_find class="w-4 h-4" /></:icon>
          {dgettext("dialogs", "Search")}
        </.button>
      </form>

      <%!-- Channel list --%>
      <div class="cl-channel-list retro-scrollbar">
        <%= if @loading do %>
          <div class="cl-loading-state">
            <.activity_indicator
              icon={:channels}
              variant="panel"
              text={dgettext("dialogs", "Searching...")}
            />
          </div>
        <% else %>
          <%= if @channels == [] do %>
            <div class="cl-empty-state">
              <Icons.icon_channels class="w-4 h-4" />
              <p>{dgettext("dialogs", "No channels found")}</p>
            </div>
          <% else %>
            <button
              :for={ch <- @channels}
              type="button"
              class={[
                "cl-channel-entry",
                @selected_channel == ch.name && "cl-channel-entry--selected"
              ]}
              phx-click={@on_select}
              phx-value-channel={ch.name}
              data-testid={"channel-list-row-#{ch.name}"}
            >
              <span class="cl-channel-main">
                <span class="cl-channel-icon" aria-hidden="true">
                  <Icons.icon_channels class="w-4 h-4" />
                </span>
                <span class="cl-channel-copy">
                  <span class="cl-channel-title-row">
                    <span class="cl-channel-name">{ch.name}</span>
                    <.badge
                      :if={invite_only?(ch)}
                      variant="secondary"
                      class="cl-channel-badge"
                      data-testid={"channel-list-invite-only-#{ch.name}"}
                    >
                      +i
                    </.badge>
                  </span>
                  <span class="cl-channel-topic">{display_topic(ch.topic)}</span>
                </span>
              </span>
              <span class="cl-channel-meta">
                <span class="cl-meta-item">
                  <span class="cl-meta-label">{dgettext("dialogs", "Users")}</span>
                  <span class="cl-meta-value">{ch.user_count}</span>
                </span>
                <span :if={invite_only?(ch)} class="cl-meta-item">
                  <span class="cl-meta-label">{dgettext("dialogs", "Mode")}</span>
                  <span class="cl-meta-value">{dgettext("dialogs", "Invite only")}</span>
                </span>
              </span>
            </button>
          <% end %>
        <% end %>
      </div>

      <div class="cl-action-row">
        <.button
          variant="default"
          phx-click={if @request_access?, do: @on_knock, else: @on_join}
          phx-value-channel={@selected_channel}
          disabled={@selected_channel == nil}
          class="cl-action-button"
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

  defp display_topic(nil), do: dgettext("dialogs", "No topic set")
  defp display_topic(""), do: dgettext("dialogs", "No topic set")
  defp display_topic(topic), do: topic
end
