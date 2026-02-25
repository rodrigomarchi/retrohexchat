defmodule RetroHexChat.Games.CatalogTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Games.Catalog

  describe "list_games/0" do
    test "returns all games" do
      games = Catalog.list_games()
      assert length(games) == 28
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
    end

    test "returns false for invalid ids" do
      refute Catalog.valid_game_id?("nonexistent")
      refute Catalog.valid_game_id?("")
    end
  end

  describe "game_ids/0" do
    test "returns list of all game id strings" do
      ids = Catalog.game_ids()
      assert length(ids) == 28
      assert Enum.all?(ids, &is_binary/1)
    end
  end
end
