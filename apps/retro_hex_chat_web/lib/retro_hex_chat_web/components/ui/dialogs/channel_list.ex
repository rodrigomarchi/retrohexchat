defmodule RetroHexChatWeb.Components.UI.ChannelList do
  @moduledoc """
  The window that lists the rooms you can go to.

  Each row is its own door: pressing it joins the channel, or asks for access
  when the channel is invite-only and you are not in it. The verb is drawn on
  the row, because two neighbouring rows can do different things — one press,
  and you can read which one before making it.

  ## Usage

      <.channel_list_panel id="channel-list" channels={@channels} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ActionList
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.ActivityIndicator

  alias RetroHexChat.Chat.TimeFormatter
  alias RetroHexChatWeb.Icons

  @doc "Renders the channel list dialog."
  attr :id, :string, required: true
  attr :channels, :list, default: []
  attr :search, :string, default: ""
  attr :loading, :boolean, default: false, doc: "Show loading state"
  attr :on_search, :any, default: nil, doc: "Search input change callback"
  attr :on_join, :any, default: nil, doc: "Row press callback for a joinable channel"
  attr :on_knock, :any, default: nil, doc: "Row press callback for an invite-only channel"

  @spec channel_list_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def channel_list_panel(assigns) do
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
            <.action_list id={"#{@id}-rows"} label={dgettext("dialogs", "Channels")}>
              <.action_row
                :for={ch <- @channels}
                on_activate={if request_access?(ch), do: @on_knock, else: @on_join}
                value={%{"channel" => ch.name}}
                data-testid={"channel-list-row-#{ch.name}"}
              >
                <:icon><Icons.icon_channels class="w-4 h-4" /></:icon>
                <:cta label={
                  if request_access?(ch),
                    do: dgettext("dialogs", "Request Access..."),
                    else: dgettext("dialogs", "Join")
                }>
                  <Icons.icon_btn_add :if={not request_access?(ch)} class="w-4 h-4" />
                  <Icons.icon_dialog_invite :if={request_access?(ch)} class="w-4 h-4" />
                </:cta>
                <:title>
                  {ch.name}
                  <.badge
                    :if={invite_only?(ch)}
                    variant="secondary"
                    class="cl-channel-badge"
                    data-testid={"channel-list-invite-only-#{ch.name}"}
                  >
                    +i
                  </.badge>
                </:title>
                <:meta>{display_topic(ch.topic)}</:meta>
                <:trailing>
                  <.action_figure label={dgettext("dialogs", "Users")} value={ch.user_count} />
                  <.action_figure
                    :if={invite_only?(ch)}
                    label={dgettext("dialogs", "Mode")}
                    value={dgettext("dialogs", "Invite only")}
                  />
                  <%!--
                    A room with nobody in it right now is still a room. Saying
                    when it was last used is the difference between "empty" and
                    "abandoned", and it is the only thing the reader can act on.
                  --%>
                  <.action_figure
                    :if={last_used(ch)}
                    label={dgettext("dialogs", "Last used")}
                    value={last_used(ch)}
                    data-testid={"channel-list-activity-#{ch.name}"}
                  />
                </:trailing>
              </.action_row>
            </.action_list>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # A closed room you are not in cannot be entered, only knocked on. It is a
  # property of the row, so the verb it draws never changes under the pointer.
  defp request_access?(channel), do: invite_only?(channel) and not joined?(channel)

  defp invite_only?(channel), do: Map.get(channel, :invite_only?, false)
  defp joined?(channel), do: Map.get(channel, :joined?, false)

  # Asked of a room with nobody in it, and only then: with people inside, the
  # count is the fresher fact and two numbers competing for the same slot is how
  # a row stops being readable. Whether a process happens to be holding the
  # channel open is not the reader's question — "is anyone there" is.
  defp last_used(channel) do
    with 0 <- Map.get(channel, :user_count, 0),
         %DateTime{} = at <- Map.get(channel, :last_activity_at) do
      TimeFormatter.format_relative(at)
    else
      _occupied_or_unknown -> nil
    end
  end

  defp display_topic(nil), do: dgettext("dialogs", "No topic set")
  defp display_topic(""), do: dgettext("dialogs", "No topic set")
  defp display_topic(topic), do: topic
end
