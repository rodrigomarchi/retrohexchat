defmodule RetroHexChatWeb.PayloadBudgetTest do
  # Not async: the call surface's budget needs a real channel process and a
  # real room, and both are global to the node.
  use RetroHexChatWeb.ConnCase, async: false

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor
  alias RetroHexChat.GroupCall
  alias RetroHexChat.GroupCall.Registry
  alias RetroHexChat.Lobby
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChatWeb.PerfBudgets

  @moduletag :integration

  # A page's first paint costs what its HTML costs: bytes over the wire, then
  # a DOM node per element on the main thread. These are the numbers RUM reads
  # back as `element_render_delay`, so they are asserted here rather than
  # discovered after a deploy.

  describe "/connect" do
    setup %{conn: conn}, do: %{html: html_for(conn, ~p"/connect")}

    test "stays inside its byte budget", %{html: html} do
      assert byte_size(html) <= PerfBudgets.html_bytes(:connect)
    end

    test "stays inside its DOM node budget", %{html: html} do
      assert PerfBudgets.count_elements(html) <= PerfBudgets.dom_nodes(:connect)
    end

    test "references the sprite instead of carrying the drawings", %{html: html} do
      assert PerfBudgets.count(html, "<use href=") == PerfBudgets.count(html, "<svg")
    end
  end

  describe "a help topic" do
    setup %{conn: conn}, do: %{html: html_for(conn, ~p"/chat/help")}

    test "stays inside its byte budget", %{html: html} do
      assert byte_size(html) <= PerfBudgets.html_bytes(:help)
    end

    test "stays inside its DOM node budget", %{html: html} do
      assert PerfBudgets.count_elements(html) <= PerfBudgets.dom_nodes(:help)
    end

    test "references the sprite instead of carrying the drawings", %{html: html} do
      assert PerfBudgets.count(html, "<use href=") == PerfBudgets.count(html, "<svg")
    end
  end

  describe "/play" do
    setup %{conn: conn}, do: %{html: html_for(session_conn(conn), ~p"/play")}

    test "stays inside its byte budget", %{html: html} do
      assert byte_size(html) <= PerfBudgets.html_bytes(:play)
    end

    test "stays inside its DOM node budget", %{html: html} do
      assert PerfBudgets.count_elements(html) <= PerfBudgets.dom_nodes(:play)
    end

    test "references the sprite instead of carrying the drawings", %{html: html} do
      assert PerfBudgets.count(html, "<use href=") == PerfBudgets.count(html, "<svg")
    end
  end

  describe "/call/:token" do
    setup %{conn: conn} do
      {nickname, path} = open_call()
      %{html: html_for(session_conn(conn, nickname), path)}
    end

    test "stays inside its byte budget", %{html: html} do
      assert byte_size(html) <= PerfBudgets.html_bytes(:call)
    end

    test "stays inside its DOM node budget", %{html: html} do
      assert PerfBudgets.count_elements(html) <= PerfBudgets.dom_nodes(:call)
    end

    test "references the sprite instead of carrying the drawings", %{html: html} do
      assert PerfBudgets.count(html, "<use href=") == PerfBudgets.count(html, "<svg")
    end
  end

  describe "/space/:slug" do
    setup %{conn: conn} do
      {nickname, path} = open_space()
      %{html: html_for(session_conn(conn, nickname), path)}
    end

    test "stays inside its byte budget", %{html: html} do
      assert byte_size(html) <= PerfBudgets.html_bytes(:space)
    end

    test "stays inside its DOM node budget", %{html: html} do
      assert PerfBudgets.count_elements(html) <= PerfBudgets.dom_nodes(:space)
    end

    test "references the sprite instead of carrying the drawings", %{html: html} do
      assert PerfBudgets.count(html, "<use href=") == PerfBudgets.count(html, "<svg")
    end
  end

  describe "/p2p/:token" do
    setup %{conn: conn} do
      {nickname, path} = open_p2p_session()
      %{html: html_for(session_conn(conn, nickname), path)}
    end

    test "stays inside its byte budget", %{html: html} do
      assert byte_size(html) <= PerfBudgets.html_bytes(:p2p)
    end

    test "stays inside its DOM node budget", %{html: html} do
      assert PerfBudgets.count_elements(html) <= PerfBudgets.dom_nodes(:p2p)
    end

    test "references the sprite instead of carrying the drawings", %{html: html} do
      assert PerfBudgets.count(html, "<use href=") == PerfBudgets.count(html, "<svg")
    end
  end

  # The same surface, in the form a match arrives in: the device half is gone
  # and the game is in its place, so a budget of its own would be a second
  # ceiling on one page. What this asserts is that the match room is not
  # *bigger* than the room it is a variant of.
  describe "/play/:game/:token" do
    setup %{conn: conn} do
      {nickname, path} = open_match()
      %{html: html_for(session_conn(conn, nickname), path)}
    end

    test "stays inside the P2P surface's byte budget", %{html: html} do
      assert byte_size(html) <= PerfBudgets.html_bytes(:p2p)
    end

    test "stays inside the P2P surface's DOM node budget", %{html: html} do
      assert PerfBudgets.count_elements(html) <= PerfBudgets.dom_nodes(:p2p)
    end

    test "references the sprite instead of carrying the drawings", %{html: html} do
      assert PerfBudgets.count(html, "<use href=") == PerfBudgets.count(html, "<svg")
    end
  end

  # The Start menu is a superset of every menu bar, grey where a screen cannot
  # reach: +177 nodes, +17 KB raw per screen. That is the right trade on the
  # chat's desktop, where every one of those entries leads somewhere. On a
  # single-purpose satellite it is 177 rows that do nothing, four times over —
  # so the satellites carry the way back to the chat and nothing else, and this
  # is the guard that keeps somebody from adding one by reflex.
  #
  # The other side of the contrast is not asserted here: `/chat`'s dead render
  # is only the boot overlay, so its Start menu arrives with the connected
  # render and `start_menu_superset_test.exs` is where it is held to being a
  # superset.
  describe "the satellites' chrome" do
    test "no satellite ships a Start menu or a taskbar", %{conn: conn} do
      {play_nick, play_path} = {register_for_budget().nickname, "/play/hex_pong"}
      {call_nick, call_path} = open_call()
      {space_nick, space_path} = open_space()
      {p2p_nick, p2p_path} = open_p2p_session()

      for {nickname, path} <- [
            {play_nick, play_path},
            {call_nick, call_path},
            {space_nick, space_path},
            {p2p_nick, p2p_path}
          ] do
        html = html_for(session_conn(conn, nickname), path)

        refute html =~ "start-menu-item-", "#{path} ships Start menu entries"
        refute html =~ ~s(data-testid="taskbar"), "#{path} ships a taskbar"
      end
    end
  end

  describe "every surface" do
    test "ships no icon art inline", %{conn: conn} do
      for path <- [~p"/connect", ~p"/chat/help"] do
        html = html_for(conn, path)

        # Everything an icon draws with. A diagram may legitimately use these,
        # but no surface here renders one.
        for tag <- ~w(<rect <polygon <ellipse) do
          assert PerfBudgets.count(html, tag) == 0,
                 "#{path} still inlines icon art (#{tag})"
        end
      end
    end
  end

  defp html_for(conn, path), do: conn |> get(path) |> html_response(200)

  # The call surface is the one budget that cannot be measured from nothing:
  # a token with no room behind it renders a refusal, which is not the page.
  defp open_call do
    nickname = "Budget#{System.unique_integer([:positive])}" |> String.slice(0, 16)

    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    channel = "#budget#{System.unique_integer([:positive])}"
    {:ok, channel_pid} = Supervisor.start_child(channel)
    NickServ.restore_identified(nickname)
    {:ok, _state} = Server.join(channel, nickname, nil, identified: true)

    {:ok, %{token: token}} =
      GroupCall.create_channel_call(channel, %{user_id: nick.id, nickname: nickname})

    on_exit(fn ->
      NickServ.remove_identified(nickname)

      case Registry.lookup_room({:room, token}) do
        {:ok, pid} -> stop_quietly(pid)
        {:error, :not_found} -> :ok
      end

      if Process.alive?(channel_pid), do: Supervisor.stop_child(Supervisor, channel_pid)
    end)

    {nickname, "/call/#{token}"}
  end

  # The space surface is measured at its antechamber, which is the state
  # everyone arrives in and the only one a dead render can show: the canvas
  # exists after a character is chosen, and choosing needs a connected socket.
  defp open_space do
    nickname = "Budget#{System.unique_integer([:positive])}" |> String.slice(0, 16)
    channel = "#budget#{System.unique_integer([:positive])}"
    {:ok, channel_pid} = Supervisor.start_child(channel)
    {:ok, _state} = Server.join(channel, nickname)

    on_exit(fn ->
      if Process.alive?(channel_pid), do: Supervisor.stop_child(Supervisor, channel_pid)
    end)

    {nickname, "/space/" <> RetroHexChatWeb.SpaceRef.slug(channel)}
  end

  # Like the call, this one cannot be measured from nothing: a token with no
  # session behind it renders a refusal, which is not the page.
  defp open_p2p_session do
    creator = register_for_budget()
    peer = register_for_budget()
    NickServ.restore_identified(creator.nickname)

    {:ok, session} = Lobby.create_session(creator.id, peer.id)

    on_exit(fn ->
      NickServ.remove_identified(creator.nickname)

      case Lobby.Registry.lookup(session.token) do
        {:ok, pid} -> stop_quietly(pid)
        {:error, :not_found} -> :ok
      end
    end)

    {creator.nickname, "/p2p/" <> session.token}
  end

  defp open_match do
    creator = register_for_budget()
    NickServ.restore_identified(creator.nickname)

    {:ok, %{session: session}} =
      Lobby.create_open_session(creator.id, metadata: %{"game_id" => "hex_pong"})

    on_exit(fn ->
      NickServ.remove_identified(creator.nickname)

      case Lobby.Registry.lookup(session.token) do
        {:ok, pid} -> stop_quietly(pid)
        {:error, :not_found} -> :ok
      end
    end)

    {creator.nickname, "/play/hex_pong/" <> session.token}
  end

  defp register_for_budget do
    nickname = "Budget#{System.unique_integer([:positive])}" |> String.slice(0, 16)

    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp stop_quietly(pid) do
    GenServer.stop(pid, :normal)
  catch
    :exit, _reason -> :ok
  end

  # A surface refuses a request with no nickname, so measuring one needs a
  # session the way a visitor would have one.
  defp session_conn(conn, nickname \\ "Budget") do
    Plug.Test.init_test_session(conn, %{"chat_nickname" => nickname})
  end
end
