defmodule RetroHexChat.Commands.Handlers.LfgTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Commands.Handlers.Lfg

  @context %{
    nickname: "Alice",
    active_channel: "#hex-hockey",
    channels: ["#hex-hockey"],
    identified: true,
    operator_in: []
  }

  test "opens a seat for the channel's game" do
    assert {:ok, :ui_action, :game_lfg, %{channel: "#hex-hockey", game_id: "hex_hockey"}} =
             Lfg.execute([], @context)
  end

  test "a mode word picks the mode" do
    assert {:ok, :ui_action, :game_lfg, %{game_id: "hex_hockey_blitz"}} =
             Lfg.execute(["blitz"], @context)

    assert {:error, message} = Lfg.execute(["turbo"], @context)
    assert message =~ "turbo"
  end

  test "only in a game's channel" do
    assert {:error, message} = Lfg.execute([], %{@context | active_channel: "#lobby"})
    assert message =~ "#hex-pong"
  end

  test "only for an identified nickname" do
    assert {:error, _not_identified} = Lfg.execute([], %{@context | identified: false})
  end

  test "not for a game played alone, which says how it is played" do
    jungle = %{@context | active_channel: "#hex-jungle", channels: ["#hex-jungle"]}
    assert {:error, message} = Lfg.execute([], jungle)
    assert message == "Hex Jungle is a game for one player."
  end
end
