defmodule RetroHexChatWeb.ChatLive.SpaceSurfaceTest do
  @moduledoc """
  The space inside the chat, now that it is a child LiveView.

  The chat kept one fact — this conversation has a space — and gave away the
  rest. What is left to assert on this side is the seam: that the tab still
  mounts the surface, that switching conversation mounts a different one, and
  that the two things the surface reports upward land where the chat can act on
  them.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChatWeb.App.SpaceLive
  alias RetroHexChatWeb.ChatLive.SpaceEvents
  alias RetroHexChatWeb.ChatLive.SpaceReadModel
  alias RetroHexChatWeb.SpaceRef

  defp space_view(view) do
    _rendered = render(view)
    Enum.find(live_children(view), &(&1.module == SpaceLive))
  end

  defp open_space(view) do
    render_click(view, "switch_tab", %{"type" => "space", "label" => "Space"})
    space_view(view)
  end

  defp assigns_of(view), do: :sys.get_state(view.pid).socket.assigns

  describe "the seam" do
    test "the Space tab mounts the surface for the conversation in focus", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Sp#{uid()}"), "/chat")

      refute space_view(view), "the space is not mounted until its tab is opened"

      space = open_space(view)
      assert space

      channel = assigns_of(view).session.active_channel
      assert assigns_of(space).space.id == channel
      assert assigns_of(space).space.dom_id == SpaceRef.dom_id(channel)
      assert assigns_of(space).embedded?
    end

    test "switching to a private conversation mounts that conversation's space", %{conn: conn} do
      nickname = "Sp#{uid()}"
      peer = "Peer#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nickname), "/chat")

      render_click(view, "nicklist_dblclick", %{"nick" => peer})
      space = open_space(view)

      assert assigns_of(space).space.mode == "direct_message"
      assert assigns_of(space).space.participants == [nickname, peer]
    end

    # Leaving the space takes the surface off the screen, and with it the
    # chosen character — which is what makes the picker show again.
    test "leaving the space unmounts it", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Sp#{uid()}"), "/chat")

      assert open_space(view)
      render_click(view, "switch_tab", %{"type" => "channel", "label" => "#lobby"})

      refute space_view(view)
    end
  end

  describe "what the surface reports upward" do
    test "the character you picked is remembered for the next visit", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Sp#{uid()}"), "/chat")

      space = open_space(view)
      render_click(space, "space_select_avatar", %{"avatar" => "monk"})

      # The chat is what outlives the visit, so the chat is what remembers.
      _rendered = render(view)
      assert assigns_of(view).space_last_avatar == "monk"

      render_click(view, "switch_tab", %{"type" => "channel", "label" => "#lobby"})
      reopened = open_space(view)

      assert assigns_of(reopened).avatar == nil
      assert assigns_of(reopened).last_avatar == "monk"

      assert has_element?(
               reopened,
               ~s([data-testid="space-avatar-monk"][aria-pressed="true"])
             )
    end

    # The canvas reports a hovered character to the LiveView that owns its
    # element, which is the space. What it means is the chat's hover card, so
    # the chat has to claim it — and has to claim nothing else, or the space
    # would reach every handler the chat has.
    test "the chat claims what the canvas says about a nickname, and only that", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Sp#{uid()}"), "/chat")
      socket = :sys.get_state(view.pid).socket

      for event <- ~w(nick_hover nick_hover_dismiss nick_right_click) do
        assert {:halt, _socket} =
                 SpaceEvents.handle_info(
                   {:space_surface_event, event, %{"nick" => "ana"}},
                   socket
                 )
      end

      assert {:cont, _socket} =
               SpaceEvents.handle_info(
                 {:space_surface_event, "switch_channel", %{"channel" => "#elsewhere"}},
                 socket
               )

      assert {:cont, _socket} = SpaceEvents.handle_info({:something_else, :entirely}, socket)
    end
  end

  describe "what the chat kept" do
    test "knowing that a conversation has a space at all", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Sp#{uid()}"), "/chat")
      session = assigns_of(view).session

      assert SpaceReadModel.has_space?(session)

      # The Status tab is not a conversation, so it has no space — and the tab
      # bar keeps the space entry anyway, because which tabs exist follows what
      # is in focus rather than what you are looking at.
      assert SpaceReadModel.conversation_space(session, true) == nil
    end
  end
end
