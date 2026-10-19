defmodule RetroHexChat.Games.DigestTest do
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Games.Channels
  alias RetroHexChat.Games.Digest
  alias RetroHexChat.Games.Results
  alias RetroHexChat.Games.Schema.GameResult

  @moduletag :integration

  setup do
    Application.put_env(:retro_hex_chat, :game_result_min_duration_ms, 0)

    on_exit(fn ->
      Application.delete_env(:retro_hex_chat, :game_result_min_duration_ms)

      for name <- Channels.names() do
        case ChannelRegistry.lookup(name) do
          {:ok, pid} -> ChannelSupervisor.stop_child(pid)
          {:error, :not_found} -> :ok
        end
      end
    end)

    ana = insert(:registered_nick, nickname: "ana")
    %{ana: %{id: ana.id, nickname: "ana"}}
  end

  defp lose_easily(player, game_id, payload) do
    {:ok, _row} =
      Results.record(%{
        game_id: game_id,
        origin: "ai",
        difficulty: "easy",
        p1: player,
        payload: payload,
        started_at: DateTime.add(DateTime.utc_now(), -60, :second)
      })
  end

  test "says the day's count and its leader in each game that was played", %{ana: ana} do
    lose_easily(ana, "hex_pong", %{"score" => %{"p1" => 11, "p2" => 3}, "winner" => 1})
    lose_easily(ana, "hex_pong", %{"score" => %{"p1" => 2, "p2" => 11}, "winner" => 2})

    yesterday = Date.add(Date.utc_today(), -1)
    noon = DateTime.new!(yesterday, ~T[12:00:00], "Etc/UTC")
    Repo.update_all(GameResult, set: [finished_at: noon])

    assert {:ok, %{posted: 1}} = Digest.post(yesterday)

    assert [%Message{content: content}] =
             Repo.all(
               from m in Message,
                 where: m.channel_name == "#hex-pong" and m.author_nickname == "GameServ"
             )

    assert content == "Yesterday in Hex Pong: 2 matches. Most wins: ana (1)."

    assert {:ok, %{posted: 0}} = Digest.post(Date.utc_today())
  end

  test "a score game names the best score" do
    assert Digest.line("hex_raid", 1, %{nickname: "ana", wins: 1, best: 900}) ==
             "Yesterday in Hex Raid: 1 match. Best score: ana (900)."

    assert Digest.line("hex_pong", 3, nil) == "Yesterday in Hex Pong: 3 matches."
  end
end
