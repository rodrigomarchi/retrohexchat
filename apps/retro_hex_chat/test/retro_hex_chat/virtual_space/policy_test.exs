defmodule RetroHexChat.VirtualSpace.PolicyTest do
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  alias RetroHexChat.Channels.Server, as: ChannelServer
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Services.Queries, as: ServiceQueries
  alias RetroHexChat.VirtualSpace.{Policy, Queries}

  @moduletag :integration

  defp unique_channel, do: "#space-test-#{System.unique_integer([:positive])}"

  defp start_channel(channel_name) do
    {:ok, pid} = ChannelSupervisor.start_child(channel_name)

    on_exit(fn ->
      if Process.alive?(pid), do: ChannelSupervisor.stop_child(pid)
    end)

    :ok
  end

  defp actor(overrides \\ %{}) do
    nick = Map.get_lazy(overrides, :registered_nick, fn -> insert(:registered_nick) end)

    Map.merge(
      %{
        user_id: nick.id,
        nickname: nick.nickname,
        identified: true,
        is_admin: false,
        is_server_operator: false
      },
      Map.drop(overrides, [:registered_nick])
    )
  end

  defp guest_actor do
    %{
      user_id: nil,
      nickname: "guest#{System.unique_integer([:positive])}",
      identified: false,
      is_admin: false,
      is_server_operator: false
    }
  end

  defp insert_space(creator, attrs \\ %{}) do
    base = %{
      token: "space-#{System.unique_integer([:positive])}",
      channel_name: "#retro",
      creator_id: creator.id,
      creator_nick: creator.nickname,
      title: "HQ"
    }

    {:ok, session} = Queries.insert_session(Map.merge(base, attrs))
    session
  end

  describe "can_create?/2" do
    test "accepts a registered, identified member who can post in the channel" do
      channel = unique_channel()
      start_channel(channel)

      nick = insert(:registered_nick)
      {:ok, _} = ChannelServer.join(channel, nick.nickname)

      assert :ok = Policy.can_create?(actor(%{registered_nick: nick}), channel)
    end

    test "rejects a guest" do
      channel = unique_channel()
      start_channel(channel)

      assert {:error, :registration_required} = Policy.can_create?(guest_actor(), channel)
    end

    test "rejects an unidentified user" do
      channel = unique_channel()
      start_channel(channel)

      assert {:error, :not_identified} =
               Policy.can_create?(actor(%{identified: false}), channel)
    end

    test "rejects a PM or Status origin" do
      assert {:error, :invalid_origin} = Policy.can_create?(actor(), nil)
      assert {:error, :invalid_origin} = Policy.can_create?(actor(), "Status")
      assert {:error, :invalid_origin} = Policy.can_create?(actor(), "mario")
    end

    test "rejects a regular member without voice in a moderated channel" do
      channel = unique_channel()
      start_channel(channel)

      owner = insert(:registered_nick)
      regular = insert(:registered_nick)
      {:ok, _} = ChannelServer.join(channel, owner.nickname)
      {:ok, _} = ChannelServer.join(channel, regular.nickname)
      :ok = ChannelServer.set_mode(channel, owner.nickname, "+m")

      assert {:error, :cannot_post} =
               Policy.can_create?(actor(%{registered_nick: regular}), channel)

      assert :ok = Policy.can_create?(actor(%{registered_nick: owner}), channel)
    end
  end

  describe "can_join?/2" do
    test "accepts a registered, identified user on a public channel" do
      creator = insert(:registered_nick)
      session = insert_space(creator, %{channel_name: unique_channel()})

      assert :ok = Policy.can_join?(actor(), session)
    end

    test "rejects a guest" do
      creator = insert(:registered_nick)
      session = insert_space(creator)

      assert {:error, :registration_required} = Policy.can_join?(guest_actor(), session)
    end

    test "rejects a terminal session" do
      creator = insert(:registered_nick)
      session = insert_space(creator, %{channel_name: unique_channel()})

      {:ok, closed} =
        Queries.update_status(session, "closed", %{
          closed_at: DateTime.utc_now(),
          closed_reason: "test"
        })

      assert {:error, :terminal_session} = Policy.can_join?(actor(), closed)
    end

    test "invite-only channel requires access per Channels.Policy" do
      channel = unique_channel()
      insert(:registered_channel, name: channel, modes: "+i")

      creator = insert(:registered_nick)
      session = insert_space(creator, %{channel_name: channel})

      outsider = insert(:registered_nick)
      invited = insert(:registered_nick)
      {:ok, _} = ServiceQueries.add_invite_exception(channel, invited.nickname, "Admin")

      assert {:error, :channel_access_denied} =
               Policy.can_join?(actor(%{registered_nick: outsider}), session)

      assert :ok = Policy.can_join?(actor(%{registered_nick: invited}), session)
    end

    test "a live channel member joins even when the channel is invite-only" do
      channel = unique_channel()
      start_channel(channel)

      member = insert(:registered_nick)
      {:ok, _} = ChannelServer.join(channel, member.nickname)
      :ok = ChannelServer.set_mode(channel, member.nickname, "+i")

      creator = insert(:registered_nick)
      session = insert_space(creator, %{channel_name: channel})

      assert :ok = Policy.can_join?(actor(%{registered_nick: member}), session)
    end
  end

  describe "check_capacity/3" do
    test "rejects a newcomer when the space is at capacity" do
      creator = insert(:registered_nick)
      session = insert_space(creator, %{max_participants: 2})

      assert {:error, :space_full} = Policy.check_capacity(session, 2, false)
    end

    test "accepts a newcomer below capacity" do
      creator = insert(:registered_nick)
      session = insert_space(creator, %{max_participants: 2})

      assert :ok = Policy.check_capacity(session, 1, false)
    end

    test "accepts a returning participant even at capacity" do
      creator = insert(:registered_nick)
      session = insert_space(creator, %{max_participants: 2})

      assert :ok = Policy.check_capacity(session, 2, true)
    end
  end

  describe "can_close?/2" do
    test "the creator can close" do
      creator = insert(:registered_nick)
      session = insert_space(creator)

      assert :ok = Policy.can_close?(actor(%{registered_nick: creator}), session)
    end

    test "a regular participant cannot close" do
      creator = insert(:registered_nick)
      session = insert_space(creator)

      assert {:error, :forbidden} = Policy.can_close?(actor(), session)
    end

    test "an admin or server operator can close" do
      creator = insert(:registered_nick)
      session = insert_space(creator)

      assert :ok = Policy.can_close?(actor(%{is_admin: true}), session)
      assert :ok = Policy.can_close?(actor(%{is_server_operator: true}), session)
    end
  end

  describe "can_admin?/2" do
    test "creator and admin can kick/mute/change_map" do
      creator = insert(:registered_nick)
      session = insert_space(creator)

      assert :ok = Policy.can_admin?(actor(%{registered_nick: creator}), session)
      assert :ok = Policy.can_admin?(actor(%{is_admin: true}), session)
      assert :ok = Policy.can_admin?(actor(%{is_server_operator: true}), session)
    end

    test "a regular participant cannot administrate" do
      creator = insert(:registered_nick)
      session = insert_space(creator)

      assert {:error, :forbidden} = Policy.can_admin?(actor(), session)
    end
  end
end
