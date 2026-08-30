defmodule RetroHexChatWeb.App.CallLiveTest do
  @moduledoc """
  The conference at an address of its own.

  What is asserted here is the half of the surface the chat cannot supply: a
  token in the address bar instead of a channel the chat already chose, every
  gate applied here instead of upstream, and a refusal that says the policy's
  own sentence rather than a generic screen. The other half — being in a call —
  is the same module the chat renders, and `group_call_flow_test.exs` exercises
  it there.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor
  alias RetroHexChat.GroupCall
  alias RetroHexChat.GroupCall.JoinToken
  alias RetroHexChat.GroupCall.Registry
  alias RetroHexChat.GroupCall.RoomServer
  alias RetroHexChat.Services.NickServ
  alias RetroHexChat.Services.RegisteredNick

  defp register(prefix) do
    nickname = "#{prefix}#{uid()}" |> String.slice(0, 16)

    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp identify(nick) do
    NickServ.restore_identified(nick.nickname)
    on_exit(fn -> NickServ.remove_identified(nick.nickname) end)
    nick
  end

  defp open_call(nick, channel) do
    {:ok, channel_pid} = Supervisor.start_child(channel)

    on_exit(fn ->
      if Process.alive?(channel_pid) do
        Supervisor.stop_child(RetroHexChat.Channels.Supervisor, channel_pid)
      end
    end)

    {:ok, _state} = Server.join(channel, nick.nickname, nil, identified: true)

    {:ok, %{room: room, token: token}} =
      GroupCall.create_channel_call(channel, %{user_id: nick.id, nickname: nick.nickname})

    on_exit(fn ->
      case Registry.lookup_room({:room, token}) do
        {:ok, pid} -> stop_room(pid)
        {:error, :not_found} -> :ok
      end
    end)

    %{room: room, token: token, channel: channel}
  end

  # An empty channel shuts its server down, so "gone" is one of the shapes
  # "nobody is in it" takes.
  defp channel_members(channel) do
    case Server.get_state(channel) do
      {:ok, state} -> Enum.map(state.members, fn {nick, _role} -> nick end)
      {:error, _absent} -> []
    end
  end

  defp stop_liveview(view) do
    ref = Process.monitor(view.pid)
    GenServer.stop(view.pid, :normal)
    assert_receive {:DOWN, ^ref, :process, _pid, _reason}, 2_000
    :ok
  end

  defp assert_eventually(fun, retries \\ 50) do
    cond do
      fun.() -> :ok
      retries <= 0 -> flunk("condition was not met before timeout")
      true -> Process.sleep(20) && assert_eventually(fun, retries - 1)
    end
  end

  defp redirected_to_connect({:error, {_kind, %{to: to}}}), do: to == "/connect"
  defp redirected_to_connect(_other), do: false

  # The room writes its participants out as it terminates, on a sandbox
  # connection borrowed from a process that is itself on its way out.
  defp stop_room(pid) do
    GenServer.stop(pid, :normal)
  catch
    :exit, _reason -> :ok
  end

  describe "who may open it" do
    test "no session goes to connect", %{conn: conn} do
      assert redirected_to_connect(live(conn, ~p"/call/whatever"))
    end

    # The most common thing a shared link is, by a wide margin: a link outlives
    # the call it names by days.
    test "a token that names no room says the call has ended", %{conn: conn} do
      nick = register("Gone") |> identify()

      {:ok, _view, html} = conn |> chat_conn(nick.nickname) |> live(~p"/call/nosuchtoken")

      assert html =~ "This conference has ended"
      assert html =~ ~s(data-testid="call-denied")
    end

    test "an unidentified nickname is told to identify, in the policy's words", %{conn: conn} do
      host = register("Host") |> identify()
      visitor = register("Anon")
      %{token: token} = open_call(host, "#call#{uid()}")

      {:ok, _view, html} = conn |> chat_conn(visitor.nickname) |> live(~p"/call/#{token}")

      assert html =~ "identified with NickServ"
    end

    test "someone who is not in the channel is told so, in the policy's words", %{conn: conn} do
      host = register("Host") |> identify()
      outsider = register("Out") |> identify()
      %{token: token} = open_call(host, "#call#{uid()}")

      {:ok, _view, html} = conn |> chat_conn(outsider.nickname) |> live(~p"/call/#{token}")

      assert html =~ ~s(data-testid="call-denied")
      refute html =~ ~s(data-testid="group-call-prejoin-form")
    end
  end

  # The assertion the whole surface-counting mechanism exists for. Everything
  # else about a call in its own tab is cosmetic next to this: the room asks
  # `Policy.can_join?/4` on every rejoin, and it asks whether you are a member
  # of the channel.
  describe "when the chat's tab closes" do
    test "the call keeps the channel membership it stands on", %{conn: conn} do
      host = register("Outlive") |> identify()
      channel = "#call#{uid()}"

      {:ok, chat, _html} =
        conn |> chat_conn(host.nickname, pre_identified: true) |> live(~p"/chat")

      submit_command_sync(chat, "/join #{channel}")
      assert host.nickname in channel_members(channel)

      {:ok, %{token: token}} =
        GroupCall.create_channel_call(channel, %{user_id: host.id, nickname: host.nickname})

      on_exit(fn ->
        case Registry.lookup_room({:room, token}) do
          {:ok, pid} -> stop_room(pid)
          {:error, :not_found} -> :ok
        end
      end)

      {:ok, call, _html} =
        build_conn() |> chat_conn(host.nickname) |> live(~p"/call/#{token}")

      stop_liveview(chat)

      # Closing the chat is not leaving: the call is still open, so the
      # membership the room checks is still there.
      assert host.nickname in channel_members(channel)
      assert :sys.get_state(call.pid).socket.assigns.denied == nil

      # And a reload of the call — the exact path the bug denied — still passes
      # the policy it has to pass.
      {:ok, reloaded, html} =
        build_conn() |> chat_conn(host.nickname) |> live(~p"/call/#{token}")

      refute html =~ ~s(data-testid="call-denied")

      # The LAST surface going is what finally takes them out — not the first.
      stop_liveview(call)
      assert host.nickname in channel_members(channel)

      stop_liveview(reloaded)
      assert_eventually(fn -> host.nickname not in channel_members(channel) end)
    end
  end

  describe "the antechamber" do
    setup %{conn: conn} do
      host = register("Host") |> identify()
      call = open_call(host, "#call#{uid()}")
      %{host: host, call: call, conn: chat_conn(conn, host.nickname)}
    end

    # The class of bug this guards is invisible to ExUnit anywhere else: a
    # surface whose first state arrives by a message after the mount renders
    # empty in a browser and correct in a test.
    test "is the first render, not something that arrives after it", %{conn: conn, call: call} do
      {:ok, _view, html} = live(conn, ~p"/call/#{call.token}")

      assert html =~ ~s(data-testid="group-call-prejoin-form")
      assert html =~ "Already inside"
    end

    # Someone arriving at a room the host is already in: the roster is the
    # difference between a door and a device picker.
    test "names who is already in the room", %{call: call, host: host} do
      guest = register("Guest") |> identify()
      {:ok, _state} = Server.join(call.channel, guest.nickname, nil, identified: true)

      {:ok, payload} =
        GroupCall.join_call(
          call.token,
          %{user_id: host.id, nickname: host.nickname},
          self(),
          %{"browser" => "liveview-test"},
          %{}
        )

      {:ok, room_pid} = Registry.lookup_room({:room, call.token})
      :ok = RoomServer.mark_ready(room_pid, payload.participant.id)

      {:ok, view, _html} =
        build_conn() |> chat_conn(guest.nickname) |> live(~p"/call/#{call.token}")

      assert has_element?(
               view,
               ~s([data-testid="group-call-prejoin-roster-entry"]),
               host.nickname
             )
    end

    # The room server owns who is in the call, not the tab: a reload finds you
    # still inside, and asking you to pick a camera again would be asking you
    # to rejoin something you never left.
    test "a participant who never actually left lands back inside", %{
      conn: conn,
      call: call,
      host: host
    } do
      {:ok, payload} =
        GroupCall.join_call(
          call.token,
          %{user_id: host.id, nickname: host.nickname},
          self(),
          %{"browser" => "liveview-test"},
          %{}
        )

      {:ok, room_pid} = Registry.lookup_room({:room, call.token})
      :ok = RoomServer.mark_ready(room_pid, payload.participant.id)

      {:ok, view, html} = live(conn, ~p"/call/#{call.token}")

      refute html =~ ~s(data-testid="group-call-prejoin-form")
      assert has_element?(view, ~s([data-testid="group-call-webrtc"]))
      assert :sys.get_state(view.pid).socket.assigns.group_call.status == :reconnecting
    end

    # P1: a channel call has no owner, so there is no host and no [Start] — any
    # member opens one and anyone joins when they like. A gate here would be a
    # regression wearing a feature's clothes.
    test "has no host and no start button", %{conn: conn, call: call} do
      {:ok, _view, html} = live(conn, ~p"/call/#{call.token}")

      refute html =~ ~s(data-testid="group-call-start")
      assert html =~ ~s(data-testid="group-call-prejoin-join")
    end

    # P2: the conversation happens in the chat, and this is the only way there.
    test "always offers the way back to the chat", %{conn: conn, call: call} do
      {:ok, view, _html} = live(conn, ~p"/call/#{call.token}")

      assert has_element?(view, ~s([data-testid="call-back-to-chat"]))

      view
      |> element(~s([data-testid="group-call-prejoin-form"]))
      |> render_submit(%{
        "group_call_prejoin" => %{
          "audio" => "true",
          "video" => "true",
          "layout_mode" => "auto",
          "self_view" => "tile",
          "audio_input_id" => "",
          "video_input_id" => "",
          "audio_output_id" => ""
        }
      })

      assert has_element?(view, ~s([data-testid="call-back-to-chat"]))
      assert has_element?(view, ~s([data-testid="group-call-webrtc"]))
    end

    # The token is the door, so the token is a test: the hook joins the raw
    # channel with it, and nothing else in the page authorises anything.
    test "hands the browser a join token the channel will verify", %{
      conn: conn,
      call: call,
      host: host
    } do
      {:ok, view, _html} = live(conn, ~p"/call/#{call.token}")

      view
      |> element(~s([data-testid="group-call-prejoin-form"]))
      |> render_submit(%{
        "group_call_prejoin" => %{
          "audio" => "true",
          "video" => "false",
          "layout_mode" => "auto",
          "self_view" => "tile",
          "audio_input_id" => "",
          "video_input_id" => "",
          "audio_output_id" => ""
        }
      })

      join_token = :sys.get_state(view.pid).socket.assigns.group_call.join_token

      assert {:ok, verified} = JoinToken.verify(join_token)
      assert verified.room_token == call.token
      assert verified.nickname == host.nickname
      assert verified.channel_name == call.channel
    end
  end
end
