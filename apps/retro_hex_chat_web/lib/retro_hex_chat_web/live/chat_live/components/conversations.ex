defmodule RetroHexChatWeb.ChatLive.Components.Conversations do
  @moduledoc """
  The conversations sidebar: channel / PM / popular-channel sections with their
  unread, highlight, flash and mute states.

  Renders inside its own LiveComponent so change-tracking isolates it from the
  parent's hot path — it no longer re-renders on every chat message, typing or lag
  update, only when one of its own assigns changes.

  The parent stays the canonical owner of the underlying maps (`unread_counts`,
  `channel_activity_order`, `highlight_channels`, `flash_channels`, `muted_channels`,
  `conversations_sections`, `channel_user_counts`, `popular_channels`) because many subsystems read and write
  them; they are passed in as raw values and this component derives the displayed
  lists (`unread_channels`, `unread_pms`, `collapsed_sections`,
  `autojoin_entries`) itself instead of the parent template computing them on
  every render. `show_conversations` stays on the parent (toggled from the
  menu/toolbar) and arrives as `visible`. The row events (`switch_channel`,
  `switch_pm`, `conversations_toggle_section`, ...) bubble to the parent
  unchanged.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.Conversations

  alias RetroHexChat.Chat.AutoJoinList

  @id "conversations"

  @doc "Stable component id."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     assign(socket,
       id: @id,
       visible: true,
       channels: [],
       active_channel: nil,
       active_pm: nil,
       open_pm_tabs: [],
       pm_conversations: [],
       pm_conversations_truncated: false,
       autojoin_list: AutoJoinList.new(),
       unread_counts: %{},
       channel_activity_order: %{},
       highlight_channels: MapSet.new(),
       flash_channels: MapSet.new(),
       muted_channels: MapSet.new(),
       disconnected_channels: MapSet.new(),
       group_call_channels: MapSet.new(),
       group_call_summaries: %{},
       p2p_peer: nil,
       p2p_session: nil,
       p2p_pm_sessions: %{},
       conversations_sections: %{},
       channel_user_counts: %{},
       popular_channels: [],
       nick_color_fn: fn _nick -> nil end
     )}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    keys = [
      :visible,
      :channels,
      :active_channel,
      :active_pm,
      :open_pm_tabs,
      :pm_conversations,
      :pm_conversations_truncated,
      :autojoin_list,
      :unread_counts,
      :channel_activity_order,
      :highlight_channels,
      :flash_channels,
      :muted_channels,
      :disconnected_channels,
      :group_call_channels,
      :group_call_summaries,
      :p2p_peer,
      :p2p_session,
      :p2p_pm_sessions,
      :conversations_sections,
      :channel_user_counts,
      :popular_channels,
      :nick_color_fn
    ]

    merged =
      Enum.reduce(keys, %{}, fn key, acc ->
        Map.put(acc, key, Map.get(assigns, key, socket.assigns[key]))
      end)

    {:ok, assign(socket, Map.put(merged, :id, Map.get(assigns, :id, socket.assigns.id)))}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    unread_channels =
      for {k, v} <- assigns.unread_counts, v > 0, !String.starts_with?(k, "pm:"), do: k

    unread_pms = for {"pm:" <> nick, v} <- assigns.unread_counts, v > 0, do: nick
    unread_total = assigns.unread_counts |> Map.values() |> Enum.sum()

    collapsed_sections =
      for {k, expanded?} <- assigns.conversations_sections, !expanded?, do: to_string(k)

    autojoin_list = assigns.autojoin_list || AutoJoinList.new()
    autojoin_entries = AutoJoinList.entries(autojoin_list)

    assigns =
      assign(assigns,
        unread_channels: unread_channels,
        unread_pms: unread_pms,
        unread_total: unread_total,
        collapsed_sections: collapsed_sections,
        autojoin_entries: autojoin_entries
      )

    ~H"""
    <div id={"#{@id}-mount"} class="flex h-full shrink-0">
      <.conversations_sidebar
        visible={@visible}
        on_backdrop="toggle_conversations"
        on_toggle="toggle_conversations"
      >
        <:rail>
          <.conversations_rail
            expanded={@visible}
            active_channel={@active_channel}
            active_pm={@active_pm}
            channel_count={length(@channels)}
            pm_count={length(@pm_conversations)}
            autojoin_count={length(@autojoin_entries)}
            popular_count={length(@popular_channels)}
            unread_count={@unread_total}
            on_toggle="toggle_conversations"
          />
        </:rail>
        <.conversations
          channels={@channels}
          active_channel={@active_channel}
          unread_counts={@unread_counts}
          channel_activity_order={@channel_activity_order}
          unread_channels={@unread_channels}
          unread_pms={@unread_pms}
          highlight_channels={MapSet.to_list(@highlight_channels)}
          flash_channels={MapSet.to_list(@flash_channels)}
          muted_channels={MapSet.to_list(@muted_channels)}
          disconnected_channels={MapSet.to_list(@disconnected_channels)}
          group_call_channels={MapSet.to_list(@group_call_channels)}
          group_call_summaries={@group_call_summaries}
          p2p_peer={@p2p_peer}
          p2p_session={@p2p_session}
          p2p_pm_sessions={@p2p_pm_sessions}
          open_pm_tabs={@open_pm_tabs}
          pm_conversations={@pm_conversations}
          pm_conversations_truncated={@pm_conversations_truncated}
          autojoin_entries={@autojoin_entries}
          active_pm={@active_pm}
          nick_color_fn={@nick_color_fn}
          channel_user_counts={@channel_user_counts}
          popular_channels={@popular_channels}
          collapsed_sections={@collapsed_sections}
          on_channel_click="switch_channel"
          on_channel_dblclick="channel_dblclick"
          on_pm_click="switch_pm"
          on_toggle_section="conversations_toggle_section"
          on_browse_channels="conversations_browse_all"
          on_join_popular="conversations_join_popular"
          on_autojoin_open="open_autojoin_dialog"
          on_close="toggle_conversations"
        />
      </.conversations_sidebar>
    </div>
    """
  end
end
