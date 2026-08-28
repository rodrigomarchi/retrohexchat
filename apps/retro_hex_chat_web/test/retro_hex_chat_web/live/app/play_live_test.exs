defmodule RetroHexChatWeb.App.PlayLiveTest do
  @moduledoc """
  The first surface that is not the chat, and the coexistence it has to prove.

  Most of what is asserted here is about `Live.Surface` rather than about games:
  a second tab of this app must survive the chat being taken over, must not
  survive a ban, and must not touch the presence or the channel membership that
  belong to the chat session.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Admin.ServerBans
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.SessionControl
  alias RetroHexChat.Topics

  describe "who may open it" do
    test "no session goes to connect", %{conn: conn} do
      assert redirected_to_connect(live(conn, ~p"/play"))
    end

    test "a nickname the validator refuses goes to connect", %{conn: conn} do
      assert redirected_to_connect(conn |> chat_conn("not a nick") |> live(~p"/play"))
    end

    test "a banned nickname goes to connect saying so", %{conn: conn} do
      nick = "Ban#{uid()}"
      {:ok, _msg} = ServerBans.ban(nick, "admin", "testing", nil)

      assert {:error, {_kind, %{to: to}}} = conn |> chat_conn(nick) |> live(~p"/play")
      assert to =~ "/connect"
      assert to =~ "banned"
    end

    test "a valid session gets the library", %{conn: conn} do
      {:ok, _view, html} = conn |> chat_conn("Play#{uid()}") |> live(~p"/play")

      assert html =~ "retro-games-panel"
    end
  end

  describe "coexistence with the chat" do
    # The whole point of the surface. ChatLive announces a takeover on the
    # person's inbox when it mounts; a surface must not, or opening a game
    # would end the chat that opened it.
    test "opening it does not announce a takeover", %{conn: conn} do
      nick = "Coex#{uid()}"
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(nick))

      {:ok, _view, _html} = conn |> chat_conn(nick) |> live(~p"/play")

      refute_receive {:force_disconnect, _payload}
    end

    # Global presence is owned by the chat session and released by its
    # terminate. A surface that tracked would make closing the game tab look
    # like going offline.
    test "opening it does not put the person online", %{conn: conn} do
      nick = "Pres#{uid()}"

      {:ok, _view, _html} = conn |> chat_conn(nick) |> live(~p"/play")

      refute Tracker.online?(Topics.presence(), nick)
    end

    test "a chat takeover leaves it running", %{conn: conn} do
      nick = "Keep#{uid()}"
      {:ok, view, _html} = conn |> chat_conn(nick) |> live(~p"/play")

      SessionControl.disconnect(nick, %{reason: "another window"}, :chat)

      # render/1 is a synchronous round trip, and the broadcast queued before
      # it — so if the surface were going to act on that message, it already
      # would have. No sleep, no retry.
      assert render(view) =~ "retro-games-panel"
    end

    test "a ban ends it", %{conn: conn} do
      nick = "Gone#{uid()}"
      {:ok, view, _html} = conn |> chat_conn(nick) |> live(~p"/play")

      SessionControl.disconnect(nick, %{reason: "Server banned"}, :all)

      assert {to, _flash} = assert_redirect(view)
      assert to =~ "/chat/session/clear"
      assert to =~ "Server+banned"
    end
  end

  describe "choosing a game" do
    test "a known game in the path opens it", %{conn: conn} do
      {:ok, _view, html} = conn |> chat_conn("Pick#{uid()}") |> live(~p"/play/hex_pong")

      assert html =~ "RetroGameCanvasHook"
    end

    test "an unknown game falls back to the library", %{conn: conn} do
      {:ok, _view, html} = conn |> chat_conn("Miss#{uid()}") |> live(~p"/play/not_a_game")

      assert html =~ "retro-games-panel"
      refute html =~ "RetroGameCanvasHook"
    end
  end

  defp redirected_to_connect({:error, {_kind, %{to: to}}}), do: to == "/connect"
  defp redirected_to_connect(_other), do: false
end
