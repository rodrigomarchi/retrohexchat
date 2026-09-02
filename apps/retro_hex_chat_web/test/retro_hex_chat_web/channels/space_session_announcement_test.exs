defmodule RetroHexChatWeb.SpaceSessionAnnouncementTest do
  @moduledoc """
  The card a gathering leaves in the conversation it belongs to.

  Driven through the space's own channel rather than through the module, because
  the thing worth asserting is that walking into an empty world is what writes
  the line — and that walking into a busy one writes nothing.
  """
  use RetroHexChatWeb.ChannelCase, async: false

  import RetroHexChat.Factory

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Channels.Supervisor
  alias RetroHexChat.Chat.Queries, as: ChatQueries
  alias RetroHexChat.ShareLinks
  alias RetroHexChat.VirtualSpace.ChannelJoinToken
  alias RetroHexChat.VirtualSpace.DirectMessageSpace
  alias RetroHexChat.VirtualSpace.Registry
  alias RetroHexChatWeb.ShareLinkRef
  alias RetroHexChatWeb.UserSocket

  @moduletag :integration

  defp uid, do: System.unique_integer([:positive])

  defp registered(prefix) do
    nick = insert(:registered_nick, nickname: "#{prefix}#{uid()}" |> String.slice(0, 16))
    {nick.nickname, nick.id}
  end

  defp start_channel(members) do
    channel = "#spacecard-#{uid()}"
    {:ok, pid} = Supervisor.start_child(channel)
    Enum.each(members, fn nickname -> {:ok, _state} = Server.join(channel, nickname) end)

    on_exit(fn ->
      stop_space({:channel_space, channel})

      case ChannelRegistry.lookup(channel) do
        {:ok, ^pid} -> Supervisor.stop_child(pid)
        _absent -> :ok
      end
    end)

    channel
  end

  defp stop_space(key) do
    case Registry.lookup(key) do
      {:ok, pid} -> GenServer.stop(pid, :normal)
      {:error, :not_found} -> :ok
    end
  end

  defp enter(channel, nickname, user_id) do
    {:ok, socket} = connect(UserSocket, %{})
    token = ChannelJoinToken.sign(channel, user_id, nickname)

    {:ok, _reply, socket} =
      subscribe_and_join(socket, "space:#{channel}", %{"join_token" => token})

    socket
  end

  defp enter_private(space_id, nickname, user_id, participants) do
    {:ok, socket} = connect(UserSocket, %{})
    token = ChannelJoinToken.sign_direct_message(space_id, user_id, nickname, participants)

    {:ok, _reply, socket} =
      subscribe_and_join(socket, "space:#{space_id}", %{"join_token" => token})

    socket
  end

  defp system_messages(channel) do
    channel
    |> ChatQueries.list_messages(limit: 50)
    |> Map.fetch!(:items)
    |> Enum.filter(&(&1.type == "system"))
  end

  describe "a channel space" do
    test "the first person in writes the gathering's address into the channel" do
      {nickname, user_id} = registered("sca")
      channel = start_channel([nickname])

      enter(channel, nickname, user_id)

      [message] = system_messages(channel)
      assert message.author_nickname == "System"
      assert message.content =~ nickname

      [slug] = ShareLinkRef.slugs_in(message.content)
      assert {:ok, resolution} = ShareLinks.describe(slug)
      assert resolution.kind == "space"
      assert resolution.target["space_id"] == channel
      assert is_binary(resolution.target["session_token"])

      card = [slug] |> ShareLinks.describe_many() |> Map.fetch!(slug)
      assert card.state == :live
      assert card.creator_nick == nickname
    end

    # One gathering, one card. Revert the "only the opener gets a session back"
    # rule and this is the test that goes red.
    test "everybody after the first writes nothing" do
      {first, first_id} = registered("scb")
      {second, second_id} = registered("scc")
      channel = start_channel([first, second])

      enter(channel, first, first_id)
      enter(channel, second, second_id)

      assert length(system_messages(channel)) == 1
    end

    # A shared address carries somebody accountable for it, which is the rule
    # `ShareLinks` enforces at its own door. A guest still walks in.
    test "a guest opens the space and announces nothing" do
      nickname = "guest#{uid()}" |> String.slice(0, 16)
      channel = start_channel([nickname])

      enter(channel, nickname, nil)

      assert system_messages(channel) == []
      assert Registry.lookup({:channel_space, channel}) != {:error, :not_found}
    end

    test "the next gathering in the same channel writes its own card" do
      {nickname, user_id} = registered("scd")
      channel = start_channel([nickname])

      enter(channel, nickname, user_id)
      stop_space({:channel_space, channel})
      enter(channel, nickname, user_id)

      assert [first, second] = system_messages(channel)
      assert ShareLinkRef.slugs_in(first.content) != ShareLinkRef.slugs_in(second.content)
    end
  end

  describe "a private space" do
    test "the card is a line in the conversation the two of them already have" do
      {ana, ana_id} = registered("sce")
      {bob, _bob_id} = registered("scf")
      space_id = DirectMessageSpace.space_id(ana, bob)
      on_exit(fn -> stop_space({:direct_message_space, space_id}) end)

      enter_private(space_id, ana, ana_id, [ana, bob])

      assert [pm] = ChatQueries.list_private_messages(ana, bob, limit: 50).items
      assert pm.type == "system"
      assert pm.sender_nickname == ana
      assert pm.recipient_nickname == bob

      [slug] = ShareLinkRef.slugs_in(pm.content)
      assert {:ok, resolution} = ShareLinks.describe(slug)
      assert resolution.target["space_id"] == space_id
    end
  end
end
