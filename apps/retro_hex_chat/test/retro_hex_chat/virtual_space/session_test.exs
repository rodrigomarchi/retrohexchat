defmodule RetroHexChat.VirtualSpace.SessionTest do
  @moduledoc """
  A gathering in a space: when one opens, when it closes, and who it says came.

  The address of a space is good forever, so the row here is not the place — it
  is the evening spent in it, which is the only thing a card in a conversation
  can be about and the only thing that can be over.
  """
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.VirtualSpace
  alias RetroHexChat.VirtualSpace.DirectMessageSpace
  alias RetroHexChat.VirtualSpace.Queries
  alias RetroHexChat.VirtualSpace.Registry
  alias RetroHexChat.VirtualSpace.Schema.Session

  @moduletag :integration

  defp start_channel(members) do
    channel = "#gather-#{System.unique_integer([:positive])}"
    {:ok, channel_pid} = ChannelSupervisor.start_child(channel)
    Enum.each(members, fn nickname -> {:ok, _state} = Server.join(channel, nickname) end)

    on_exit(fn ->
      stop_space(channel)

      case ChannelRegistry.lookup(channel) do
        {:ok, ^channel_pid} -> ChannelSupervisor.stop_child(channel_pid)
        _absent -> :ok
      end
    end)

    channel
  end

  defp stop_space(space_id) do
    for key <- [{:channel_space, space_id}, {:direct_message_space, space_id}] do
      case Registry.lookup(key) do
        {:ok, pid} -> stop_and_wait(pid)
        {:error, :not_found} -> :ok
      end
    end
  end

  # The recorder learns a world is gone from a monitor, so the assertion has to
  # wait for the process to actually be gone and then for the recorder to have
  # drained the message that says so.
  defp stop_and_wait(pid) do
    ref = Process.monitor(pid)
    GenServer.stop(pid, :normal)
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 2_000
    _drained = :sys.get_state(VirtualSpace.SessionRecorder)
    :ok
  end

  defp private_space do
    suffix = System.unique_integer([:positive])
    participants = ["dm_ana_#{suffix}", "dm_bob_#{suffix}"]
    [left, right] = participants
    space_id = DirectMessageSpace.space_id(left, right)
    on_exit(fn -> stop_space(space_id) end)
    {space_id, participants}
  end

  describe "opening" do
    test "walking into an empty channel space opens one, and says so to the caller" do
      channel = start_channel(["ana"])

      assert {:ok, joined} =
               VirtualSpace.join_channel_space(channel, %{user_id: nil, nickname: "ana"})

      assert %{token: token} = joined.session
      assert {:ok, %Session{} = session} = VirtualSpace.get_session(token)
      assert session.space_id == channel
      assert session.kind == "channel"
      assert session.status == "open"
      assert session.opened_by_nick == "ana"
    end

    # One world, one gathering, one card. The second person through the door is
    # handed nothing to announce, because the announcement is already in the
    # conversation.
    test "a second arrival opens nothing and is handed nothing to announce" do
      channel = start_channel(["ana", "bob"])

      {:ok, first} = VirtualSpace.join_channel_space(channel, %{user_id: nil, nickname: "ana"})
      {:ok, second} = VirtualSpace.join_channel_space(channel, %{user_id: nil, nickname: "bob"})

      assert first.session
      refute second.session
      assert %Session{} = VirtualSpace.open_session(channel)
    end

    test "a private space opens one keyed by the pair" do
      {space_id, [ana, _bob] = participants} = private_space()

      {:ok, joined} =
        VirtualSpace.join_direct_message_space(
          space_id,
          %{user_id: nil, nickname: ana},
          participants
        )

      assert {:ok, session} = VirtualSpace.get_session(joined.session.token)
      assert session.kind == "direct_message"
      assert session.space_id == space_id
    end
  end

  describe "who came" do
    # The roster of a channel space is the channel's membership, drawn on the
    # map whether or not anybody opened it. The card asks a different question,
    # and this is the difference between the two.
    test "counts the people who walked in, not the members of the channel" do
      channel = start_channel(["ana", "bob", "cara"])

      {:ok, joined} = VirtualSpace.join_channel_space(channel, %{user_id: nil, nickname: "ana"})
      {:ok, _} = VirtualSpace.join_channel_space(channel, %{user_id: nil, nickname: "bob"})

      assert length(VirtualSpace.roster(channel)) == 3
      assert {:ok, session} = VirtualSpace.get_session(joined.session.token)
      assert VirtualSpace.session_visitors(session) == 2
    end

    test "coming back is the same person, not a second visitor" do
      channel = start_channel(["ana"])

      {:ok, joined} = VirtualSpace.join_channel_space(channel, %{user_id: nil, nickname: "ana"})
      {:ok, _again} = VirtualSpace.join_channel_space(channel, %{user_id: nil, nickname: "ana"})

      assert {:ok, session} = VirtualSpace.get_session(joined.session.token)
      assert VirtualSpace.session_visitors(session) == 1
    end
  end

  describe "closing" do
    test "the world going quiet closes the gathering" do
      channel = start_channel(["ana"])
      {:ok, joined} = VirtualSpace.join_channel_space(channel, %{user_id: nil, nickname: "ana"})

      stop_space(channel)

      assert {:ok, session} = VirtualSpace.get_session(joined.session.token)
      assert session.status == "closed"
      assert session.closed_reason == "emptied"
      assert %DateTime{} = session.closed_at
      assert VirtualSpace.open_session(channel) == nil
    end

    # A monitor and not `terminate/2`, which is the whole point: a world that
    # crashes has to count out exactly like one that emptied, or the row stays
    # open for good and the card says the party is still going.
    test "a world that crashes closes it too, and says which it was" do
      channel = start_channel(["ana"])
      {:ok, joined} = VirtualSpace.join_channel_space(channel, %{user_id: nil, nickname: "ana"})
      {:ok, pid} = Registry.lookup({:channel_space, channel})

      ref = Process.monitor(pid)
      Process.exit(pid, :kill)
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 2_000
      _drained = :sys.get_state(VirtualSpace.SessionRecorder)

      assert {:ok, session} = VirtualSpace.get_session(joined.session.token)
      assert session.status == "closed"
      assert session.closed_reason == "crashed"
    end

    test "the next gathering in the same space is a new one" do
      channel = start_channel(["ana"])
      {:ok, first} = VirtualSpace.join_channel_space(channel, %{user_id: nil, nickname: "ana"})
      stop_space(channel)

      {:ok, second} = VirtualSpace.join_channel_space(channel, %{user_id: nil, nickname: "ana"})

      assert second.session.token != first.session.token
      assert {:ok, %Session{status: "closed"}} = VirtualSpace.get_session(first.session.token)
      assert {:ok, %Session{status: "open"}} = VirtualSpace.get_session(second.session.token)
    end
  end

  describe "the sweep" do
    test "an open gathering with no world left is stale" do
      channel = "#orphan-#{System.unique_integer([:positive])}"

      {:ok, session} =
        Queries.insert_session(%{
          token: "orphan-#{System.unique_integer([:positive])}",
          space_id: channel,
          kind: "channel",
          status: "open",
          opened_by_nick: "ana",
          opened_at: DateTime.utc_now()
        })

      cutoff = DateTime.add(DateTime.utc_now(), 60, :second)

      assert {:ok, :expired} = Queries.expire_stale_session(session, cutoff)
      assert %Session{status: "expired"} = Queries.get_session_by_token(session.token)
    end
  end
end
