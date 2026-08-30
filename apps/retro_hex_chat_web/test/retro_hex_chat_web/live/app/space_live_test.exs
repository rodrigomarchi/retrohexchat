defmodule RetroHexChatWeb.App.SpaceLiveTest do
  @moduledoc """
  A space at an address of its own.

  What is asserted here is the half of the surface the chat cannot supply: an
  address instead of a conversation the chat already chose, every gate applied
  here instead of upstream, and a refusal that names the door that was shut.
  The other half — being in a space — is the same module the chat renders, and
  `chat_desktop_shell_test.exs` exercises it there.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.ShareLinks
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
      other = "Peer#{uid()}" |> String.slice(0, 16)
      {:ok, _state} = Server.join(channel, other)

      {:ok, view, _html} = live(conn, path(channel))

      assert has_element?(view, ~s([data-testid="space-roster-names"]), nickname)
      assert has_element?(view, ~s([data-testid="space-roster-names"]), other)
    end

    test "an empty space says so rather than breaking", %{conn: _conn} do
      ana = "ana#{uid()}" |> String.slice(0, 16)
      bob = "bob#{uid()}" |> String.slice(0, 16)
      space_id = DirectMessageSpace.space_id(ana, bob)

      {:ok, view, _html} = build_conn() |> chat_conn(ana) |> live(path(space_id))

      assert has_element?(view, ~s([data-testid="space-roster"]), "Nobody is in here yet")
    end

    # The address is the place, so a tab that already is the space has nothing
    # to open in a tab of its own.
    test "offers no tab of its own when it already is one", %{conn: conn, channel: channel} do
      {:ok, view, _html} = live(conn, path(channel))

      refute has_element?(view, ~s([data-testid="space-open-in-tab"]))
      refute has_element?(view, ~s([data-testid="space-fullscreen-toggle"]))
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

      other = "Peer#{uid()}" |> String.slice(0, 16)
      {:ok, _state} = Server.join(channel, other)

      assert render(view) =~ other
    end

    # Nobody has opened the space, so there is no process to ask — and the
    # answer is still right, because a channel space holds the channel.
    test "a space nobody has opened still names who would be in it", %{conn: conn} do
      nickname = "Cold#{uid()}" |> String.slice(0, 16)
      channel = start_channel(nickname)

      {:ok, view, _html} = conn |> chat_conn(nickname) |> live(path(channel))

      assert has_element?(view, ~s([data-testid="space-roster-names"]), nickname)
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
