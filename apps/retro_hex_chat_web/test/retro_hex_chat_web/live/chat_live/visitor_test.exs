defmodule RetroHexChatWeb.ChatLive.VisitorTest do
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Accounts.NicknameValidator
  alias RetroHexChat.Channels.{Server, Supervisor}
  alias RetroHexChat.Services.NickServ
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Site.Address

  # A member keeps the lobby up: an unregistered room nobody is in stops when
  # its last visitor leaves, and these tests ask the lobby about its visitors
  # after one has.
  setup do
    {:ok, _pid} = Supervisor.ensure_started("#lobby")
    keeper = "Keeper#{uid()}"
    {:ok, _} = Server.join("#lobby", keeper)
    on_exit(fn -> Server.part("#lobby", keeper) end)
    :ok
  end

  defp open_channel(founder) do
    channel = "#visit-#{uid()}"
    {:ok, pid} = Supervisor.start_child(channel)
    on_exit(fn -> if Process.alive?(pid), do: Supervisor.stop_child(pid) end)
    {:ok, _} = Server.join(channel, founder)
    channel
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  defp guests(channel) do
    {:ok, state} = Server.get_state(channel)
    state.guests
  end

  describe "opening /chat without an account" do
    test "shows the chat on the lobby, read-only, instead of sending them away", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      html = render(view)

      assert html =~ ~s(data-testid="chat-desktop")
      # The same composer a member has, unreachable under the pane that asks.
      assert html =~ ~s(data-testid="chat-input-field")
      assert html =~ ~s(data-testid="visitor-composer")

      [wrapper] =
        html
        |> Floki.parse_document!()
        |> Floki.find("div[inert]:has([data-testid=\"chat-input-field\"])")

      assert wrapper

      %{session: session, visitor_nick: guest_name} = assigns(view)
      assert session.active_channel == "#lobby"
      assert NicknameValidator.guest?(guest_name)
      assert html =~ guest_name
    end

    test "is listed as a guest of the lobby, never as a member", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      guest_name = assigns(view).visitor_nick

      {:ok, state} = Server.get_state("#lobby")
      assert guest_name in state.guests
      refute Enum.any?(state.members, fn {nick, _role} -> nick == guest_name end)
    end

    test "stops being listed when the tab closes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      guest_name = assigns(view).visitor_nick
      ref = Process.monitor(view.pid)

      GenServer.stop(view.pid, :normal)
      assert_receive {:DOWN, ^ref, :process, _pid, _reason}

      refute guest_name in guests("#lobby")
    end

    test "opens the channel a link names", %{conn: conn} do
      channel = open_channel("Host#{uid()}")

      {:ok, view, _html} = live(conn, Address.channel_path(channel))

      assert assigns(view).session.active_channel == channel
      assert assigns(view).visitor_nick in guests(channel)
    end
  end

  describe "moving between channels" do
    test "watches a public channel instead of joining it", %{conn: conn} do
      channel = open_channel("Host#{uid()}")
      {:ok, view, _html} = live(conn, "/")

      render_hook(view, "switch_channel", %{"channel" => channel})

      assert assigns(view).session.active_channel == channel
      {:ok, state} = Server.get_state(channel)
      assert assigns(view).visitor_nick in state.guests
      assert state.member_count == 1
    end

    test "is refused a channel a stranger may not see", %{conn: conn} do
      founder = "Host#{uid()}"
      channel = open_channel(founder)
      :ok = Server.set_mode(channel, founder, "+s")
      {:ok, view, _html} = live(conn, "/")

      render_hook(view, "switch_channel", %{"channel" => channel})

      assert assigns(view).session.active_channel == "#lobby"
      assert guests(channel) == []
    end

    test "closing a channel's tab stops watching it", %{conn: conn} do
      channel = open_channel("Host#{uid()}")
      {:ok, view, _html} = live(conn, "/")
      render_hook(view, "switch_channel", %{"channel" => channel})

      render_hook(view, "close_tab", %{"type" => "channel", "label" => channel})

      refute channel in assigns(view).session.channels
      assert guests(channel) == []
    end

    test "a channel that goes secret closes for the visitor", %{conn: conn} do
      founder = "Host#{uid()}"
      channel = open_channel(founder)
      {:ok, view, _html} = live(conn, "/")
      render_hook(view, "switch_channel", %{"channel" => channel})

      :ok = Server.set_mode(channel, founder, "+s")
      _ = render(view)

      refute channel in assigns(view).session.channels
    end
  end

  describe "any action" do
    test "the sign-in button opens the connect window, returning to the channel",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      view |> element(~s([data-testid="visitor-composer"])) |> render_click()

      assert_patch(view, "/connect?return_to=%2Fc%2Flobby&signup=chat")
      assert render(view) =~ ~s(data-testid="document-window-connect")
      assert connect_window(view).return_to == "/c/lobby"
    end

    test "a deliberate action opens the connect window and does nothing else",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      for {event, params} <- [
            {"nick_right_click", %{"nick" => "someone", "x" => 1, "y" => 1}},
            {"toggle_reaction", %{"message-id" => "1", "emoji" => "👍"}},
            {"toolbar_action", %{"action" => "open_away_dialog"}},
            {"conversations_context_action", %{"action" => "ctx_conversations_leave"}}
          ] do
        render_hook(view, event, params)
        assert assigns(view).focused_doc == :connect, "#{event} did not ask to sign in"
        assert assigns(view).docs[:connect]
        render_patch(view, "/")
      end

      refute "away" in assigns(view).open_windows
      assert assigns(view).session.channels == ["#lobby"]
    end

    test "the sign-in window names the feature that needs an account", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      for {event, params, feature} <- [
            {"open_arcade", %{}, :games},
            {"arcade_select_game", %{"game" => "doom"}, :games},
            {"group_call_open", %{}, :calls},
            {"space_open", %{}, :space},
            {"p2p_start_pm_session", %{"nickname" => "x"}, :p2p},
            {"confirm_open_tab", %{"url" => "https://example.com"}, :links},
            {"visitor_link", %{"feature" => "games"}, :games},
            {"visitor_link", %{"feature" => "anything"}, :feature},
            {"visitor_sign_in", %{}, :chat},
            {"toolbar_action", %{"action" => "open_arcade"}, :games},
            {"toolbar_action", %{"action" => "open_away_dialog"}, :feature}
          ] do
        render_hook(view, event, params)
        assert connect_window(view).feature == feature, "#{event} → #{feature}"
      end

      html = render(view)
      assert html =~ ~s(data-testid="document-window-connect")
      assert html =~ "This feature needs an account."
    end

    test "arriving from a screen that needs an account opens the window, with the way back",
         %{conn: conn} do
      path = Paths.visitor_sign_in_path(:games, "/play/tetris")

      {:ok, view, _html} = live(conn, path)

      assert assigns(view).focused_doc == :connect
      assert connect_window(view).feature == :games
      assert connect_window(view).return_to == "/play/tetris"
      assert render(view) =~ "Games are for registered players."

      # Moving to another channel keeps the way back to the screen they came for.
      render_hook(view, "switch_channel", %{"channel" => "#lobby"})
      assert connect_window(view).return_to == "/play/tetris"
    end

    test "a way back that is not ours goes back to the chat", %{conn: conn} do
      path = Paths.visitor_sign_in_path(:games, "//evil.test/x")

      {:ok, view, _html} = live(conn, path)

      assert connect_window(view).return_to == "/"
    end

    test "holds every link not open to everybody", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      html = render(view)

      [allow] =
        html
        |> Floki.parse_document!()
        |> Floki.find("#visitor-link-guard")
        |> Floki.attribute("data-allow")

      allow = Jason.decode!(allow)
      assert "/" in allow
      assert "/c/" in allow
      assert "/connect" in allow
      assert "/chat/help/" in allow
      refute Enum.any?(allow, &String.starts_with?(&1, "/play"))
      refute "/chat/" in allow
    end

    test "gets no always-mounted tool window, nor its taskbar button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")
      html = render(view)

      for id <- ["url-catcher", "channel-central"] do
        refute html =~ ~s(data-window-id="#{id}")
        refute html =~ ~s(data-window-taskbar="#{id}")
      end
    end

    test "mounts no tool window the window manager asks for", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      render_hook(view, "window_open", %{"id" => "address-book"})

      refute "address-book" in assigns(view).open_windows
      refute Map.has_key?(assigns(view).docs, :connect)
    end

    test "what the browser reports on its own asks nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      render_hook(view, "tips_seen", %{"tips" => ["first_join"]})
      render_hook(view, "window_keydown", %{"key" => "a"})

      refute Map.has_key?(assigns(view).docs, :connect)
    end
  end

  describe "members" do
    test "see the visitors watching their channel, apart from the members", %{conn: conn} do
      member = "Member#{uid()}"
      {:ok, member_view, _html} = conn |> chat_conn(member) |> live("/")
      {:ok, visitor_view, _html} = build_conn() |> live("/")
      guest_name = assigns(visitor_view).visitor_nick

      _ = render(member_view)

      assert guest_name in Map.get(assigns(member_view).channel_guests, "#lobby", [])
    end
  end

  describe "reading" do
    test "a server emoji is served to a visitor" do
      conn = get(build_conn(), "/chat/emoji/999999999")
      assert conn.status == 404
      refute redirected_to_connect?(conn)
    end
  end

  defp redirected_to_connect?(conn),
    do: conn.status in [301, 302] and get_resp_header(conn, "location") == ["/connect"]

  describe "guest names" do
    test "cannot be registered" do
      assert {:error, _} = NickServ.register("Guest4242", "pass12345")
    end

    test "cannot be taken as a plain nickname", %{conn: conn} do
      conn = post(conn, ~p"/chat/session", %{"nickname" => "guest77"})
      assert redirected_to(conn) == "/connect"
    end
  end

  defp connect_window(view), do: assigns(view).docs[:connect].assigns
end
