defmodule RetroHexChat.Games.CatalogTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Games.Catalog

  describe "list_games/0" do
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

  describe "list_games/0, game by game" do
    test "returns the games with a browser solo runtime" do
      assert [
               %{id: "hex_pong", name: "Hex Pong"},
               %{id: "light_trails", name: "Light Trails"},
               %{id: "pixel_tanks", name: "Pixel Tanks"},
               %{id: "star_duel", name: "Star Duel"},
               %{id: "gravity_well", name: "Gravity Well"},
               %{id: "debris_field", name: "Debris Field"},
               %{id: "block_breakers", name: "Block Breakers"},
               %{id: "hex_warlords", name: "Hex Warlords"},
               %{id: "hex_raid", name: "Hex Raid"},
               %{id: "hex_raid_pacifist", name: "Hex Raid: Pacifist"},
               %{id: "hex_raid_blitz", name: "Hex Raid: Blitz"},
               %{id: "hex_boxing", name: "Hex Boxing"},
               %{id: "hex_outlaw", name: "Hex Outlaw"},
               %{id: "hex_outlaw_ricochet", name: "Hex Outlaw: Ricochet"},
               %{id: "hex_outlaw_stagecoach", name: "Hex Outlaw: Stagecoach"},
               %{id: "hex_outlaw_nml", name: "Hex Outlaw: No Man's Land"},
               %{id: "hex_invaders", name: "Hex Invaders"},
               %{id: "hex_invaders_coop", name: "Hex Invaders: Co-op"},
               %{id: "hex_invaders_blitz", name: "Hex Invaders: Blitz"},
               %{id: "hex_enduro", name: "Hex Enduro"},
               %{id: "hex_enduro_night", name: "Hex Enduro: Night Race"},
               %{id: "hex_enduro_sprint", name: "Hex Enduro: Sprint"},
               %{id: "hex_tennis", name: "Hex Tennis"},
               %{id: "hex_tennis_quick", name: "Hex Tennis: Quick Match"},
               %{id: "hex_tennis_sudden", name: "Hex Tennis: Sudden Death"},
               %{id: "hex_skiing", name: "Hex Skiing"},
               %{id: "hex_skiing_escape", name: "Hex Skiing: Escape"},
               %{id: "hex_skiing_clean", name: "Hex Skiing: Clean Run"},
               %{id: "hex_frost", name: "Hex Frost"},
               %{id: "hex_frost_blizzard", name: "Hex Frost: Blizzard"},
               %{id: "hex_frost_peaceful", name: "Hex Frost: Peaceful"},
               %{id: "hex_hockey", name: "Hex Hockey"},
               %{id: "hex_hockey_blitz", name: "Hex Hockey: Blitz"},
               %{id: "hex_hockey_showdown", name: "Hex Hockey: Showdown"},
               %{id: "hex_jungle", name: "Hex Jungle"},
               %{id: "hex_solitaire", name: "Hex Solitaire"},
               %{id: "hex_solitaire_draw3", name: "Hex Solitaire: Draw Three"}
             ] = Catalog.list_games()
    end

    # A description is one msgid, translated when the game is read: anything
    # assembled at compile time matches nothing in a catalog and reaches every
    # reader in English.
    test "localizes every description, whole" do
      english = Map.new(Catalog.list_games(), &{&1.id, &1.description})
      previous_locale = Gettext.get_locale(RetroHexChat.Gettext)

      try do
        Gettext.put_locale(RetroHexChat.Gettext, "pt_BR")

        for game <- Catalog.list_games() do
          assert game.description != english[game.id],
                 "#{game.id} reaches pt_BR readers untranslated"
        end
      after
        Gettext.put_locale(RetroHexChat.Gettext, previous_locale)
      end
    end

    test "localizes controls using the current domain locale" do
      previous_locale = Gettext.get_locale(RetroHexChat.Gettext)

      try do
        Gettext.put_locale(RetroHexChat.Gettext, "pt_BR")

        assert [
                 %{id: "hex_pong", controls: "Setas ou W/S para mover a pá"},
                 %{id: "light_trails", controls: "Setas para mudar de direção"},
                 %{
                   id: "pixel_tanks",
                   controls:
                     "Setas (Esquerda/Direita rotacionam, Cima avança), Espaço para disparar"
                 },
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
                   id: "block_breakers",
                   controls: "Setas (esquerda/direita) para mover a pá"
                 },
                 %{
                   id: "hex_warlords",
                   controls:
                     "Setas (Para cima/para baixo) para mover escudo, espaço para pegar / soltar bola de fogo"
                 },
                 %{
                   id: "hex_raid",
                   controls:
                     "Setas para mover/velocidade, Espaço para disparar, Shift para soltar a mina"
                 },
                 %{
                   id: "hex_raid_pacifist",
                   controls: "Setas para mover/velocidade, Espaço para disparar"
                 },
                 %{
                   id: "hex_raid_blitz",
                   controls:
                     "Setas para mover/velocidade, Espaço para disparar, Shift para soltar a mina"
                 },
                 %{
                   id: "hex_boxing",
                   controls: "Setas ou WASD para mover, Espaço ou Shift para socar"
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
                   id: "hex_enduro",
                   controls: "Setas (←/→ faixa, ↑ acelerar, ↓ frear), Espaço ou Shift para turbo"
                 },
                 %{
                   id: "hex_enduro_night",
                   controls: "Setas (←/→ faixa, ↑ acelerar, ↓ frear), Espaço ou Shift para turbo"
                 },
                 %{
                   id: "hex_enduro_sprint",
                   controls: "Setas (←/→ faixa, ↑ acelerar, ↓ frear), Espaço ou Shift para turbo"
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
                   id: "hex_skiing",
                   controls: "Setas (←/→) ou A/D para dirigir"
                 },
                 %{
                   id: "hex_skiing_escape",
                   controls: "Setas (←/→) ou A/D para dirigir"
                 },
                 %{
                   id: "hex_skiing_clean",
                   controls: "Setas (←/→) ou A/D para dirigir"
                 },
                 %{
                   id: "hex_frost",
                   controls:
                     "Setas ou WASD para mover, para cima/para baixo para saltar entre linhas"
                 },
                 %{
                   id: "hex_frost_blizzard",
                   controls:
                     "Setas ou WASD para mover, para cima/para baixo para saltar entre linhas"
                 },
                 %{
                   id: "hex_frost_peaceful",
                   controls:
                     "Setas ou WASD para mover, para cima/para baixo para saltar entre linhas"
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
                 },
                 %{
                   id: "hex_jungle",
                   controls: "Setas ou WASD para mover e subir, a barra de espaço para saltar"
                 },
                 %{
                   id: "hex_solitaire",
                   controls: "Toque para jogar, ou arraste com o mouse ou um dedo"
                 },
                 %{
                   id: "hex_solitaire_draw3",
                   controls: "Toque para jogar, ou arraste com o mouse ou um dedo"
                 }
               ] = Catalog.list_games()
      after
        Gettext.put_locale(RetroHexChat.Gettext, previous_locale)
      end
    end
  end

  describe "solo_game_id?/1" do
    test "accepts only games exposed in Retro Games" do
      assert Catalog.solo_game_id?("hex_pong")
      assert Catalog.solo_game_id?("light_trails")
      assert Catalog.solo_game_id?("pixel_tanks")
      assert Catalog.solo_game_id?("star_duel")
      assert Catalog.solo_game_id?("gravity_well")
      assert Catalog.solo_game_id?("debris_field")
      assert Catalog.solo_game_id?("block_breakers")
      assert Catalog.solo_game_id?("hex_warlords")
      assert Catalog.solo_game_id?("hex_raid")
      assert Catalog.solo_game_id?("hex_raid_pacifist")
      assert Catalog.solo_game_id?("hex_raid_blitz")
      assert Catalog.solo_game_id?("hex_boxing")
      assert Catalog.solo_game_id?("hex_outlaw")
      assert Catalog.solo_game_id?("hex_outlaw_ricochet")
      assert Catalog.solo_game_id?("hex_outlaw_stagecoach")
      assert Catalog.solo_game_id?("hex_outlaw_nml")
      assert Catalog.solo_game_id?("hex_invaders")
      assert Catalog.solo_game_id?("hex_invaders_coop")
      assert Catalog.solo_game_id?("hex_invaders_blitz")
      assert Catalog.solo_game_id?("hex_enduro")
      assert Catalog.solo_game_id?("hex_enduro_night")
      assert Catalog.solo_game_id?("hex_enduro_sprint")
      assert Catalog.solo_game_id?("hex_skiing")
      assert Catalog.solo_game_id?("hex_skiing_escape")
      assert Catalog.solo_game_id?("hex_skiing_clean")
      assert Catalog.solo_game_id?("hex_frost")
      assert Catalog.solo_game_id?("hex_frost_blizzard")
      assert Catalog.solo_game_id?("hex_frost_peaceful")
      assert Catalog.solo_game_id?("hex_tennis")
      assert Catalog.solo_game_id?("hex_tennis_quick")
      assert Catalog.solo_game_id?("hex_tennis_sudden")
      assert Catalog.solo_game_id?("hex_hockey")
      assert Catalog.solo_game_id?("hex_hockey_blitz")
      assert Catalog.solo_game_id?("hex_hockey_showdown")
      assert Catalog.solo_game_id?("hex_jungle")
      assert Catalog.solo_game_id?("hex_solitaire")
      assert Catalog.solo_game_id?("hex_solitaire_draw3")
      refute Catalog.solo_game_id?("nonexistent")
    end
  end

  describe "solo_only?/1" do
    test "names the games played by one person alone, ranked by score" do
      assert Catalog.solo_only?("hex_jungle")
      assert Catalog.ranking("hex_jungle") == :score

      for id <- ~w(hex_solitaire hex_solitaire_draw3) do
        assert Catalog.solo_only?(id)
        assert Catalog.ranking(id) == :score
      end

      refute Catalog.solo_only?("hex_raid")
      refute Catalog.solo_only?("hex_pong")
      refute Catalog.solo_only?("nonexistent")
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
      assert Catalog.valid_game_id?("hex_jungle")
    end

    test "returns false for invalid ids" do
      refute Catalog.valid_game_id?("nonexistent")
      refute Catalog.valid_game_id?("")
    end
  end

  describe "game_ids/0" do
    test "returns list of all game id strings" do
      ids = Catalog.game_ids()
      assert length(ids) == 37
      assert Enum.all?(ids, &is_binary/1)
    end
  end

  describe "games and their modes" do
    test "a base game is never a mode, and every mode names a base game" do
      base_ids = Enum.map(Catalog.base_games(), & &1.id)

      assert "hex_tennis" in base_ids
      refute "hex_tennis_quick" in base_ids

      for game <- Catalog.list_games(), mode_of = Map.get(game, :mode_of) do
        assert mode_of in base_ids, "#{game.id} is a mode of #{mode_of}, which is not a game"
      end
    end

    test "a game lists its modes in catalogue order" do
      assert Enum.map(Catalog.modes_of("hex_tennis"), & &1.id) ==
               ["hex_tennis_quick", "hex_tennis_sudden"]

      assert Catalog.modes_of("hex_pong") == []
    end

    test "every game is a base game or exactly one game's mode" do
      ids = Catalog.game_ids()

      covered =
        Enum.map(Catalog.base_games(), & &1.id) ++
          Enum.flat_map(
            Catalog.base_games(),
            &Enum.map(Catalog.modes_of(&1.id), fn mode -> mode.id end)
          )

      assert Enum.sort(covered) == Enum.sort(ids)
    end
  end

  describe "channels" do
    test "every base game has one channel, named after its slug" do
      names = Catalog.channel_names()

      assert length(names) == length(Catalog.base_games())
      assert names == Enum.uniq(names)
      assert "#hex-pong" in names

      for name <- names do
        assert String.length(name) <= 50
        refute String.contains?(name, " ")
      end
    end

    test "a mode shares its game's channel" do
      assert Catalog.channel_name("hex_tennis_quick") == "#hex-tennis"
      assert Catalog.base_id("hex_tennis_quick") == "hex_tennis"
      assert Catalog.base_id("hex_tennis") == "hex_tennis"
    end

    test "a channel names its base game back" do
      for %{id: id} <- Catalog.base_games() do
        assert Catalog.game_for_channel(Catalog.channel_name(id)) == {:ok, id}
      end

      assert Catalog.game_for_channel("#lobby") == :error
      assert Catalog.game_for_channel("hex-pong") == :error
    end
  end

  describe "ranking/1" do
    test "versus is the default, score and co-op are named" do
      assert Catalog.ranking("hex_pong") == :versus
      assert Catalog.ranking("hex_invaders_blitz") == :score
      assert Catalog.ranking("hex_invaders_coop") == :coop
      assert Catalog.ranking("block_breakers") == :coop
    end
  end

  test "mode_word/1 is the word a command names each mode by, and nil for a game" do
    for game <- Catalog.base_games(), mode <- Catalog.modes_of(game.id) do
      word = Catalog.mode_word(mode.id)
      assert game.id <> "_" <> word == mode.id
    end

    assert Catalog.mode_word("hex_pong") == nil
    assert Catalog.mode_word("hex_raid_blitz") == "blitz"
  end

  describe "Hex Solitaire" do
    test "draws three as a mode of the game, in the game's own room" do
      assert Catalog.base_id("hex_solitaire_draw3") == "hex_solitaire"
      assert Catalog.mode_word("hex_solitaire_draw3") == "draw3"
      assert Catalog.channel_name("hex_solitaire_draw3") == "#hex-solitaire"
      assert [%{id: "hex_solitaire_draw3"}] = Catalog.modes_of("hex_solitaire")
    end
  end
end
