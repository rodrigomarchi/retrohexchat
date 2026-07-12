defmodule RetroHexChat.GroupCall.PolicyTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Channels.Membership
  alias RetroHexChat.GroupCall.{Policy, Queries}
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration

  @member_roles [:owner, :operator, :half_operator, :voiced, :regular]
  @moderator_roles [:owner, :operator, :half_operator]

  defp create_registered_nick(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> Repo.insert()

    nick
  end

  defp create_room(attrs \\ %{}) do
    creator =
      Map.get_lazy(attrs, :creator, fn -> create_registered_nick(unique_nick("creator")) end)

    attrs =
      attrs
      |> Map.drop([:creator])
      |> Map.merge(%{
        token: Map.get(attrs, :token, unique_token("room")),
        channel_name: Map.get(attrs, :channel_name, "#calls"),
        creator_id: creator.id,
        creator_nick: creator.nickname,
        status: Map.get(attrs, :status, "pending")
      })

    {:ok, room} = Queries.insert_room(attrs)
    room
  end

  defp unique_token(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  defp unique_nick(prefix),
    do: "#{prefix}#{System.unique_integer([:positive])}" |> String.slice(0, 16)

  defp role_nick(role), do: role |> Atom.to_string() |> String.replace("_", "")

  defp assert_policy_result(expected?, result) do
    if expected? do
      assert :ok = result
    else
      assert {:error, _message} = result
    end
  end

  describe "can_create_channel_call?/4" do
    test "allows a registered channel member to create a room" do
      nick = create_registered_nick(unique_nick("alice"))
      membership = Membership.new() |> Membership.add(nick.nickname, :regular)

      assert :ok =
               Policy.can_create_channel_call?(nick.id, nick.nickname, "#calls", membership)
    end

    test "rejects unregistered users" do
      membership = Membership.new() |> Membership.add("Guest", :regular)

      assert {:error, message} =
               Policy.can_create_channel_call?(nil, "Guest", "#calls", membership)

      assert message =~ "registered"
    end

    test "rejects non-members" do
      nick = create_registered_nick(unique_nick("alice"))
      membership = Membership.new()

      assert {:error, message} =
               Policy.can_create_channel_call?(nick.id, nick.nickname, "#calls", membership)

      assert message =~ "not in this channel"
    end

    test "rejects a channel that already has an active room" do
      nick = create_registered_nick(unique_nick("alice"))
      _room = create_room(%{creator: nick, channel_name: "#busy"})
      membership = Membership.new() |> Membership.add(nick.nickname, :operator)

      assert {:error, message} =
               Policy.can_create_channel_call?(nick.id, nick.nickname, "#busy", membership)

      assert message =~ "already has"
    end

    test "allows every registered channel role to create a room" do
      for role <- @member_roles do
        nick = create_registered_nick(unique_nick(role_nick(role)))
        membership = Membership.new() |> Membership.add(nick.nickname, role)

        assert :ok =
                 Policy.can_create_channel_call?(
                   nick.id,
                   nick.nickname,
                   "##{unique_token("create")}",
                   membership
                 )
      end
    end
  end

  describe "can_join?/4" do
    test "allows a registered member to join a non-terminal room" do
      room = create_room(%{channel_name: "#join"})
      nick = create_registered_nick(unique_nick("alice"))
      membership = Membership.new() |> Membership.add(nick.nickname, :regular)

      assert :ok = Policy.can_join?(nick.id, nick.nickname, room, membership)
    end

    test "rejects terminal rooms" do
      room =
        create_room(%{
          status: "closed",
          closed_at: DateTime.utc_now(),
          closed_reason: "ended"
        })

      nick = create_registered_nick(unique_nick("alice"))
      membership = Membership.new() |> Membership.add(nick.nickname, :regular)

      assert {:error, message} = Policy.can_join?(nick.id, nick.nickname, room, membership)
      assert message =~ "no longer active"
    end

    test "allows every registered channel role to join a non-terminal room" do
      room = create_room(%{channel_name: "##{unique_token("join")}"})

      for role <- @member_roles do
        nick = create_registered_nick(unique_nick(role_nick(role)))
        membership = Membership.new() |> Membership.add(nick.nickname, role)

        assert :ok = Policy.can_join?(nick.id, nick.nickname, room, membership)
      end
    end

    test "rejects guests even when a matching nickname exists in membership" do
      room = create_room(%{channel_name: "##{unique_token("guest")}"})
      membership = Membership.new() |> Membership.add("Guest", :regular)

      assert {:error, message} = Policy.can_join?(nil, "Guest", room, membership)
      assert message =~ "registered"
    end

    test "rejects lower-ranked members when the room is locked" do
      room =
        create_room(%{channel_name: "##{unique_token("locked")}", metadata: %{"locked" => true}})

      nick = create_registered_nick(unique_nick("regular"))
      membership = Membership.new() |> Membership.add(nick.nickname, :regular)

      assert {:error, message} = Policy.can_join?(nick.id, nick.nickname, room, membership)
      assert message =~ "locked"
    end

    test "allows moderators to join a locked room" do
      room =
        create_room(%{channel_name: "##{unique_token("locked")}", metadata: %{"locked" => true}})

      for role <- @moderator_roles do
        nick = create_registered_nick(unique_nick(role_nick(role)))
        membership = Membership.new() |> Membership.add(nick.nickname, role)

        assert :ok = Policy.can_join?(nick.id, nick.nickname, room, membership)
      end
    end
  end

  describe "moderation policy" do
    test "half operators and above can close a room" do
      room = create_room()
      membership = Membership.new() |> Membership.add("HalfOp", :half_operator)

      assert :ok = Policy.can_close?("HalfOp", room, membership)
    end

    test "regular users cannot close a room" do
      room = create_room()
      membership = Membership.new() |> Membership.add("Alice", :regular)

      assert {:error, message} = Policy.can_close?("Alice", room, membership)
      assert message =~ "Insufficient"
    end

    test "kicking participants follows channel kick policy" do
      membership =
        Membership.new()
        |> Membership.add("Op", :operator)
        |> Membership.add("User", :regular)

      assert :ok = Policy.can_kick_participant?(membership, "Op", "User")
    end

    test "media moderation follows channel kick policy" do
      membership =
        Membership.new()
        |> Membership.add("User", :regular)
        |> Membership.add("Op", :operator)

      assert {:error, _message} = Policy.can_moderate_media?(membership, "User", "Op")
    end

    test "close room permission is explicit for each channel role" do
      room = create_room()

      for role <- @member_roles do
        actor = role_nick(role)
        membership = Membership.new() |> Membership.add(actor, role)

        assert_policy_result(
          role in @moderator_roles,
          Policy.can_close?(actor, room, membership)
        )
      end

      assert {:error, _message} = Policy.can_close?("Guest", room, Membership.new())
    end

    test "kick participant permission follows channel rank for every role pair" do
      for actor_role <- @member_roles, target_role <- @member_roles do
        actor = "actor-#{role_nick(actor_role)}"
        target = "target-#{role_nick(target_role)}"

        membership =
          Membership.new()
          |> Membership.add(actor, actor_role)
          |> Membership.add(target, target_role)

        expected? =
          actor_role in @moderator_roles and
            Membership.rank(actor_role) > Membership.rank(target_role)

        assert_policy_result(
          expected?,
          Policy.can_kick_participant?(membership, actor, target)
        )
      end

      membership = Membership.new() |> Membership.add("Target", :regular)
      assert {:error, _message} = Policy.can_kick_participant?(membership, "Guest", "Target")
    end

    test "media moderation permission follows the same rank matrix as participant kick" do
      for actor_role <- @member_roles, target_role <- @member_roles do
        actor = "actor-#{role_nick(actor_role)}"
        target = "target-#{role_nick(target_role)}"

        membership =
          Membership.new()
          |> Membership.add(actor, actor_role)
          |> Membership.add(target, target_role)

        expected? =
          actor_role in @moderator_roles and
            Membership.rank(actor_role) > Membership.rank(target_role)

        assert_policy_result(
          expected?,
          Policy.can_moderate_media?(membership, actor, target)
        )
      end

      membership = Membership.new() |> Membership.add("Target", :regular)
      assert {:error, _message} = Policy.can_moderate_media?(membership, "Guest", "Target")
    end
  end
end
