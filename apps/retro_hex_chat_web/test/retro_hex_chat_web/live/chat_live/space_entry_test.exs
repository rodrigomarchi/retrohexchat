defmodule RetroHexChatWeb.ChatLive.SpaceEntryTest do
  @moduledoc """
  The chat's side of a space that does not live here any more.

  What is left is one fact and one control: which space this conversation has,
  and a control beside the tabs that writes the space's card into it. The
  control has one shape and carries no address at all — the card is the door,
  so nobody walks into a place the conversation was never told about.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.App.SpaceLive
  alias RetroHexChatWeb.ChatLive.SpaceReadModel
  alias RetroHexChatWeb.Live.OpenSurfaces

  defp assigns_of(view), do: :sys.get_state(view.pid).socket.assigns

  describe "the door" do
    test "the conversation in focus offers to put its space in the conversation",
         %{conn: conn} do
      {:ok, view, html} = live(chat_conn(conn, "Sp#{uid()}"), "/chat")

      channel = assigns_of(view).session.active_channel

      assert html =~ ~s(data-testid="space-open")

      # No address on the control: an anchor here would be a second door, and
      # the one it skipped is the conversation. Asserted on the control itself,
      # because the page around it is full of links to elsewhere.
      entry = render(element(view, ~s([data-testid="space-open"])))
      assert entry =~ "<button"
      assert entry =~ ~s(phx-click="space_open")
      refute entry =~ ~s(href="#{Paths.space_path(channel)}")
      refute entry =~ "_blank"
    end

    test "a private conversation offers the space the two of them share", %{conn: conn} do
      nickname = "Sp#{uid()}"
      peer = "Peer#{uid()}"
      {:ok, view, _html} = live(chat_conn(conn, nickname), "/chat")

      render_click(view, "nicklist_dblclick", %{"nick" => peer})

      space = SpaceReadModel.conversation_space(assigns_of(view).session, false)
      assert space.mode == "direct_message"
      assert space.participants == [nickname, peer]

      html = render(view)
      assert html =~ ~s(data-testid="space-open")
      assert html =~ ~s(data-space="#{space.space_id}")
    end

    # Status is not a conversation, so there is no space to offer from it.
    test "the status tab has no space", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Sp#{uid()}"), "/chat")

      render_click(view, "switch_to_status", %{})

      refute render(view) =~ ~s(data-testid="space-open")
      assert SpaceReadModel.conversation_space(assigns_of(view).session, true) == nil
    end

    # Having the space open changes nothing about the control: it was never an
    # address, so there is no second shape for it to become.
    test "an address this person already has open leaves the control alone",
         %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, "Sp#{uid()}"), "/chat")

      channel = assigns_of(view).session.active_channel
      path = Paths.space_path(channel)

      send(view.pid, {:surfaces_changed, [%{kind: SpaceLive, path: path}]})
      html = render(view)

      assert html =~ ~s(data-testid="space-open")
      refute html =~ ~s(data-testid="space-elsewhere")
      refute html =~ ~s(href="#{path}")
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
