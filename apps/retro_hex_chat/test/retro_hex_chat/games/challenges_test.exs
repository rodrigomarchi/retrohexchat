defmodule RetroHexChat.Games.ChallengesTest do
  use RetroHexChat.DataCase, async: false

  import RetroHexChat.Factory

  alias RetroHexChat.Channels.Registry, as: ChannelRegistry
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Games.Challenges
  alias RetroHexChat.Games.Channels
  alias RetroHexChat.Games.Queries

  @moduletag :integration

  # A Monday of an ISO week with an even number, and the next one.
  @monday ~D[2026-10-12]

  setup do
    on_exit(fn ->
      for name <- Channels.names(),
          {:ok, pid} <- [ChannelRegistry.lookup(name)],
          do: ChannelSupervisor.stop_child(pid)
    end)

    %{
      ana: insert(:registered_nick, nickname: "ana"),
      beto: insert(:registered_nick, nickname: "beto")
    }
  end

  defp played(attrs) do
    finished_at = Map.fetch!(attrs, :finished_at)

    {:ok, _row} =
      Queries.insert(
        Map.merge(
          %{
            base_id: "hex_hockey",
            origin: "p2p",
            p2_nickname: "beto",
            p1_score: 3,
            p2_score: 1,
            outcome: "p1",
            ranked: true,
            duration_ms: 120_000,
            started_at: DateTime.add(finished_at, -120, :second),
            lobby_token: "c-#{System.unique_integer([:positive])}"
          },
          attrs
        )
      )
  end

  test "each week puts the next variant of the game up, the same all week" do
    this_week = Challenges.for_week("hex_hockey", @monday)

    assert this_week == Challenges.for_week("hex_hockey", Date.add(@monday, 6))
    assert this_week.starts_at == ~U[2026-10-12 00:00:00Z]
    assert this_week.ends_at == ~U[2026-10-19 00:00:00Z]

    variants =
      for week <- 0..2, do: Challenges.for_week("hex_hockey", Date.add(@monday, 7 * week)).game_id

    assert Enum.sort(variants) == ~w(hex_hockey hex_hockey_blitz hex_hockey_showdown)
  end

  test "the leader is whoever won most of the week's variant against people", ctx do
    challenge = Challenges.for_week("hex_hockey", @monday)
    noon = DateTime.add(challenge.starts_at, 12, :hour)

    played(%{
      game_id: challenge.game_id,
      p1_id: ctx.ana.id,
      p1_nickname: "ana",
      p2_id: ctx.beto.id,
      finished_at: noon
    })

    # Another week's matches, and another variant's, do not count.
    played(%{
      game_id: challenge.game_id,
      p1_id: ctx.beto.id,
      p1_nickname: "beto",
      p2_id: ctx.ana.id,
      p2_nickname: "ana",
      finished_at: DateTime.add(challenge.ends_at, 1, :hour)
    })

    assert %{nickname: "ana", wins: 1} = Challenges.leader(challenge)
    assert Challenges.leader(Challenges.for_week("hex_hockey", Date.add(@monday, 7))) == nil
  end

  test "Monday closes last week's challenge and opens this one in each game's channel", ctx do
    last_week = Challenges.for_week("hex_hockey", @monday)

    played(%{
      game_id: last_week.game_id,
      p1_id: ctx.ana.id,
      p1_nickname: "ana",
      p2_id: ctx.beto.id,
      finished_at: DateTime.add(last_week.starts_at, 1, :day)
    })

    for name <- Channels.names(), do: Channels.ensure(name)

    next_monday = Date.add(@monday, 7)
    assert {:ok, %{posted: posted}} = Challenges.turn_week(next_monday)
    assert posted == length(Catalog.base_games())

    [line] =
      Repo.all(
        from m in Message,
          where: m.channel_name == "#hex-hockey" and m.author_nickname == "GameServ",
          select: m.content
      )

    {:ok, last_game} = Catalog.get_game(last_week.game_id)

    {:ok, this_game} =
      Catalog.get_game(Challenges.for_week("hex_hockey", next_monday).game_id)

    assert line =~ "ana won last week's challenge in #{last_game.name}."
    assert line =~ "This week's challenge is #{this_game.name}."
  end
end
