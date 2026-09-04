defmodule RetroHexChatWeb.ChatLive.GroupCallFlowTest do
  @moduledoc """
  What the chat does about conferences, which is open them and draw them.

  A conference does not live here any more. The chat's part is two acts that
  must not come apart — creating the room and writing its address into the
  channel as a card everyone can scroll back to — plus the chrome it draws about
  a call it cannot reach: the badge, the glyph and the status zone.

  Being *inside* a conference is `live/app/call_surface_flow_test.exs`, at the
  address that card carries.
  """
  use RetroHexChatWeb.LiveViewCase, async: false

  @moduletag :liveview_feature

  alias RetroHexChat.Chat.Queries, as: ChatQueries
  alias RetroHexChat.GroupCall
  alias RetroHexChat.GroupCall.Registry
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.ShareLinks

  defp unique_nick(prefix), do: "#{prefix}#{uid()}" |> String.slice(0, 16)

  defp register(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> RetroHexChat.Repo.insert()

    nick
  end

  defp mount_identified(conn, prefix) do
    nick = register(unique_nick(prefix))
    {:ok, view, _html} = live(chat_conn(conn, nick.nickname, pre_identified: true), "/chat")
    %{nick: nick, view: view}
  end

  defp flush(view), do: :sys.get_state(view.pid)
  defp active_channel(view), do: :sys.get_state(view.pid).socket.assigns.session.active_channel

  defp group_call_channels(view),
    do: :sys.get_state(view.pid).socket.assigns.group_call_channels

  defp group_call_channel_summaries(view),
    do: :sys.get_state(view.pid).socket.assigns.group_call_channel_summaries

  # The one click in the product that creates a conference. It only exists while
  # the channel has no room; once one does, the control is an anchor.
  defp click_open(view) do
    view |> element(~s([data-testid="group-call-open"])) |> render_click()
    flush(view)
  end

  defp open_conference(view) do
    click_open(view)
    room = GroupCall.active_room_for_channel(active_channel(view))
    cleanup_room(room.token)
    room
  end

  # The card is a real message in the channel, so it is counted where messages
  # live rather than in whatever the reader's screen happens to be rendering.
  defp system_messages(channel) do
    channel
    |> ChatQueries.list_messages(limit: 50)
    |> Map.fetch!(:items)
    |> Enum.filter(&(&1.type == "system"))
  end

  defp cleanup_room(token) do
    on_exit(fn ->
      case Registry.lookup_room({:room, token}) do
        {:ok, pid} -> stop_room(pid)
        {:error, :not_found} -> :ok
      end
    end)
  end

  defp stop_room(pid) do
    GenServer.stop(pid, :normal)
  catch
    :exit, _reason -> :ok
  end

  defp wait_until(fun, retries \\ 30)

  defp wait_until(fun, retries) do
    case fun.() do
      true -> :ok
      _other when retries <= 0 -> flunk("condition was not met before timeout")
      _other -> Process.sleep(20) && wait_until(fun, retries - 1)
    end
  end

  describe "opening a conference from the chat" do
    test "creates the room and writes its address into the channel", %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcfa")
      channel = active_channel(view)

      assert has_element?(view, ~s|[data-testid="group-call-open"]:not([disabled])|)

      room = open_conference(view)

      assert room.channel_name == channel

      # The card is the door, so it has to be a message: persisted, broadcast,
      # and in the scrollback of somebody who joins the channel tomorrow.
      [message] = system_messages(channel)
      assert message.author_nickname == "System"
      assert message.content =~ nick.nickname

      [slug] = RetroHexChatWeb.ShareLinkRef.slugs_in(message.content)
      assert {:ok, resolution} = ShareLinks.describe(slug)

      assert resolution.kind == "call"
      assert resolution.target["room_token"] == room.token

      card = ShareLinks.describe_many([slug]) |> Map.fetch!(slug)
      assert card.state == :live
      assert card.creator_nick == nick.nickname
    end

    # A room, a link, a card. Clicking again is not a second conference, and the
    # negative here is the point: revert the idempotence and this goes red.
    test "clicking again with a live room mints nothing and posts nothing", %{conn: conn} do
      %{view: view} = mount_identified(conn, "gcfz")
      channel = active_channel(view)

      _room = open_conference(view)
      assert length(system_messages(channel)) == 1

      # The control is an anchor once a room exists, so the click that would
      # repeat it can only arrive as the event itself.
      render_click(view, "group_call_open", %{})
      flush(view)

      assert length(system_messages(channel)) == 1
      assert render(view) =~ "already open"
    end

    test "a second person in the channel lands in the same room", %{conn: conn} do
      ctx_a = mount_identified(conn, "gcfb")
      ctx_b = mount_identified(conn, "gcfc")

      channel = active_channel(ctx_a.view)
      assert channel == active_channel(ctx_b.view)

      room = open_conference(ctx_a.view)

      wait_until(fn ->
        flush(ctx_b.view)
        MapSet.member?(group_call_channels(ctx_b.view), channel)
      end)

      # No second room and no second card: what B sees is the card A's press
      # wrote, which is the only door either of them has.
      assert GroupCall.active_room_for_channel(channel).token == room.token
      assert length(system_messages(channel)) == 1

      assert has_element?(ctx_b.view, ~s([data-testid="group-call-open"]))
      refute has_element?(ctx_b.view, ~s([data-testid="group-call-open"][href]))
    end

    test "an unidentified user is refused, in the policy's words", %{conn: conn} do
      {:ok, view, _html} = live(chat_conn(conn, unique_nick("gcfe")), "/chat")
      channel = active_channel(view)

      assert has_element?(view, ~s([data-testid="group-call-open"][disabled]))

      render_click(view, "group_call_open", %{})

      assert render(view) =~ "identified with NickServ"
      refute GroupCall.active_room_for_channel(channel)
      assert system_messages(channel) == []
    end
  end

  describe "what the chat draws about a call it does not host" do
    test "a live conference shows in the badge, the glyph and the status zone", %{conn: conn} do
      ctx_a = mount_identified(conn, "gcfi")
      ctx_b = mount_identified(conn, "gcfj")
      channel = "#gcli#{uid()}"

      submit_command_sync(ctx_a.view, "/join #{channel}")
      submit_command_sync(ctx_b.view, "/join #{channel}")

      refute MapSet.member?(group_call_channels(ctx_b.view), channel)

      room = open_conference(ctx_a.view)

      wait_until(fn ->
        flush(ctx_b.view)
        MapSet.member?(group_call_channels(ctx_b.view), channel)
      end)

      assert Map.has_key?(group_call_channel_summaries(ctx_b.view), channel)

      assert has_element?(
               ctx_b.view,
               ~s([data-testid="group-call-open"][data-channel="#{channel}"][data-state="active"])
             )

      assert has_element?(
               ctx_b.view,
               ~s([data-testid="group-call-channel-popover"][data-channel="#{channel}"]),
               "Participants"
             )

      assert has_element?(ctx_b.view, ~s([data-testid="tab-group-call-glyph"]))
      assert has_element?(ctx_b.view, ~s([data-testid="channel-group-call-glyph-#{channel}"]))

      GroupCall.close_call(room.token, %{user_id: ctx_a.nick.id, nickname: ctx_a.nick.nickname})

      wait_until(fn ->
        flush(ctx_b.view)
        !MapSet.member?(group_call_channels(ctx_b.view), channel)
      end)

      refute Map.has_key?(group_call_channel_summaries(ctx_b.view), channel)
      refute has_element?(ctx_b.view, ~s([data-testid="group-call-open"][data-state]))
      refute has_element?(ctx_b.view, ~s([data-testid="tab-group-call-glyph"]))
    end

    # The status zone is the third shape of "you are in a call": not here, and
    # not merely running — running on a screen of yours that is not this one.
    test "the status zone says where the call is, with no way over and no Leave",
         %{conn: conn} do
      %{nick: nick, view: view} = mount_identified(conn, "gcff")
      room = open_conference(view)

      refute has_element?(view, ~s([data-testid="status-bar-group-call"]))

      # The zone exists because the registry says this person has that address
      # open, so the test opens it for real rather than posing the answer.
      {:ok, call, _html} =
        live(chat_conn(conn, nick.nickname, pre_identified: true), "/call/#{room.token}")

      assert call

      wait_until(fn ->
        flush(view)

        MapSet.member?(
          :sys.get_state(view.pid).socket.assigns.open_surface_paths,
          "/call/#{room.token}"
        )
      end)

      # A readout, not a way over: the card in the conversation is the door.
      assert has_element?(
               view,
               ~s([data-testid="status-bar-group-call"]),
               "in another tab"
             )

      refute has_element?(view, ~s([data-testid="status-bar-group-call"][href]))

      refute has_element?(view, ~s([data-testid="status-bar-group-call-stop"]))
    end

    test "conference administrative events render system messages without update spam", %{
      conn: conn
    } do
      %{view: view} = mount_identified(conn, "gcau")
      channel = "#gcaudit#{uid()}"

      submit_command_sync(view, "/join #{channel}")

      Phoenix.PubSub.broadcast(RetroHexChat.PubSub, "channel:#{channel}", {
        :group_call_moderation,
        %{
          channel: channel,
          action: :participant_muted,
          actor: "Mod",
          target: "Guest",
          event: %{"type" => "participant_muted"}
        }
      })

      flush(view)
      html = render(view)
      assert html =~ "Mod"
      assert html =~ "Guest"
      assert html =~ "conference microphone"

      Phoenix.PubSub.broadcast(RetroHexChat.PubSub, "channel:#{channel}", {
        :group_call_moderation,
        %{
          channel: channel,
          action: :screen_share_started,
          target: "Guest",
          event: %{"type" => "screen_share_started"}
        }
      })

      flush(view)
      assert render(view) =~ "started sharing a screen"

      Phoenix.PubSub.broadcast(RetroHexChat.PubSub, "channel:#{channel}", {
        :group_call_moderation,
        %{
          channel: channel,
          action: :participant_kicked,
          actor: "Mod",
          target: "Guest",
          event: %{"type" => "participant_kicked"}
        }
      })

      flush(view)
      assert render(view) =~ "removed Guest from the conference"

      Phoenix.PubSub.broadcast(RetroHexChat.PubSub, "channel:#{channel}", {
        :group_call_updated,
        %{channel: channel, reason: "media_state", summary: %{}}
      })

      flush(view)
      refute render(view) =~ "Conference moderation updated"
    end
  end
end
