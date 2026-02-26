defmodule RetroHexChat.Arcade.CatalogTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Arcade.Catalog

  describe "list_games/0" do
    test "returns all games" do
      games = Catalog.list_games()
      assert length(games) == 9
    end

    test "each game has required fields" do
      for game <- Catalog.list_games() do
        assert is_binary(game.id)
        assert is_binary(game.name)
        assert is_binary(game.tagline)
        assert is_binary(game.description)
        assert game.engine in [:doom, :quake]
        assert is_binary(game.controls)
        assert is_binary(game.icon)
      end
    end

    test "all game ids are unique" do
      ids = Enum.map(Catalog.list_games(), & &1.id)
      assert ids == Enum.uniq(ids)
    end

    test "includes expected games" do
      ids = Enum.map(Catalog.list_games(), & &1.id)
      assert "doom_shareware" in ids
      assert "freedoom1" in ids
      assert "freedoom2" in ids
      assert "freedm" in ids
      assert "chex_quest" in ids
      assert "hacx" in ids
      assert "rekkr" in ids
      assert "quake_shareware" in ids
      assert "librequake" in ids
    end
  end

  describe "get_game/1" do
    test "returns game for valid id" do
      assert {:ok, game} = Catalog.get_game("doom_shareware")
      assert game.name == "DOOM: Knee-Deep in the Dead"
      assert game.engine == :doom
    end

    test "returns error for unknown id" do
      assert {:error, :not_found} = Catalog.get_game("nonexistent")
    end
  end

  describe "valid_game_id?/1" do
    test "returns true for valid ids" do
      assert Catalog.valid_game_id?("doom_shareware")
      assert Catalog.valid_game_id?("freedoom1")
      assert Catalog.valid_game_id?("freedoom2")
      assert Catalog.valid_game_id?("freedm")
      assert Catalog.valid_game_id?("chex_quest")
      assert Catalog.valid_game_id?("hacx")
      assert Catalog.valid_game_id?("rekkr")
      assert Catalog.valid_game_id?("quake_shareware")
      assert Catalog.valid_game_id?("librequake")
    end

    test "returns false for invalid ids" do
      refute Catalog.valid_game_id?("nonexistent")
      refute Catalog.valid_game_id?("")
    end
  end

  describe "game_ids/0" do
    test "returns list of all game id strings" do
      ids = Catalog.game_ids()
      assert length(ids) == 9
      assert Enum.all?(ids, &is_binary/1)
    end
  end

  describe "game_url/1" do
    test "builds per-game URL for doom game" do
      {:ok, game} = Catalog.get_game("doom_shareware")
      assert Catalog.game_url(game) == "/arcade/doom_shareware/index.html"
    end

    test "builds per-game URL for quake game" do
      {:ok, game} = Catalog.get_game("quake_shareware")
      assert Catalog.game_url(game) == "/arcade/quake_shareware/index.html"
    end

    test "builds per-game URL for new games" do
      {:ok, game} = Catalog.get_game("chex_quest")
      assert Catalog.game_url(game) == "/arcade/chex_quest/index.html"
    end
  end
end
