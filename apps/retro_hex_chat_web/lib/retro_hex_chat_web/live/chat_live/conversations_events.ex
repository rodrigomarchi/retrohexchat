defmodule RetroHexChatWeb.ChatLive.ConversationsEvents do
  @moduledoc """
  Handle conversations sidebar events.

  Covers: conversations_toggle_section, conversations_join_popular,
  conversations_browse_all.

  Attached as `attach_hook(:conversations_events, :handle_event, ...)` in ChatLive.mount/3.
  Returns `{:halt, socket}` when the event is handled, `{:cont, socket}` otherwise.
  """

  import Phoenix.Component, only: [assign: 2]

  alias RetroHexChat.Commands.Autocomplete
  alias RetroHexChatWeb.ChatLive.Helpers

  # ── Section toggle ─────────────────────────────────────────

  def handle_event("conversations_toggle_section", %{"section" => section_str}, socket) do
    section = String.to_existing_atom(section_str)
    sections = socket.assigns.conversations_sections
    new_expanded = !Map.get(sections, section, false)
    updated_sections = Map.put(sections, section, new_expanded)

    socket = assign(socket, conversations_sections: updated_sections)

    # Lazy load popular channels on first expand
    socket =
      if section == :popular and new_expanded and not socket.assigns.popular_channels_loaded do
        load_popular_channels(socket)
      else
        socket
      end

    {:halt, socket}
  end

  # ── Join a popular channel ─────────────────────────────────

  def handle_event("conversations_join_popular", %{"channel" => channel}, socket) do
    socket =
      socket
      |> Helpers.join_channel(channel, socket.assigns.session)
      |> load_popular_channels()

    {:halt, socket}
  end

  # ── Browse all channels ────────────────────────────────────

  def handle_event("conversations_browse_all", _params, socket) do
    channels = Autocomplete.list_visible_channels(socket.assigns.session.channels)

    {:halt,
     assign(socket,
       show_channel_list: true,
       channel_list_channels: channels,
       channel_list_filtered: channels,
       channel_list_search: "",
       channel_list_loading: false,
       channel_list_count: length(channels)
     )}
  end

  # ── Catch-all ──────────────────────────────────────────────

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private ────────────────────────────────────────────────

  @spec load_popular_channels(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp load_popular_channels(socket) do
    joined = MapSet.new(socket.assigns.session.channels)

    popular =
      Autocomplete.list_visible_channels(socket.assigns.session.channels)
      |> Enum.reject(fn ch -> MapSet.member?(joined, ch.name) end)
      |> Enum.sort_by(& &1.user_count, :desc)
      |> Enum.take(10)

    assign(socket, popular_channels: popular, popular_channels_loaded: true)
  end
end
