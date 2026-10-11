defmodule RetroHexChat.VirtualSpace.SpeechTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Admin.GlobalMutes
  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Topics
  alias RetroHexChat.VirtualSpace
  alias RetroHexChat.VirtualSpace.DirectMessageSpace
  alias RetroHexChat.VirtualSpace.Registry

  @moduletag :integration

  setup do
    Application.put_env(:retro_hex_chat, :virtual_space_step_ms, 0)
    on_exit(fn -> Application.delete_env(:retro_hex_chat, :virtual_space_step_ms) end)
    GlobalMutes.reload_cache()
    :ok
  end

  defp uid, do: System.unique_integer([:positive])

  # A channel with its owner and one guest in it, and the guest standing in
  # the channel's space.
  defp channel_with_space do
    channel = "#speech-#{uid()}"
    owner = "own#{uid()}"
    guest = "gst#{uid()}"

    {:ok, channel_pid} = ChannelSupervisor.start_child(channel)
    {:ok, _} = Server.join(channel, owner)
    {:ok, _} = Server.join(channel, guest)
    {:ok, _joined} = VirtualSpace.join_channel_space(channel, %{user_id: nil, nickname: guest})

    on_exit(fn ->
      case Registry.lookup({:channel_space, channel}) do
        {:ok, pid} -> GenServer.stop(pid, :normal)
        {:error, :not_found} -> :ok
      end

      case ChannelRegistry.lookup(channel) do
        {:ok, _pid} -> ChannelSupervisor.stop_child(ChannelSupervisor, channel_pid)
        {:error, :not_found} -> :ok
      end
    end)

    %{channel: channel, owner: owner, guest: guest}
  end

  defp private_space do
    [me, peer] = participants = ["sp_me_#{uid()}", "sp_peer_#{uid()}"]
    space_id = DirectMessageSpace.space_id(me, peer)

    on_exit(fn ->
      case Registry.lookup({:direct_message_space, space_id}) do
        {:ok, pid} -> GenServer.stop(pid, :normal)
        {:error, :not_found} -> :ok
      end
    end)

    {:ok, _joined} =
      VirtualSpace.join_direct_message_space(
        space_id,
        %{user_id: nil, nickname: me},
        participants
      )

    %{space_id: space_id, me: me, peer: peer, participants: participants}
  end

  describe "in a channel's space" do
    test "a line is said in the channel, and the space draws it over the speaker" do
      %{channel: channel, guest: guest} = channel_with_space()
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(channel))
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.space(channel))

      assert :ok = VirtualSpace.say({:channel, channel}, guest, "  hello plaza  ")

      assert_receive %{event: "new_message", payload: %{author: ^guest, content: "hello plaza"}}
      assert_receive %{event: "space_message", payload: %{nickname: ^guest, text: "hello plaza"}}
    end

    test "/me is said as an action" do
      %{channel: channel, guest: guest} = channel_with_space()
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(channel))

      assert :ok = VirtualSpace.say({:channel, channel}, guest, "/me waves")

      assert_receive %{event: "new_message", payload: %{content: "waves", type: type}}
      assert to_string(type) == "action"
    end

    test "the channel's own rules still apply: a moderated channel refuses a guest" do
      %{channel: channel, owner: owner, guest: guest} = channel_with_space()
      :ok = Server.set_mode(channel, owner, "+m")

      assert {:error, reason} = VirtualSpace.say({:channel, channel}, guest, "can I talk?")
      assert is_binary(reason) and reason != ""
    end

    test "a muted nickname is refused before anything is sent" do
      %{channel: channel, guest: guest} = channel_with_space()
      :ok = GlobalMutes.mute(guest, "Admin", nil, :permanent)
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(channel))

      assert {:error, "You are muted by an administrator"} =
               VirtualSpace.say({:channel, channel}, guest, "hi")

      refute_receive %{event: "new_message"}
    end
  end

  describe "in a private space" do
    test "a line goes to the other person, and the space draws it over the speaker" do
      %{space_id: space_id, me: me, peer: peer, participants: participants} = private_space()
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.inbox(peer))
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.space(space_id))

      assert :ok = VirtualSpace.say({:direct_message, participants}, me, "just us")

      assert_receive %{event: "new_pm", payload: %{sender: ^me, content: "just us"}}
      assert_receive %{event: "space_message", payload: %{nickname: ^me, text: "just us"}}
    end

    test "a third nickname has nobody to say it to" do
      %{participants: participants} = private_space()

      assert {:error, reason} =
               VirtualSpace.say({:direct_message, participants}, "intruder", "hi")

      assert reason =~ "two other people"
    end
  end

  describe "what is not a line" do
    test "blank text is refused" do
      %{channel: channel, guest: guest} = channel_with_space()

      assert {:error, _reason} = VirtualSpace.say({:channel, channel}, guest, "   ")
      assert {:error, _reason} = VirtualSpace.say({:channel, channel}, guest, "/me   ")
    end

    test "any command other than /me belongs to the chat" do
      %{channel: channel, guest: guest} = channel_with_space()
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, Topics.channel(channel))

      assert {:error, reason} = VirtualSpace.say({:channel, channel}, guest, "/part")
      assert reason =~ "/me"
      refute_receive %{event: "new_message"}
    end
  end
end
