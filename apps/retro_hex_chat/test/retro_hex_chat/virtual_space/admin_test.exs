defmodule RetroHexChat.VirtualSpace.AdminTest do
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  alias RetroHexChat.VirtualSpace.{Queries, Registry, SessionServer, Supervisor}

  @moduletag :integration

  setup do
    Application.put_env(:retro_hex_chat, :virtual_space_chat_rate, {50, 1000})
    on_exit(fn -> Application.delete_env(:retro_hex_chat, :virtual_space_chat_rate) end)
    :ok
  end

  defp start_space do
    creator = insert(:registered_nick)

    {:ok, session} =
      Queries.insert_session(%{
        token: "adm-#{System.unique_integer([:positive])}",
        channel_name: "#retro",
        creator_id: creator.id,
        creator_nick: creator.nickname,
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    {:ok, pid} = Supervisor.start_child(session.token)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)

    Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "space:#{session.token}")

    {:ok, cj} =
      SessionServer.join(session.token, %{user_id: creator.id, nickname: creator.nickname})

    %{token: session.token, creator: creator, creator_key: cj.participant.key}
  end

  defp join_member(ctx, nick \\ nil) do
    member = insert(:registered_nick, if(nick, do: [nickname: nick], else: []))
    {:ok, j} = SessionServer.join(ctx.token, %{user_id: member.id, nickname: member.nickname})
    {member, j.participant.key}
  end

  defp creator_actor(ctx),
    do: %{user_id: ctx.creator.id, is_admin: false, is_server_operator: false}

  defp member_actor(member),
    do: %{user_id: member.id, is_admin: false, is_server_operator: false}

  describe "authorization" do
    test "a common participant cannot run admin actions" do
      ctx = start_space()
      {member, member_key} = join_member(ctx)

      assert {:error, :forbidden} =
               SessionServer.admin_action(ctx.token, member_actor(member), %{
                 kind: "mute",
                 target_key: member_key,
                 muted: true
               })
    end
  end

  describe "kick" do
    test "removes the target, blocks reentry and publishes the reason" do
      ctx = start_space()
      {member, member_key} = join_member(ctx)

      assert :ok =
               SessionServer.admin_action(ctx.token, creator_actor(ctx), %{
                 kind: "kick",
                 target_key: member_key,
                 reason: "spam"
               })

      assert_receive %{
        event: "space_participant_kicked",
        payload: %{key: ^member_key, reason: "spam"}
      }

      {:ok, state} = SessionServer.get_state(ctx.token)
      refute state.participants[member_key].online?

      # The kicked participant cannot rejoin the session.
      assert {:error, :kicked} =
               SessionServer.join(ctx.token, %{user_id: member.id, nickname: member.nickname})
    end

    test "a kicked participant cannot resurrect via interact (sit)" do
      ctx = start_space()
      {_member, member_key} = join_member(ctx)

      assert :ok =
               SessionServer.admin_action(ctx.token, creator_actor(ctx), %{
                 kind: "kick",
                 target_key: member_key,
                 reason: "spam"
               })

      # An offline/kicked participant whose socket is still open must not be
      # able to reseat and reappear to everyone.
      assert {:error, :not_participant} =
               SessionServer.interact(ctx.token, member_key, %{
                 seq: 1,
                 kind: "sit",
                 target_id: "seat_bar_1"
               })

      {:ok, state} = SessionServer.get_state(ctx.token)
      refute state.participants[member_key].online?
      assert state.participants[member_key].seat_id == nil
    end
  end

  describe "mute" do
    test "muting blocks chat and unmuting restores it" do
      ctx = start_space()
      {member, member_key} = join_member(ctx)

      assert :ok =
               SessionServer.admin_action(ctx.token, creator_actor(ctx), %{
                 kind: "mute",
                 target_key: member_key,
                 muted: true
               })

      assert {:error, :muted} = SessionServer.chat_bubble(ctx.token, member_key, "hi")

      assert :ok =
               SessionServer.admin_action(ctx.token, creator_actor(ctx), %{
                 kind: "mute",
                 target_key: member_key,
                 muted: false
               })

      assert :ok = SessionServer.chat_bubble(ctx.token, member_key, "hi")
      assert member.id
    end
  end

  describe "close" do
    test "manual close transitions to closed and stops the process" do
      ctx = start_space()

      assert :ok =
               SessionServer.admin_action(ctx.token, creator_actor(ctx), %{
                 kind: "close",
                 reason: "done"
               })

      assert_receive %{event: "space_closed", payload: %{reason: "done"}}
      assert Queries.get_session_by_token(ctx.token).status == "closed"
      assert {:error, :not_found} = Registry.lookup(ctx.token)
    end
  end

  describe "change_map" do
    test "reemits a full snapshot, respawns everyone and preserves mute" do
      ctx = start_space()
      {_member, member_key} = join_member(ctx)

      :ok =
        SessionServer.admin_action(ctx.token, creator_actor(ctx), %{
          kind: "mute",
          target_key: member_key,
          muted: true
        })

      assert :ok =
               SessionServer.admin_action(ctx.token, creator_actor(ctx), %{
                 kind: "change_map",
                 map_id: "guild_hall_v1"
               })

      assert_receive %{event: "space_map_changed", payload: payload}
      assert payload.map.id == "guild_hall_v1"
      assert Map.has_key?(payload.snapshot.participants, member_key)

      {:ok, state} = SessionServer.get_state(ctx.token)
      assert state.session.map_id == "guild_hall_v1"

      # Everyone is on a valid (non-collision) spawn of the new map; mute kept.
      blocked = RetroHexChat.VirtualSpace.Map.collision_set(state.map)

      for {_key, p} <- state.participants do
        refute MapSet.member?(blocked, {p.x, p.y})
      end

      assert state.participants[member_key].muted?
    end

    test "rejects a map id outside the registry" do
      ctx = start_space()

      assert {:error, :unknown_map} =
               SessionServer.admin_action(ctx.token, creator_actor(ctx), %{
                 kind: "change_map",
                 map_id: "castle_v9"
               })

      {:ok, state} = SessionServer.get_state(ctx.token)
      assert state.session.map_id == "tavern_cafe_v1"
    end
  end
end
