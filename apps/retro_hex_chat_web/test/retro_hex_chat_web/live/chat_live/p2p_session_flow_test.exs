defmodule RetroHexChatWeb.ChatLive.P2PSessionFlowTest do
  @moduledoc """
  What the chat does about P2P sessions, which is start them and draw them.

  A session does not live here any more. The chat's part is two acts that must
  not come apart — creating the session and writing its address into the private
  message as a card both people can scroll back to — plus the chrome it draws
  about a session it cannot reach: the PM entry, the tab glyph and the status
  zone. Refusing an invitation stays here too, because refusing is conversation.

  Being *inside* a session is `live/app/p2p_surface_flow_test.exs`, at the
  address that card carries.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Chat.Queries, as: ChatQueries
  alias RetroHexChat.Lobby
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChatWeb.App.Paths

  defp unique_nick(prefix), do: "#{prefix}#{uid()}" |> String.slice(0, 16)

  defp register(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp mount_pair(conn, prefix_a, prefix_b) do
    a = register(unique_nick(prefix_a))
    b = register(unique_nick(prefix_b))

    {:ok, view_a, _} = live(chat_conn(conn, a.nickname, pre_identified: true), "/chat")
    {:ok, view_b, _} = live(chat_conn(conn, b.nickname, pre_identified: true), "/chat")

    %{a: a, b: b, view_a: view_a, view_b: view_b}
  end

  defp flush(view), do: :sys.get_state(view.pid)

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  defp pm_sessions(view), do: assigns(view).p2p_pm_sessions

  defp badge(view, peer_nick), do: Map.get(pm_sessions(view), String.downcase(peer_nick))

  # The invite is a real private message, so it is read where messages live
  # rather than in whatever the reader's screen happens to be rendering.
  defp invite_messages(nick_a, nick_b) do
    nick_a
    |> ChatQueries.list_private_messages(nick_b, limit: 50)
    |> Map.fetch!(:items)
    |> Enum.filter(&(&1.type == "p2p_invite"))
  end

  defp invite(ctx) do
    submit_command_sync(ctx.view_a, "/p2p #{ctx.b.nickname}")
    session = Lobby.active_session_for_user(ctx.a.id)
    assert session, "expected /p2p to create the session and send the invite"
    on_exit(fn -> stop_session_server(session.token) end)
    flush(ctx.view_b)
    session
  end

  defp stop_session_server(token) do
    case RetroHexChat.Lobby.Registry.lookup(token) do
      {:ok, pid} -> GenServer.stop(pid, :normal)
      {:error, :not_found} -> :ok
    end
  catch
    :exit, _reason -> :ok
  end

  describe "starting a session is writing its door into the conversation" do
    test "the invite creates the session and leaves a card carrying its address",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pcs", "p2pct")
      session = invite(ctx)

      assert [message] = invite_messages(ctx.a.nickname, ctx.b.nickname)
      assert message.content =~ Paths.p2p_path(session.token)
      assert message.sender_nickname == ctx.a.nickname
    end

    # Nobody is put inside anything by asking. The creator uses the same door as
    # the person who was asked, which is what keeps a pop-up blocker out of the
    # story: no tab is opened from the click that creates the room.
    test "the creator is not put inside the session by sending the invite", %{conn: conn} do
      ctx = mount_pair(conn, "p2pcu", "p2pcv")
      session = invite(ctx)

      assert {:ok, %{status: "pending"}} = Lobby.get_session(session.token)
      assert badge(ctx.view_a, ctx.b.nickname).state == :invite_sent
      refute render(ctx.view_a) =~ ~s(data-testid="p2p-call-window")
    end

    # The PM entry is the same door, in the shape the toolbar draws.
    test "the PM entry carries the session's own address, in a tab of its own",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pcw", "p2pcx")
      render_click(ctx.view_a, "switch_pm", %{"nickname" => ctx.b.nickname})

      html = render(ctx.view_a)
      assert html =~ ~s(data-p2p-state="idle")
      assert html =~ ~s(phx-click="p2p_start_pm_session")

      render_click(ctx.view_a, "p2p_start_pm_session", %{"peer" => ctx.b.nickname})
      session = Lobby.active_session_for_user(ctx.a.id)
      on_exit(fn -> stop_session_server(session.token) end)

      # The entry never carries the address: the invite card it wrote into the
      # private message is the door, for the host as much as for the peer.
      assert has_element?(ctx.view_a, ~s(button[data-testid="p2p-peer-entry"]))
      refute has_element?(ctx.view_a, ~s(a[data-testid="p2p-peer-entry"]))

      assert has_element?(
               ctx.view_a,
               ~s([data-testid="share-message-enter"][href*="#{Paths.p2p_path(session.token)}"])
             )
    end

    # A door is not a control: nothing on this screen can reach inside a session
    # that is running somewhere else.
    test "the chat draws no control that acts on a session", %{conn: conn} do
      ctx = mount_pair(conn, "p2pcy", "p2pcz")
      invite(ctx)
      render_click(ctx.view_a, "switch_pm", %{"nickname" => ctx.b.nickname})

      html = render(ctx.view_a)
      refute html =~ "p2p_console_select"
      refute html =~ "p2p_statusbar_stop"
      refute html =~ "p2p_accept_invite"
      refute html =~ ~s(data-testid="p2p-call-window")
      refute html =~ ~s(data-window-taskbar="p2p-call")
    end
  end

  describe "the badge follows the session it cannot see" do
    # The chat hears about the session from the session, on this reader's own
    # topic — never from the room, where the negotiation crosses.
    test "the invited peer's conversation grows a badge without joining anything",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pda", "p2pdb")
      session = invite(ctx)

      assert badge(ctx.view_b, ctx.a.nickname).state == :pending_received
      assert badge(ctx.view_b, ctx.a.nickname).token == session.token
      assert {:ok, %{status: "pending"}} = Lobby.get_session(session.token)
    end

    test "the tab glyph moves from invite to connected as the session does", %{conn: conn} do
      ctx = mount_pair(conn, "p2pdc", "p2pdd")
      session = invite(ctx)

      render_click(ctx.view_a, "switch_pm", %{"nickname" => ctx.b.nickname})
      html = render(ctx.view_a)
      assert html =~ ~s(data-testid="tab-p2p-glyph")
      assert html =~ ~s(data-testid="pm-p2p-glyph-#{ctx.b.nickname}")
      assert html =~ ~s(data-p2p-state="pending")

      # Both people take their seats at the session's own address; the chat is
      # told by the session and re-reads the row.
      :ok = Lobby.join_session(session.token, ctx.a.id)
      :ok = Lobby.join_session(session.token, ctx.b.id)

      flush(ctx.view_a)
      assert render(ctx.view_a) =~ ~s(data-p2p-state="connecting")
    end

    test "a session that ends takes its badge with it", %{conn: conn} do
      ctx = mount_pair(conn, "p2pde", "p2pdf")
      session = invite(ctx)

      assert badge(ctx.view_a, ctx.b.nickname)

      :ok = Lobby.cancel_invite(session.token, ctx.a.id)
      flush(ctx.view_a)

      refute badge(ctx.view_a, ctx.b.nickname)
      refute render(ctx.view_a) =~ ~s(data-testid="status-bar-p2p")
    end
  end

  describe "refusing is conversation, and stays here" do
    test "declining closes the session and says so in the private message",
         %{conn: conn} do
      ctx = mount_pair(conn, "p2pdg", "p2pdh")
      session = invite(ctx)

      render_click(ctx.view_b, "p2p_decline_invite", %{"token" => session.token})

      assert {:ok, %{status: "closed", closed_reason: "declined"}} =
               Lobby.get_session(session.token)

      flush(ctx.view_a)
      refute badge(ctx.view_a, ctx.b.nickname)

      assert Enum.any?(
               ctx.a.nickname
               |> ChatQueries.list_private_messages(ctx.b.nickname, limit: 50)
               |> Map.fetch!(:items),
               &(&1.type == "p2p_system" and &1.content =~ "declined")
             )
    end
  end
end
