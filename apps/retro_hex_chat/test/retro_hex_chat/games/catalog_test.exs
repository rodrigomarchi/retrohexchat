defmodule RetroHexChat.Games.CatalogTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Games.Catalog

  describe "list_games/0" do
    test "returns all games" do
      games = Catalog.list_games()
      assert length(games) == 34
    end

    test "each game has required fields" do
      for game <- Catalog.list_games() do
        assert is_binary(game.id)
        assert is_binary(game.name)
        assert is_binary(game.tagline)
        assert is_binary(game.description)
        assert is_binary(game.icon)
        assert is_binary(game.controls)
      end
    end

    test "all game ids are unique" do
      ids = Enum.map(Catalog.list_games(), & &1.id)
      assert ids == Enum.uniq(ids)
    end

    test "includes expected games" do
      ids = Enum.map(Catalog.list_games(), & &1.id)
      assert "hex_pong" in ids
      assert "light_trails" in ids
      assert "pixel_tanks" in ids
      assert "star_duel" in ids
      assert "gravity_well" in ids
      assert "debris_field" in ids
      assert "block_breakers" in ids
      assert "hex_warlords" in ids
      assert "hex_raid" in ids
      assert "hex_raid_pacifist" in ids
      assert "hex_raid_blitz" in ids
      assert "hex_boxing" in ids
      assert "hex_outlaw" in ids
      assert "hex_outlaw_ricochet" in ids
      assert "hex_outlaw_stagecoach" in ids
      assert "hex_outlaw_nml" in ids
      assert "hex_invaders" in ids
      assert "hex_invaders_coop" in ids
      assert "hex_invaders_blitz" in ids
      assert "hex_enduro" in ids
      assert "hex_enduro_night" in ids
      assert "hex_enduro_sprint" in ids
      assert "hex_tennis" in ids
      assert "hex_tennis_quick" in ids
      assert "hex_tennis_sudden" in ids
      assert "hex_skiing" in ids
      assert "hex_skiing_escape" in ids
      assert "hex_skiing_clean" in ids
      assert "hex_frost" in ids
      assert "hex_frost_blizzard" in ids
      assert "hex_frost_peaceful" in ids
      assert "hex_hockey" in ids
      assert "hex_hockey_blitz" in ids
      assert "hex_hockey_showdown" in ids
    end
  end

  describe "get_game/1" do
    test "returns game for valid id" do
      assert {:ok, game} = Catalog.get_game("hex_pong")
      assert game.name == "Hex Pong"
    end

    test "returns error for unknown id" do
      assert {:error, :not_found} = Catalog.get_game("nonexistent")
    end
  end

  describe "list_solo_games/0" do
    test "returns the games with a browser solo runtime" do
      assert [
               %{id: "hex_pong", name: "Hex Pong"},
               %{id: "light_trails", name: "Light Trails"},
               %{id: "star_duel", name: "Star Duel"},
               %{id: "gravity_well", name: "Gravity Well"},
               %{id: "debris_field", name: "Debris Field"},
               %{id: "hex_outlaw", name: "Hex Outlaw"},
               %{id: "hex_outlaw_ricochet", name: "Hex Outlaw: Ricochet"},
               %{id: "hex_outlaw_stagecoach", name: "Hex Outlaw: Stagecoach"},
               %{id: "hex_outlaw_nml", name: "Hex Outlaw: No Man's Land"},
               %{id: "hex_invaders", name: "Hex Invaders"},
               %{id: "hex_invaders_coop", name: "Hex Invaders: Co-op"},
               %{id: "hex_invaders_blitz", name: "Hex Invaders: Blitz"},
               %{id: "hex_tennis", name: "Hex Tennis"},
               %{id: "hex_tennis_quick", name: "Hex Tennis: Quick Match"},
               %{id: "hex_tennis_sudden", name: "Hex Tennis: Sudden Death"},
               %{id: "hex_hockey", name: "Hex Hockey"},
               %{id: "hex_hockey_blitz", name: "Hex Hockey: Blitz"},
               %{id: "hex_hockey_showdown", name: "Hex Hockey: Showdown"}
             ] = Catalog.list_solo_games()
    end

    test "localizes controls using the current domain locale" do
      previous_locale = Gettext.get_locale(RetroHexChat.Gettext)

      try do
        Gettext.put_locale(RetroHexChat.Gettext, "pt_BR")

        assert [
                 %{id: "hex_pong", controls: "Setas ou W/S para mover a pá"},
                 %{id: "light_trails", controls: "Setas para mudar de direção"},
                 %{
                   id: "star_duel",
                   controls:
                     "Setas ou WASD para empurrar/rotar, espaço para disparar, Down/S para warp"
                 },
                 %{
                   id: "gravity_well",
                   controls:
                     "Setas ou WASD para empurrar/rotar, espaço para disparar, Down/S para warp"
                 },
                 %{
                   id: "debris_field",
                   controls:
                     "Setas ou WASD para empurrar/rotar, espaço para disparar, Down/S para warp"
                 },
                 %{
                   id: "hex_outlaw",
                   controls: "Setas ou WASD para mover, Espaço ou Shift para disparar"
                 },
                 %{
                   id: "hex_outlaw_ricochet",
                   controls: "Setas ou WASD para mover/alvo, espaço ou Shift para disparar"
                 },
                 %{
                   id: "hex_outlaw_stagecoach",
                   controls: "Setas ou WASD para mover, Espaço ou Shift para disparar"
                 },
                 %{
                   id: "hex_outlaw_nml",
                   controls: "Setas ou WASD para mover, Espaço ou Shift para disparar"
                 },
                 %{
                   id: "hex_invaders",
                   controls: "Setas ou A/D para mover, Espaço para disparar"
                 },
                 %{
                   id: "hex_invaders_coop",
                   controls: "Setas ou A/D para mover, Espaço para disparar"
                 },
                 %{
                   id: "hex_invaders_blitz",
                   controls: "Setas ou A/D para mover, Espaço para disparar"
                 },
                 %{
                   id: "hex_tennis",
                   controls: "Setas ou WASD para mover, Espaço ou Shift para servir"
                 },
                 %{
                   id: "hex_tennis_quick",
                   controls: "Setas ou WASD para mover, Espaço ou Shift para servir"
                 },
                 %{
                   id: "hex_tennis_sudden",
                   controls: "Setas ou WASD para mover, Espaço ou Shift para servir"
                 },
                 %{
                   id: "hex_hockey",
                   controls: "Setas ou WASD para mover, Espaço ou Shift para chutar/desarmar"
                 },
                 %{
                   id: "hex_hockey_blitz",
                   controls: "Setas ou WASD para mover, Espaço ou Shift para chutar/desarmar"
                 },
                 %{
                   id: "hex_hockey_showdown",
                   controls: "Setas ou WASD para mover, Espaço ou Shift para chutar/desarmar"
                 }
               ] = Catalog.list_solo_games()
      after
        Gettext.put_locale(RetroHexChat.Gettext, previous_locale)
      end
    end
  end

  describe "solo_game_id?/1" do
    test "accepts only games exposed in Retro Games" do
      assert Catalog.solo_game_id?("hex_pong")
      assert Catalog.solo_game_id?("light_trails")
      assert Catalog.solo_game_id?("star_duel")
      assert Catalog.solo_game_id?("gravity_well")
      assert Catalog.solo_game_id?("debris_field")
      assert Catalog.solo_game_id?("hex_outlaw")
      assert Catalog.solo_game_id?("hex_outlaw_ricochet")
      assert Catalog.solo_game_id?("hex_outlaw_stagecoach")
      assert Catalog.solo_game_id?("hex_outlaw_nml")
      assert Catalog.solo_game_id?("hex_invaders")
      assert Catalog.solo_game_id?("hex_invaders_coop")
      assert Catalog.solo_game_id?("hex_invaders_blitz")
      assert Catalog.solo_game_id?("hex_tennis")
      assert Catalog.solo_game_id?("hex_tennis_quick")
      assert Catalog.solo_game_id?("hex_tennis_sudden")
      assert Catalog.solo_game_id?("hex_hockey")
      assert Catalog.solo_game_id?("hex_hockey_blitz")
      assert Catalog.solo_game_id?("hex_hockey_showdown")
      refute Catalog.solo_game_id?("nonexistent")
    end
  end

  describe "valid_game_id?/1" do
    test "returns true for valid ids" do
      assert Catalog.valid_game_id?("hex_pong")
      assert Catalog.valid_game_id?("light_trails")
      assert Catalog.valid_game_id?("pixel_tanks")
      assert Catalog.valid_game_id?("star_duel")
      assert Catalog.valid_game_id?("gravity_well")
      assert Catalog.valid_game_id?("debris_field")
      assert Catalog.valid_game_id?("block_breakers")
      assert Catalog.valid_game_id?("hex_warlords")
      assert Catalog.valid_game_id?("hex_raid")
      assert Catalog.valid_game_id?("hex_raid_pacifist")
      assert Catalog.valid_game_id?("hex_raid_blitz")
      assert Catalog.valid_game_id?("hex_boxing")
      assert Catalog.valid_game_id?("hex_outlaw")
      assert Catalog.valid_game_id?("hex_outlaw_ricochet")
      assert Catalog.valid_game_id?("hex_outlaw_stagecoach")
      assert Catalog.valid_game_id?("hex_outlaw_nml")
      assert Catalog.valid_game_id?("hex_invaders")
      assert Catalog.valid_game_id?("hex_invaders_coop")
      assert Catalog.valid_game_id?("hex_invaders_blitz")
      assert Catalog.valid_game_id?("hex_enduro")
      assert Catalog.valid_game_id?("hex_enduro_night")
      assert Catalog.valid_game_id?("hex_enduro_sprint")
      assert Catalog.valid_game_id?("hex_tennis")
      assert Catalog.valid_game_id?("hex_tennis_quick")
      assert Catalog.valid_game_id?("hex_tennis_sudden")
      assert Catalog.valid_game_id?("hex_skiing")
      assert Catalog.valid_game_id?("hex_skiing_escape")
      assert Catalog.valid_game_id?("hex_skiing_clean")
      assert Catalog.valid_game_id?("hex_frost")
      assert Catalog.valid_game_id?("hex_frost_blizzard")
      assert Catalog.valid_game_id?("hex_frost_peaceful")
      assert Catalog.valid_game_id?("hex_hockey")
      assert Catalog.valid_game_id?("hex_hockey_blitz")
      assert Catalog.valid_game_id?("hex_hockey_showdown")
    end

    test "returns false for invalid ids" do
      refute Catalog.valid_game_id?("nonexistent")
      refute Catalog.valid_game_id?("")
    end
  end

  describe "game_ids/0" do
    test "returns list of all game id strings" do
      ids = Catalog.game_ids()
      assert length(ids) == 34
      assert Enum.all?(ids, &is_binary/1)
    end
  end
end
