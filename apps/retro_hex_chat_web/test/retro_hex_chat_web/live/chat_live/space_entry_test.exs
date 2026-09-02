defmodule RetroHexChatWeb.ChatLive.SpaceEntryTest do
  @moduledoc """
  The chat's side of a space that does not live here any more.

  What is left is one fact and one control: which space this conversation has,
  and a door to it beside the tabs. The door has two shapes and no third,
  because a space is a place — there is nothing to create, and the address is
  good whether anybody is standing in it or not.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.App.SpaceLive
  alias RetroHexChatWeb.ChatLive.SpaceReadModel
  alias RetroHexChatWeb.Live.OpenSurfaces

  defp assigns_of(view), do: :sys.get_state(view.pid).socket.assigns

  describe "the door" do
    test "the conversation in focus offers its space in a tab of its own", %{conn: conn} do
      {:ok, view, html} = live(chat_conn(conn, "Sp#{uid()}"), "/chat")

      channel = assigns_of(view).session.active_channel
      path = Paths.space_path(channel)

      assert html =~ ~s(data-testid="space-open")
      assert html =~ ~s(href="#{path}")
      assert html =~ ~s(target="_blank")
    end

    test "a private conversation offers the space the two of them share", %{conn: conn} do
      nickname = "Sp#{uid()}"
      peer = "Peer#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nickname), "/chat")

      render_click(view, "nicklist_dblclick", %{"nick" => peer})

      space = SpaceReadModel.conversation_space(assigns_of(view).session, false)
      assert space.mode == "direct_message"
      assert space.participants == [nickname, peer]
      assert render(view) =~ ~s(href="#{Paths.space_path(space.space_id)}")
    end

    # Status is not a conversation, so there is no space to offer from it.
    test "the status tab has no space", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Sp#{uid()}"), "/chat")

      render_click(view, "switch_to_status", %{})

      refute render(view) =~ ~s(data-testid="space-open")
      assert SpaceReadModel.conversation_space(assigns_of(view).session, true) == nil
    end

    # A second tab of a world you are already in is a second character nobody
    # asked for, so the door becomes a way to the tab that holds it.
    test "an address this person already has open is a way to that tab", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Sp#{uid()}"), "/chat")

      channel = assigns_of(view).session.active_channel
      path = Paths.space_path(channel)

      send(view.pid, {:surfaces_changed, [%{kind: SpaceLive, path: path}]})
      html = render(view)

      assert html =~ ~s(data-testid="space-elsewhere")
      refute html =~ ~s(data-testid="space-open")
    end
  end

  describe "what the chat no longer holds" do
    test "the space is not a tab and not a child of the chat", %{conn: conn} do
      {:ok, view, html} = live(chat_conn(conn, "Sp#{uid()}"), "/chat")

      refute html =~ ~s(data-tab-type="space")
      refute Enum.any?(live_children(view), &(&1.module == SpaceLive))
    end
  end

  describe "the surface registry" do
    test "an open space is one of this person's surfaces", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Sp#{uid()}"), "/chat")
      channel = assigns_of(view).session.active_channel

      assert OpenSurfaces.open?(
               MapSet.new([Paths.space_path(channel)]),
               Paths.space_path(channel)
             )
    end
  end
end
