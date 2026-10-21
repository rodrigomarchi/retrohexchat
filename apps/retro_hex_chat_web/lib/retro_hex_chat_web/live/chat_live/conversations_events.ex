defmodule RetroHexChatWeb.ChatLive.ConversationsEvents do
  @moduledoc """
  Handle conversations sidebar events.

  Covers: conversations_toggle_section, conversations_join_popular,
  conversations_browse_all, conversations_browse_category.

  Attached as `attach_hook(:conversations_events, :handle_event, ...)` in ChatLive.mount/3.
  Returns `{:halt, socket}` when the event is handled, `{:cont, socket}` otherwise.
  """

  import Phoenix.Component, only: [assign: 2]

  alias RetroHexChatWeb.ChatLive.ChannelListEvents
  alias RetroHexChatWeb.ChatLive.ConversationsReadModel
  alias RetroHexChatWeb.ChatLive.Helpers

  # The sections whose rooms are read from the directory when they open.
  @suggestion_sections ["popular" | ConversationsReadModel.featured_categories()]

  # ── Section toggle ─────────────────────────────────────────

  def handle_event("conversations_toggle_section", %{"section" => section_str}, socket) do
    section = String.to_existing_atom(section_str)
    sections = socket.assigns.conversations_sections
    new_expanded = !Map.get(sections, section, false)
    updated_sections = Map.put(sections, section, new_expanded)

    socket = assign(socket, conversations_sections: updated_sections)

    socket =
      if new_expanded and section_str in @suggestion_sections do
        ConversationsReadModel.load_discovery(socket)
      else
        socket
      end

    {:halt, socket}
  end

  # ── Join a popular channel ─────────────────────────────────

  def handle_event("conversations_join_popular", %{"channel" => channel}, socket) do
    {:halt, Helpers.join_channel(socket, channel, socket.assigns.session)}
  end

  # ── Browse all channels ────────────────────────────────────

  def handle_event("conversations_browse_all", _params, socket) do
    {:halt, ChannelListEvents.open(socket)}
  end

  # A featured section's "see more": every room about its subject, in the
  # Channel List, where the rest of them can be searched.
  def handle_event("conversations_browse_category", %{"category" => category}, socket) do
    {:halt, ChannelListEvents.open(socket, category: category)}
  end

  # ── Catch-all ──────────────────────────────────────────────

  def handle_event(_event, _params, socket), do: {:cont, socket}
end
