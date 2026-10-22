defmodule RetroHexChat.Arcade.DigestTest do
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  alias RetroHexChat.Arcade.{Digest, Queries}
  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Chat.Message

  @moduletag :integration

  setup do
    on_exit(fn ->
      for name <- ["#doom-shareware", "#hacx"] do
        case ChannelRegistry.lookup(name) do
          {:ok, pid} -> ChannelSupervisor.stop_child(pid)
          {:error, :not_found} -> :ok
        end
      end
    end)

    %{
      ana: insert(:registered_nick, nickname: "ana"),
      beto: insert(:registered_nick, nickname: "beto")
    }
  end

  defp played(player, game_id, at) do
    {:ok, _session} =
      Queries.insert_session(%{
        token: "t#{System.unique_integer([:positive])}",
        creator_id: player.id,
        status: "playing",
        game_id: game_id,
        game_started_at: at
      })
  end

  test "says the day's plays and players in each game that was played", %{ana: ana, beto: beto} do
    insert_game_announcer(["#doom-shareware", "#hacx"], name: "Pixel", nickname: "Pixel")
    day = ~D[2026-10-20]

    played(ana, "doom_shareware", ~U[2026-10-20 09:00:00Z])
    played(ana, "doom_shareware", ~U[2026-10-20 10:00:00Z])
    played(beto, "doom_shareware", ~U[2026-10-20 23:59:00Z])
    # The next day is the next digest's.
    played(beto, "hacx", ~U[2026-10-21 00:01:00Z])

    assert {:ok, %{posted: 1}} = Digest.post(day)

    assert [%Message{channel_name: "#doom-shareware", content: line}] = Repo.all(Message)
    assert line == "Yesterday, DOOM: Knee-Deep in the Dead was started 3 times by 2 players."
  end

  test "a game the catalogue no longer has says nothing, and the others still do", %{ana: ana} do
    insert_game_announcer(["#doom-shareware"], name: "Pixel", nickname: "Pixel")
    played(ana, "retired_game", ~U[2026-10-20 09:00:00Z])
    played(ana, "doom_shareware", ~U[2026-10-20 10:00:00Z])

    assert {:ok, %{posted: 1}} = Digest.post(~D[2026-10-20])
  end

  test "one play by one player reads in the singular" do
    assert Digest.line("hacx", %{plays: 1, people: 1}) ==
             "Yesterday, HacX: Twitch 'n Kill was started once by 1 player."
  end
end
