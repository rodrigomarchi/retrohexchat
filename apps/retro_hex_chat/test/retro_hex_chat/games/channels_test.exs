defmodule RetroHexChat.Games.ChannelsTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Channels.Membership
  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Server, as: ChannelServer
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Chat.Archive
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Channels
  alias RetroHexChat.Services.ChanExpiry
  alias RetroHexChat.Services.RegisteredChannel

  @moduletag :integration

  setup do
    on_exit(fn -> Enum.each(Channels.names(), &stop_channel/1) end)
  end

  defp stop_channel(name) do
    case ChannelRegistry.lookup(name) do
      {:ok, pid} -> ChannelSupervisor.stop_child(pid)
      {:error, :not_found} -> :ok
    end
  end

  defp gameserv_inside?(name) do
    {:ok, pid} = ChannelRegistry.lookup(name)
    state = :sys.get_state(pid)
    Membership.member?(state.membership, Channels.service())
  end

  test "every game gets a published system channel with GameServ inside, once" do
    assert {:ok, %{created: created, channels: count}} = Channels.ensure_all()
    assert count == length(Catalog.base_games()) + 1
    assert created == count

    channel = Repo.get_by!(RegisteredChannel, name: "#hex-pong")
    assert channel.system
    assert channel.founder_nickname == "GameServ"
    assert channel.topic =~ "Hex Pong"
    # Talked about in English, whichever language the players use the chat in.
    assert channel.locale == "en"
    assert channel.category == "games"
    assert Archive.published?("#hex-pong")
    assert gameserv_inside?("#hex-pong")
    assert gameserv_inside?(Channels.feed())

    assert {:ok, %{created: 0}} = Channels.ensure_all()
  end

  test "a reboot leaves what the operators changed alone" do
    :created = Channels.ensure("#hex-tennis")
    {:ok, _channel} = Archive.unpublish("#hex-tennis")

    assert :ok = Channels.ensure("#hex-tennis")
    refute Archive.published?("#hex-tennis")
  end

  test "a channel that lost GameServ gets it back" do
    :created = Channels.ensure("#hex-hockey")
    :ok = ChannelServer.part("#hex-hockey", Channels.service(), "test")
    refute gameserv_inside?("#hex-hockey")

    assert :ok = Channels.ensure_present("#hex-hockey")
    assert gameserv_inside?("#hex-hockey")
  end

  test "a quiet games channel never expires" do
    :created = Channels.ensure("#light-trails")
    long_ago = DateTime.add(DateTime.utc_now(), -400, :day)
    Repo.update_all(RegisteredChannel, set: [last_activity_at: long_ago])

    ChanExpiry.purge(expiration_days: 90)

    assert Repo.get_by(RegisteredChannel, name: "#light-trails")
  end
end
