defmodule RetroHexChat.VirtualSpace.EnterChannelTest do
  @moduledoc """
  Somebody who opens the Space of a channel they are not in — a shared link,
  the public Spaces page — is put in the channel the way `/join` would, as long
  as it is a channel anybody could have found and walked into.
  """
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Surfaces
  alias RetroHexChat.Topics
  alias RetroHexChat.VirtualSpace

  @moduletag :integration

  defp unique(prefix), do: "#{prefix}#{System.unique_integer([:positive])}"

  # A running channel with its first member, who holds it open and owns it.
  defp running_channel do
    name = "#" <> unique("spenter")
    {:ok, pid} = ChannelSupervisor.start_child(name)
    {:ok, _state} = Server.join(name, "Owner", nil, identified: true)

    on_exit(fn ->
      if Process.alive?(pid), do: ChannelSupervisor.stop_child(ChannelSupervisor, pid)
    end)

    name
  end

  # The Space's own tab, registered the way `Surface` registers it: the
  # membership lasts while it is open.
  defp open_space_tab(nickname) do
    test = self()

    pid =
      spawn(fn ->
        :ok = Surfaces.open(nickname, RetroHexChatWeb.App.SpaceLive)
        send(test, :registered)

        receive do
          :close -> :ok
        end
      end)

    assert_receive :registered
    pid
  end

  defp members(channel) do
    case Server.get_state(channel) do
      {:ok, state} -> Enum.map(state.members, fn {nick, _role} -> nick end)
      {:error, _absent} -> []
    end
  end

  test "an open channel takes them in, for as long as the Space is open" do
    channel = running_channel()
    nickname = unique("ana")
    tab = open_space_tab(nickname)

    assert :ok = VirtualSpace.enter_channel(channel, nickname)
    assert nickname in members(channel)

    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(channel))
    send(tab, :close)

    assert_receive {:user_left, %{nickname: ^nickname, reason: "Left the space"}}, 1_000
  end

  test "a secret or invite-only channel is not walked into" do
    for mode <- ["+s", "+i"] do
      channel = running_channel()
      :ok = Server.set_mode(channel, "Owner", mode)
      nickname = unique("bea")
      _tab = open_space_tab(nickname)

      assert {:error, :not_open} = VirtualSpace.enter_channel(channel, nickname)
      refute nickname in members(channel)
    end
  end

  test "a key still refuses, as /join does" do
    channel = running_channel()
    :ok = Server.set_mode(channel, "Owner", "+k", ["sesame"])
    nickname = unique("cid")
    _tab = open_space_tab(nickname)

    assert {:error, reason} = VirtualSpace.enter_channel(channel, nickname)
    assert is_binary(reason)
    refute nickname in members(channel)
  end

  # The channel every chat puts everybody in is walked into even when nobody
  # is in it yet: the chat would have started it on arrival.
  test "the default channel takes them in even before anybody is in it" do
    channel = "#" <> unique("front")
    restore_default_channel_on_exit()
    Application.put_env(:retro_hex_chat, :default_channel, channel)
    nickname = unique("eve")
    _tab = open_space_tab(nickname)

    on_exit(fn ->
      case ChannelRegistry.lookup(channel) do
        {:ok, pid} -> ChannelSupervisor.stop_child(ChannelSupervisor, pid)
        _absent -> :ok
      end
    end)

    assert :ok = VirtualSpace.enter_channel(channel, nickname)
    assert nickname in members(channel)
  end

  test "a channel that does not exist is not created" do
    channel = "#" <> unique("nowhere")

    assert {:error, :not_open} = VirtualSpace.enter_channel(channel, unique("dan"))
    assert {:error, _not_running} = Server.get_state(channel)
  end
end
