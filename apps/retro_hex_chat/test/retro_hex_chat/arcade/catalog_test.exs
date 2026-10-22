defmodule RetroHexChat.Arcade.CatalogTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Arcade.Catalog

  describe "list_games/0" do
    test "keeps canonical game names across locales" do
      Gettext.put_locale(RetroHexChat.Gettext, "pt_BR")
      on_exit(fn -> Gettext.put_locale(RetroHexChat.Gettext, "en") end)

      assert Enum.map(Catalog.list_games(), & &1.name) == [
               "DOOM: Knee-Deep in the Dead",
               "Freedoom: Phase 1",
               "Freedoom: Phase 2",
               "FreeDM",
               "Chex Quest",
               "HacX: Twitch 'n Kill",
               "REKKR: Sunken Land",
               "Quake: Dimension of the Doomed",
               "LibreQuake",
               "Quake II: The Invasion",
               "Wolfenstein 3D: Escape from Castle",
               "Half-Life: Uplink",
               "Beneath a Steel Sky",
               "Drascula: The Vampire Strikes Back",
               "Dreamweb",
               "Flight of the Amazon Queen",
               "Lure of the Temptress",
               "Soltys"
             ]
    end

    test "each game has required fields" do
      for game <- Catalog.list_games() do
        assert is_binary(game.id)
        assert is_binary(game.name)
        assert is_binary(game.tagline)
        assert is_binary(game.description)
        assert game.engine in Catalog.engines()
        assert is_binary(game.controls)
        assert is_binary(game.icon)
      end
    end

    test "all game ids are unique" do
      ids = Enum.map(Catalog.list_games(), & &1.id)
      assert ids == Enum.uniq(ids)
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
      assert Catalog.valid_game_id?("wolfenstein_3d")
      assert Catalog.valid_game_id?("quake2_shareware")
      assert Catalog.valid_game_id?("halflife_uplink")
      assert Catalog.valid_game_id?("scummvm_bass")
      assert Catalog.valid_game_id?("scummvm_drascula")
      assert Catalog.valid_game_id?("scummvm_dreamweb")
      assert Catalog.valid_game_id?("scummvm_fotaq")
      assert Catalog.valid_game_id?("scummvm_lure")
      assert Catalog.valid_game_id?("scummvm_soltys")
    end

    test "returns false for invalid ids" do
      refute Catalog.valid_game_id?("nonexistent")
      refute Catalog.valid_game_id?("")
    end
  end

  describe "game_ids/0" do
    test "returns list of all game id strings" do
      ids = Catalog.game_ids()
      assert length(ids) == 18
      assert Enum.all?(ids, &is_binary/1)
    end
  end

  describe "game_url/1" do
    setup do
      original = Application.fetch_env!(:retro_hex_chat, :arcade_base_url)
      Application.put_env(:retro_hex_chat, :arcade_base_url, "https://example.test/arcade")
      on_exit(fn -> Application.put_env(:retro_hex_chat, :arcade_base_url, original) end)
      :ok
    end

    test "builds per-game URL for doom game" do
      {:ok, game} = Catalog.get_game("doom_shareware")
      assert Catalog.game_url(game) == "https://example.test/arcade/doom_shareware/index.html"
    end

    test "builds shared engine URL with fragment for scummvm game" do
      {:ok, game} = Catalog.get_game("scummvm_bass")

      assert Catalog.game_url(game) ==
               "https://example.test/arcade/scummvm/index.html#-p /data/games/bass/ sky"
    end
  end

  describe "engines/0" do
    test "names every engine its games run on, in the order they are listed" do
      listed = Catalog.list_games() |> Enum.map(& &1.engine) |> Enum.dedup()

      assert listed == Catalog.engines()
      assert Catalog.engine_name(:quake2) == "Quake II"
    end
  end
end
