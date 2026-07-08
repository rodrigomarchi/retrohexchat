defmodule RetroHexChatWeb.ChatLive.Components.Conversations do
  @moduledoc """
  The conversations sidebar: channel / PM / popular-channel sections with their
  unread, highlight, flash and mute states.

  Renders inside its own LiveComponent so change-tracking isolates it from the
  parent's hot path — it no longer re-renders on every chat message, typing or lag
  update, only when one of its own assigns changes.

  The parent stays the canonical owner of the underlying maps (`unread_counts`,
  `highlight_channels`, `flash_channels`, `muted_channels`, `conversations_sections`,
  `channel_user_counts`, `popular_channels`) because many subsystems read and write
  them; they are passed in as raw values and this component derives the displayed
  lists (`unread_channels`, `unread_pms`, `collapsed_sections`) itself instead of the
  parent template computing them on every render. `show_conversations` stays on the
  parent (toggled from the menu/toolbar) and arrives as `visible`. The row events
  (`switch_channel`, `switch_pm`, `conversations_toggle_section`, …) bubble to the
  parent unchanged.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.Conversations

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
       pm_conversations: [],
       unread_counts: %{},
       highlight_channels: MapSet.new(),
       flash_channels: MapSet.new(),
       muted_channels: MapSet.new(),
       disconnected_channels: MapSet.new(),
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
      :pm_conversations,
      :unread_counts,
      :highlight_channels,
      :flash_channels,
      :muted_channels,
      :disconnected_channels,
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

    collapsed_sections =
      for {k, expanded?} <- assigns.conversations_sections, !expanded?, do: to_string(k)

    assigns =
      assign(assigns,
        unread_channels: unread_channels,
        unread_pms: unread_pms,
        collapsed_sections: collapsed_sections
      )

    ~H"""
    <div id={"#{@id}-mount"} class="flex h-full shrink-0">
      <.conversations_sidebar visible={@visible} on_backdrop="toggle_conversations">
        <.conversations
          channels={@channels}
          active_channel={@active_channel}
          unread_counts={@unread_counts}
          unread_channels={@unread_channels}
          unread_pms={@unread_pms}
          highlight_channels={MapSet.to_list(@highlight_channels)}
          flash_channels={MapSet.to_list(@flash_channels)}
          muted_channels={MapSet.to_list(@muted_channels)}
          disconnected_channels={MapSet.to_list(@disconnected_channels)}
          pm_conversations={@pm_conversations}
          active_pm={@active_pm}
          nick_color_fn={@nick_color_fn}
          channel_user_counts={@channel_user_counts}
          popular_channels={@popular_channels}
          collapsed_sections={@collapsed_sections}
          on_channel_click="switch_channel"
          on_channel_dblclick="channel_dblclick"
          on_pm_click="switch_pm"
          on_toggle_section="conversations_toggle_section"
          on_close="toggle_conversations"
          on_browse_channels="conversations_browse_all"
          on_join_popular="conversations_join_popular"
        />
      </.conversations_sidebar>
    </div>
    """
  end
end
