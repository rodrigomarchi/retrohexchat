defmodule RetroHexChat.Commands.Handlers.SpaceTest do
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  alias RetroHexChat.Channels.Server, as: ChannelServer
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Commands.Handlers.Space
  alias RetroHexChat.Commands.Registry, as: CommandRegistry
  alias RetroHexChat.VirtualSpace.Queries
  alias RetroHexChat.VirtualSpace.Registry, as: SpaceRegistry

  @moduletag :integration

  defp unique_channel, do: "#space-cmd-#{System.unique_integer([:positive])}"

  defp channel_with_member do
    channel = unique_channel()
    {:ok, pid} = ChannelSupervisor.start_child(channel)

    on_exit(fn ->
      if Process.alive?(pid), do: ChannelSupervisor.stop_child(pid)
    end)

    nick = insert(:registered_nick)
    {:ok, _} = ChannelServer.join(channel, nick.nickname)
    {channel, nick}
  end

  defp context(nick, channel) do
    %{
      nickname: nick.nickname,
      active_channel: channel,
      channels: List.wrap(channel),
      identified: true,
      owner_in: [],
      operator_in: [],
      half_operator_in: [],
      is_admin: false,
      is_server_operator: false
    }
  end

  defp stop_space(token) do
    case SpaceRegistry.lookup(token) do
      {:ok, pid} -> GenServer.stop(pid, :normal)
      {:error, :not_found} -> :ok
    end
  end

  describe "execute/2" do
    test "creates a session in the active channel and returns the space_invite ui_action" do
      {channel, nick} = channel_with_member()

      assert {:ok, :ui_action, :space_invite, payload} =
               Space.execute([], context(nick, channel))

      on_exit(fn -> stop_space(payload.token) end)

      assert payload.target == channel
      assert payload.creator_id == nick.id
      assert is_binary(payload.token)

      session = Queries.get_session_by_token(payload.token)
      assert session.channel_name == channel
    end

    test "accepts explicit target channel, title and ttl" do
      {channel, nick} = channel_with_member()

      args = String.split("#{channel} Guild Tavern ttl=4h")

      assert {:ok, :ui_action, :space_invite, payload} =
               Space.execute(args, context(nick, channel))

      on_exit(fn -> stop_space(payload.token) end)

      assert payload.target == channel
      assert payload.title == "Guild Tavern"

      session = Queries.get_session_by_token(payload.token)
      assert session.title == "Guild Tavern"

      expected = DateTime.add(DateTime.utc_now(), 4 * 3600, :second)
      assert_in_delta DateTime.to_unix(session.expires_at), DateTime.to_unix(expected), 5
    end

    test "rejects an invalid ttl format with a usage error" do
      {channel, nick} = channel_with_member()

      assert {:error, message} = Space.execute(["ttl=banana"], context(nick, channel))
      assert message =~ "ttl"

      assert {:error, _} = Space.execute(["ttl="], context(nick, channel))
    end

    test "refuses PM/Status origins even with an explicit target channel" do
      {channel, nick} = channel_with_member()

      assert {:error, _} = Space.execute([channel], context(nick, nil))
      assert {:error, _} = Space.execute([channel], context(nick, "Status"))
    end

    test "refuses an unidentified user" do
      {channel, nick} = channel_with_member()
      ctx = %{context(nick, channel) | identified: false}

      assert {:error, _} = Space.execute([], ctx)
    end
  end

  describe "behaviour contract" do
    test "help/0 has the required shape" do
      help = Space.help()
      assert help.name == "space"
      assert is_binary(help.syntax)
      assert is_binary(help.description)
      assert is_list(help.examples)
    end

    test "syntax_definition/0 is present and category is :user" do
      syntax = Space.syntax_definition()
      assert syntax.command == "space"
      assert syntax.category == :user
      assert Space.category() == :user
    end

    test "the command is listed in the Commands.Registry" do
      assert CommandRegistry.lookup("space") == {:ok, Space}
    end
  end
end
