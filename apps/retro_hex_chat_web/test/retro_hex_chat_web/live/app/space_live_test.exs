defmodule RetroHexChatWeb.App.SpaceLiveTest do
  @moduledoc """
  A space at an address of its own.

  The only place a space is rendered, so everything about one is asserted here:
  the address it resolves from, every gate applied at it, a refusal that names
  the door that was shut, and walking in.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Accounts.Avatars
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.ShareLinks
  alias RetroHexChat.Topics
  alias RetroHexChat.VirtualSpace
  alias RetroHexChat.VirtualSpace.ChannelJoinToken
  alias RetroHexChat.VirtualSpace.DirectMessageSpace
  alias RetroHexChat.VirtualSpace.Registry
  alias RetroHexChatWeb.SpaceRef

  defp start_channel(nickname) do
    channel = "#space#{uid()}"
    {:ok, channel_pid} = Supervisor.start_child(channel)

    on_exit(fn ->
      if Process.alive?(channel_pid) do
        Supervisor.stop_child(RetroHexChat.Channels.Supervisor, channel_pid)
      end
    end)

    {:ok, _state} = Server.join(channel, nickname)
    channel
  end

  defp stop_space(space_id) do
    on_exit(fn ->
      case Registry.lookup({:channel_space, space_id}) do
        {:ok, pid} -> GenServer.stop(pid, :normal)
        {:error, :not_found} -> :ok
      end
    end)
  end

  defp path(space_id), do: "/space/" <> SpaceRef.slug(space_id)

  defp redirected_to_connect({:error, {_kind, %{to: to}}}), do: to == "/connect"
  defp redirected_to_connect(_other), do: false

  describe "who may open it" do
    test "no session goes to connect", %{conn: conn} do
      assert redirected_to_connect(live(conn, path("#nowhere")))
    end

    test "a slug that decodes to nothing says so instead of rendering a map", %{conn: conn} do
      {:ok, _view, html} = conn |> chat_conn("Lost#{uid()}") |> live("/space/not-a-slug")

      assert html =~ ~s(data-testid="space-denied")
      assert html =~ "does not name a space"
    end

    test "someone who is not in the channel is told which door is shut", %{conn: conn} do
      nickname = "In#{uid()}" |> String.slice(0, 16)
      outsider = "Out#{uid()}" |> String.slice(0, 16)
      channel = start_channel(nickname)

      {:ok, _view, html} = conn |> chat_conn(outsider) |> live(path(channel))

      assert html =~ ~s(data-testid="space-denied")
      assert html =~ channel
      refute html =~ ~s(data-testid="space-character-select")
    end

    # A private space has no membership record: its id *is* the pair, so the
    # address itself says who may open it.
    test "a private space refuses a third nickname", %{conn: conn} do
      space_id = DirectMessageSpace.space_id("ana#{uid()}", "bob#{uid()}")
      stranger = "Cara#{uid()}" |> String.slice(0, 16)

      {:ok, _view, html} = conn |> chat_conn(stranger) |> live(path(space_id))

      assert html =~ ~s(data-testid="space-denied")
      assert html =~ "two other people"
    end

    # The address folds the pair to lowercase; the screen still says each of
    # them the way they write their own name.
    test "a private space names its two as they spell themselves", %{conn: _conn} do
      ana = register_nick("Ana")
      bob = register_nick("Bob")
      space_id = DirectMessageSpace.space_id(ana, bob)

      {:ok, _view, html} = build_conn() |> chat_conn(ana) |> live(path(space_id))

      assert html =~ ana
      assert html =~ bob
      refute html =~ String.downcase(ana) <> " + "
    end

    test "a private space opens for either of its two", %{conn: _conn} do
      ana = "ana#{uid()}" |> String.slice(0, 16)
      bob = "bob#{uid()}" |> String.slice(0, 16)
      space_id = DirectMessageSpace.space_id(ana, bob)

      for nickname <- [ana, bob] do
        {:ok, _view, html} = build_conn() |> chat_conn(nickname) |> live(path(space_id))
        assert html =~ ~s(data-testid="space-character-select")
      end
    end
  end

  describe "the antechamber" do
    setup %{conn: conn} do
      nickname = "Walk#{uid()}" |> String.slice(0, 16)
      channel = start_channel(nickname)
      stop_space(channel)
      %{nickname: nickname, channel: channel, conn: chat_conn(conn, nickname)}
    end

    # The class of bug this guards is invisible to ExUnit anywhere else: a
    # surface whose first state arrives by a message after the mount renders
    # empty in a browser and correct in a test.
    test "is the first render, not something that arrives after it", %{
      conn: conn,
      channel: channel
    } do
      {:ok, view, html} = live(conn, path(channel))

      assert html =~ ~s(data-testid="space-character-select")
      refute html =~ ~s(data-testid="channel-space-shell")
      assert :sys.get_state(view.pid).socket.assigns.avatar == nil
    end

    # A space is a place: it has no host, nothing to start, and no waiting.
    test "has no host and nothing to start", %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, path(channel))

      refute html =~ "Start"
      assert html =~ ~s(data-testid="space-back-to-chat")
    end

    test "says who is inside right now", %{conn: conn, channel: channel, nickname: nickname} do
      {:ok, _joined} =
        VirtualSpace.join_channel_space(channel, %{user_id: nil, nickname: nickname})

      {:ok, view, _html} = live(conn, path(channel))

      assert has_element?(view, ~s([data-testid="space-roster-names"]), nickname)
    end

    test "an empty space says so rather than breaking", %{conn: _conn} do
      ana = "ana#{uid()}" |> String.slice(0, 16)
      bob = "bob#{uid()}" |> String.slice(0, 16)
      space_id = DirectMessageSpace.space_id(ana, bob)

      {:ok, view, _html} = build_conn() |> chat_conn(ana) |> live(path(space_id))

      assert has_element?(view, ~s([data-testid="space-roster"]), "Nobody is in here yet")
    end

    # The address is the place, so a tab that already is the space has nothing
    # to open in a tab of its own. Filling the screen is a different question:
    # a maximized window is still inside browser chrome.
    test "offers no tab of its own when it already is one", %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, path(channel))

      refute has_element?(view, ~s([data-testid="space-open-in-tab"]))
    end

    test "remembers the character this browser picked last time", %{
      conn: conn,
      channel: channel
    } do
      {:ok, view, _html} = live(conn, path(channel))

      # The browser is what remembers, so the browser is what says so — the
      # server renders its default first and moves the highlight when told.
      render_hook(view, "space_remember_avatar", %{"avatar" => "monk"})

      assert has_element?(view, ~s([data-testid="space-avatar-monk"][aria-pressed="true"]))
      assert :sys.get_state(view.pid).socket.assigns.avatar == nil
    end

    # The chat draws the saved character beside the nickname, so a picker that
    # started anywhere else in a fresh browser would be offering a stranger.
    test "starts on the character the nickname chose, whatever the browser remembers", %{
      conn: conn
    } do
      nickname = register_nick("Saved")
      channel = start_channel(nickname)
      stop_space(channel)
      :ok = Avatars.remember(nickname, "archer")

      {:ok, view, _html} = conn |> chat_conn(nickname) |> live(path(channel))

      assert has_element?(view, ~s([data-testid="space-avatar-archer"][aria-pressed="true"]))

      render_hook(view, "space_remember_avatar", %{"avatar" => "monk"})

      assert has_element?(view, ~s([data-testid="space-avatar-archer"][aria-pressed="true"]))
    end

    test "a remembered character this build no longer has is ignored", %{
      conn: conn,
      channel: channel
    } do
      {:ok, view, _html} = live(conn, path(channel))

      render_hook(view, "space_remember_avatar", %{"avatar" => "dragon_lord"})

      assert :sys.get_state(view.pid).socket.assigns.last_avatar == "hero"
    end
  end

  describe "walking in" do
    setup %{conn: conn} do
      nickname = "Walk#{uid()}" |> String.slice(0, 16)
      channel = start_channel(nickname)
      stop_space(channel)
      %{nickname: nickname, channel: channel, conn: chat_conn(conn, nickname)}
    end

    test "choosing a character is entering, and mints the token the channel checks", %{
      conn: conn,
      channel: channel,
      nickname: nickname
    } do
      {:ok, view, _html} = live(conn, path(channel))

      html = view |> element(~s([data-testid="space-avatar-knight"])) |> render_click()

      assert html =~ ~s(data-testid="channel-space-shell")
      assert html =~ ~s(data-avatar="knight")

      token = :sys.get_state(view.pid).socket.assigns.join_token

      assert {:ok, data} = ChannelJoinToken.verify(token)
      assert data.space_kind == "channel"
      assert data.channel_name == channel
      assert data.nickname == nickname
    end

    test "a private space mints the token its own channel checks", %{conn: _conn} do
      ana = "ana#{uid()}" |> String.slice(0, 16)
      bob = "bob#{uid()}" |> String.slice(0, 16)
      space_id = DirectMessageSpace.space_id(ana, bob)

      {:ok, view, _html} = build_conn() |> chat_conn(ana) |> live(path(space_id))

      view |> element(~s([data-testid="space-avatar-hero"])) |> render_click()

      token = :sys.get_state(view.pid).socket.assigns.join_token

      assert {:ok, data} = ChannelJoinToken.verify(token)
      assert data.space_kind == "direct_message"
      assert data.space_id == space_id
      assert Enum.sort(data.participants) == Enum.sort([ana, bob])
    end

    # The token is what tells the space's channel who walked in, and a nil id
    # there is a registered person entering as a guest: no card in the
    # conversation, and nothing anywhere saying why.
    test "the token carries the registered nickname's own id", %{conn: conn} do
      nickname = register_nick("Ident")
      channel = start_channel(nickname)
      stop_space(channel)

      {:ok, view, _html} = conn |> chat_conn(nickname) |> live(path(channel))
      view |> element(~s([data-testid="space-avatar-hero"])) |> render_click()

      token = :sys.get_state(view.pid).socket.assigns.join_token
      assert {:ok, data} = ChannelJoinToken.verify(token)
      assert is_integer(data.user_id)
    end

    test "an avatar outside the roster changes nothing", %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, path(channel))

      render_click(view, "space_select_avatar", %{"avatar" => "dragon_lord"})

      assert :sys.get_state(view.pid).socket.assigns.avatar == nil
      assert has_element?(view, ~s([data-testid="space-character-select"]))
    end

    # The element id is a contract with `SpaceCanvasHook` and with four
    # Playwright specs. Changing how it is spelled breaks all of them silently.
    test "the shell keeps the element id the hook looks for", %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, path(channel))

      html = view |> element(~s([data-testid="space-avatar-hero"])) |> render_click()

      assert html =~ ~s(id="conversation-space-#{SpaceRef.slug(channel)}")
    end
  end

  describe "saying something" do
    setup %{conn: conn} do
      nickname = "Talk#{uid()}" |> String.slice(0, 16)
      channel = start_channel(nickname)
      stop_space(channel)
      %{nickname: nickname, channel: channel, conn: chat_conn(conn, nickname)}
    end

    defp walk_in(view, avatar \\ "hero") do
      view |> element(~s([data-testid="space-avatar-#{avatar}"])) |> render_click()
    end

    test "there is nothing to type in before you have walked in", %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, path(channel))

      refute has_element?(view, ~s([data-testid="space-say-bar"]))
      walk_in(view)
      assert has_element?(view, ~s([data-testid="space-say-input"][placeholder*="#{channel}"]))
    end

    test "a line goes to the channel and the field empties", %{
      conn: conn,
      channel: channel,
      nickname: nickname
    } do
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(channel))
      {:ok, view, _html} = live(conn, path(channel))
      walk_in(view)

      view |> form(~s([data-testid="space-say-form"]), %{text: "hi all"}) |> render_change()
      view |> form(~s([data-testid="space-say-form"]), %{text: "hi all"}) |> render_submit()

      assert_receive %{event: "new_message", payload: %{author: ^nickname, content: "hi all"}}
      assert :sys.get_state(view.pid).socket.assigns.say_draft == ""
      refute has_element?(view, ~s([data-testid="space-say-error"]))
    end

    test "a refused line stays in the field with the reason under it", %{
      conn: conn,
      channel: channel
    } do
      {:ok, view, _html} = live(conn, path(channel))
      walk_in(view)

      html =
        view |> form(~s([data-testid="space-say-form"]), %{text: "/part"}) |> render_submit()

      assert html =~ ~s(data-testid="space-say-error")
      assert html =~ "/me"
      assert :sys.get_state(view.pid).socket.assigns.say_draft == "/part"
    end

    test "in a private space the line goes to the other person", %{conn: _conn} do
      ana = "ana#{uid()}" |> String.slice(0, 16)
      bob = "bob#{uid()}" |> String.slice(0, 16)
      space_id = DirectMessageSpace.space_id(ana, bob)
      stop_space(space_id)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(bob))

      {:ok, view, _html} = build_conn() |> chat_conn(ana) |> live(path(space_id))
      walk_in(view)

      assert has_element?(view, ~s([data-testid="space-say-input"][placeholder*="#{bob}"]))

      view |> form(~s([data-testid="space-say-form"]), %{text: "psst"}) |> render_submit()

      assert_receive %{event: "new_pm", payload: %{sender: ^ana, content: "psst"}}
    end
  end

  describe "changing character inside" do
    setup %{conn: conn} do
      nickname = "Swap#{uid()}" |> String.slice(0, 16)
      channel = start_channel(nickname)
      stop_space(channel)
      %{nickname: nickname, channel: channel, conn: chat_conn(conn, nickname)}
    end

    test "is offered only once you are inside", %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, path(channel))
      refute has_element?(view, ~s([data-testid="space-change-character"]))

      view |> element(~s([data-testid="space-avatar-hero"])) |> render_click()
      assert has_element?(view, ~s([data-testid="space-change-character"]))
    end

    # The canvas stays mounted: changing clothes is not leaving the room, and a
    # remount would end the gathering for somebody who was alone in it.
    test "reopens the picker over the running map and hands the choice to the canvas", %{
      conn: conn,
      channel: channel
    } do
      {:ok, view, _html} = live(conn, path(channel))
      view |> element(~s([data-testid="space-avatar-hero"])) |> render_click()
      token = :sys.get_state(view.pid).socket.assigns.join_token

      view |> element(~s([data-testid="space-change-character"])) |> render_click()

      assert has_element?(view, ~s([data-testid="space-character-select"]))
      assert has_element?(view, ~s([data-testid="channel-space-shell"]))
      assert has_element?(view, ~s([data-testid="space-avatar-hero"][aria-pressed="true"]))

      view |> element(~s([data-testid="space-avatar-knight"])) |> render_click()

      assert_push_event(view, "space_change_avatar", %{avatar: "knight"})
      refute has_element?(view, ~s([data-testid="space-character-select"]))
      assert has_element?(view, ~s([data-testid="channel-space-shell"]))
      assert :sys.get_state(view.pid).socket.assigns.join_token == token
    end

    test "cancel leaves the character as it was", %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, path(channel))
      view |> element(~s([data-testid="space-avatar-monk"])) |> render_click()

      view |> element(~s([data-testid="space-change-character"])) |> render_click()
      view |> element(~s([data-testid="space-change-cancel"])) |> render_click()

      refute has_element?(view, ~s([data-testid="space-character-select"]))
      assert :sys.get_state(view.pid).socket.assigns.avatar == "monk"
    end
  end

  describe "sharing the address" do
    test "mints a link that resolves back to this space", %{conn: conn} do
      nickname = register_nick("Share")
      channel = start_channel(nickname)
      stop_space(channel)

      {:ok, view, _html} = conn |> chat_conn(nickname) |> live(path(channel))

      render_click(view, "share_space", %{})

      url = :sys.get_state(view.pid).socket.assigns.share_url
      assert is_binary(url)

      slug = url |> String.split("/join/") |> List.last()
      assert {:ok, resolution} = ShareLinks.resolve(slug)
      assert resolution.kind == "space"
      assert resolution.target["space_id"] == channel
      assert resolution.live?
    end

    test "an unregistered nickname is told why it cannot", %{conn: conn} do
      nickname = "Anon#{uid()}" |> String.slice(0, 16)
      channel = start_channel(nickname)
      stop_space(channel)

      {:ok, view, _html} = conn |> chat_conn(nickname) |> live(path(channel))

      assert has_element?(view, ~s([data-testid="share-bar"]), "Register your nickname")
      render_click(view, "share_space", %{})
      assert :sys.get_state(view.pid).socket.assigns.share_url == nil
    end
  end

  describe "the roster keeps itself current" do
    test "somebody arriving appears at the door without a reload", %{conn: conn} do
      nickname = "Live#{uid()}" |> String.slice(0, 16)
      channel = start_channel(nickname)
      stop_space(channel)

      # Somebody is standing in the space, so the world has a process and the
      # roster is a live thing rather than a cold read of the channel.
      {:ok, _joined} =
        VirtualSpace.join_channel_space(channel, %{user_id: nil, nickname: nickname})

      {:ok, view, _html} = conn |> chat_conn(nickname) |> live(path(channel))
      assert VirtualSpace.roster(channel) == [nickname]

      # Wait for the roster message itself rather than for a render: the arrival
      # travels channel server → space server → topic → surface, and asserting
      # on a render straight after the join is asserting that three hops already
      # happened.
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.space_roster(channel))

      other = "Peer#{uid()}" |> String.slice(0, 16)
      {:ok, _state} = Server.join(channel, other)

      assert_receive {:space_roster, %{participants: participants}}, 2_000
      assert other in participants

      # The surface has the same message queued behind the one just received, so
      # a synchronous call to it is what makes the render current.
      assert other in :sys.get_state(view.pid).socket.assigns.roster
      assert render(view) =~ other
    end

    # Nobody has opened the space, so there is nobody in it. The members of the
    # channel it hangs off are not people standing in a room, and saying they
    # were would put a crowd at the door of an empty world.
    test "a space nobody has opened says nobody is in it", %{conn: conn} do
      nickname = "Cold#{uid()}" |> String.slice(0, 16)
      channel = start_channel(nickname)

      {:ok, view, _html} = conn |> chat_conn(nickname) |> live(path(channel))

      assert VirtualSpace.roster(channel) == []
      assert has_element?(view, ~s([data-testid="space-roster"]), "Nobody is in here yet")
    end
  end

  describe "the gate to the Construct" do
    setup %{conn: conn} do
      nickname = "Gate#{uid()}" |> String.slice(0, 16)
      channel = start_channel(nickname)
      stop_space(channel)
      %{nickname: nickname, channel: channel, conn: chat_conn(conn, nickname)}
    end

    test "walking through it carries the character to the Construct's own address", %{
      conn: conn,
      channel: channel
    } do
      {:ok, view, _html} = live(conn, path(channel))
      view |> element(~s([data-testid="space-avatar-knight"])) |> render_click()

      assert {:error, {:live_redirect, %{to: to}}} = render_hook(view, "space_portal", %{})
      assert to == path(VirtualSpace.construct_id(channel)) <> "?avatar=knight"
    end

    test "is not a door before a character is chosen", %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, path(channel))

      render_hook(view, "space_portal", %{})
      assert has_element?(view, ~s([data-testid="space-character-select"]))
    end

    test "the Construct opens straight inside with the character from the address", %{
      conn: conn,
      channel: channel,
      nickname: nickname
    } do
      construct_id = VirtualSpace.construct_id(channel)

      {:ok, view, html} = live(conn, path(construct_id) <> "?avatar=monk")

      assert html =~ ~s(data-space-mode="construct")
      assert html =~ ~s(data-avatar="monk")
      assert html =~ ~s(data-testid="construct-palette")
      assert html =~ "Construct · #{channel}"
      refute html =~ ~s(data-testid="space-character-select")

      token = :sys.get_state(view.pid).socket.assigns.join_token
      assert {:ok, data} = ChannelJoinToken.verify(token)
      assert data.space_kind == "construct"
      assert data.space_id == construct_id
      assert data.nickname == nickname

      assert {:error, {:live_redirect, %{to: to}}} = render_hook(view, "space_portal", %{})
      assert to == path(channel) <> "?avatar=monk"
    end

    test "an address without a character, or with one this build lacks, is the picker", %{
      conn: conn,
      channel: channel
    } do
      construct_id = VirtualSpace.construct_id(channel)

      for suffix <- ["", "?avatar=dragon_lord"] do
        {:ok, _view, html} = live(conn, path(construct_id) <> suffix)
        assert html =~ ~s(data-testid="space-character-select")
        refute html =~ ~s(data-testid="share-bar")
      end
    end

    test "the End of Time has no build palette", %{conn: conn, channel: channel} do
      {:ok, _view, html} = live(conn, path(channel) <> "?avatar=hero")

      assert html =~ ~s(data-testid="channel-space-shell")
      refute html =~ ~s(data-testid="construct-palette")
    end

    test "the Construct keeps the door its space keeps", %{conn: conn, channel: channel} do
      outsider = "Out#{uid()}" |> String.slice(0, 16)

      {:ok, _view, html} =
        conn
        |> chat_conn(outsider)
        |> live(path(VirtualSpace.construct_id(channel)) <> "?avatar=hero")

      assert html =~ ~s(data-testid="space-denied")
      refute html =~ ~s(data-testid="channel-space-shell")
    end

    test "a private space's Construct opens for its two and mints their pair", %{conn: _conn} do
      [me, peer] = ["Cm#{uid()}", "Cp#{uid()}"] |> Enum.map(&String.slice(&1, 0, 16))
      construct_id = VirtualSpace.construct_id(DirectMessageSpace.space_id(me, peer))

      {:ok, view, html} =
        build_conn() |> chat_conn(me) |> live(path(construct_id) <> "?avatar=hero")

      assert html =~ ~s(data-space-mode="construct")
      token = :sys.get_state(view.pid).socket.assigns.join_token

      assert {:ok, %{space_kind: "construct", participants: pair}} =
               ChannelJoinToken.verify(token)

      assert Enum.sort(pair) == Enum.sort(Enum.map([me, peer], &String.downcase/1))

      {:ok, _view, html} =
        build_conn()
        |> chat_conn("Third#{uid()}" |> String.slice(0, 16))
        |> live(path(construct_id) <> "?avatar=hero")

      assert html =~ ~s(data-testid="space-denied")
    end
  end

  defp register_nick(prefix) do
    nickname = "#{prefix}#{uid()}" |> String.slice(0, 16)

    {:ok, _nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> Repo.insert()

    nickname
  end
end
