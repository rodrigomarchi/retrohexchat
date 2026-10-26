defmodule RetroHexChat.Commands.Handlers.ChallengeTest do
  use RetroHexChat.DataCase, async: true

  import RetroHexChat.Factory

  alias RetroHexChat.Commands.Handlers.Challenge
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Topics

  @moduletag :integration

  defp context(channel) do
    %{
      nickname: "alice",
      active_channel: channel,
      channels: [channel],
      identified: true,
      operator_in: []
    }
  end

  test "is a P2P invite that carries the channel's game" do
    insert(:registered_nick, nickname: "alice")
    bob = insert(:registered_nick, nickname: "bob")
    {:ok, _ref} = Tracker.track_user(Topics.presence(), "bob", %{})

    assert {:ok, :ui_action, :lobby_invite, %{target: "bob", target_id: target_id, game_id: game}} =
             Challenge.execute(["bob", "quick"], context("#hex-tennis"))

    assert target_id == bob.id
    assert game == "hex_tennis_quick"
  end

  test "refuses outside a game's channel before asking anything else" do
    assert {:error, message} = Challenge.execute(["bob"], context("#lobby"))
    assert message =~ "game's own channel"
  end

  test "needs somebody to challenge" do
    assert {:error, "Usage: /challenge" <> _} = Challenge.execute([], context("#hex-pong"))
    assert {:error, _usage} = Challenge.validate("")
  end

  test "not in a game played alone" do
    assert {:error, "Hex Jungle is a game for one player."} =
             Challenge.execute(["bob"], context("#hex-jungle"))
  end
end
