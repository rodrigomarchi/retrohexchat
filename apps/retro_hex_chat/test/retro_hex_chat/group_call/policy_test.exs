defmodule RetroHexChat.GroupCall.PolicyTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Channels.Membership
  alias RetroHexChat.GroupCall.{Policy, Queries}
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration

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
  defp unique_nick(prefix), do: "#{prefix}#{System.unique_integer([:positive])}"

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
  end
end
