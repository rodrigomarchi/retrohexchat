defmodule RetroHexChatWeb.Components.UI.Games.GamePadTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.RetroGamesPanel

  alias RetroHexChat.Games.Catalog

  @moduletag :unit

  @touch ~w(hex_solitaire hex_solitaire_draw3 hex_freecell hex_spider hex_spider_2suits
            hex_spider_4suits hex_mines hex_mines_intermediate hex_mines_expert hex_sudoku
            hex_sudoku_medium hex_sudoku_hard)
  @keys [" ", "Shift", "x", "z", "c"]

  defp game(id), do: Enum.find(Catalog.list_games(), &(&1.id == id))

  describe "game_pad/1" do
    test "gives every keyboard game a cross and at most four buttons, each a real key" do
      for %{id: id} = game <- Catalog.list_games(), id not in @touch do
        pad = game_pad(game)
        assert pad, id
        assert pad.dirs != [], id
        assert Enum.all?(pad.dirs, &(&1 in ~w(up down left right))), id
        assert length(pad.actions) <= 4, id
        assert Enum.all?(pad.actions, &(&1.key in @keys and &1.label != "")), id
        assert pad.actions == Enum.uniq_by(pad.actions, & &1.key), id
      end
    end

    test "gives the games played by touch no pad" do
      for id <- @touch, do: assert(game_pad(game(id)) == nil, id)
    end

    test "shows only the arrows a game uses" do
      assert %{dirs: ["up", "down"], actions: []} = game_pad(game("hex_pong"))
      assert %{dirs: ["left", "right"]} = game_pad(game("block_breakers"))
    end

    test "names each button by its row, on the row's first key that is not an arrow" do
      assert [%{key: " ", label: "Jump"}] = game_pad(game("hex_jungle")).actions
      assert [%{key: " ", label: "Fire"}] = game_pad(game("pixel_tanks")).actions
      # Hex Raid fires and lays a mine with two keys: two buttons.
      assert [%{key: " ", label: "Fire"}, %{key: "Shift", label: "Drop a mine"}] =
               game_pad(game("hex_raid")).actions

      assert [
               %{key: "x", label: "Turn"},
               %{key: "z", label: "Turn the other way"},
               %{key: " ", label: "Drop to the bottom"},
               %{key: "c", label: "Keep a piece for later"}
             ] = game_pad(game("hex_blocks")).actions
    end
  end

  describe "the pad over the game" do
    defp panel(game) do
      render_component(&retro_games_panel/1,
        id: "retro-games-panel",
        status: "ready",
        selected_game: game,
        difficulty: "normal",
        canvas_ready: true
      )
      |> Floki.parse_document!()
    end

    test "lies over a keyboard game's canvas, its buttons named and keyed" do
      doc = panel(game("pixel_tanks"))
      assert [_] = Floki.find(doc, ~s([data-testid="retro-game-pad"][data-pad]))
      # Pixel Tanks turns with ← and →, drives with ↑, and never backs up.
      assert length(Floki.find(doc, "[data-pad-dir]")) == 3
      assert [fire] = Floki.find(doc, ~s([data-pad-action=" "]))
      assert Floki.text(fire) =~ "Fire"
    end

    test "is dimmed and takes no press before the match starts, and wakes when it runs" do
      waiting = panel(game("hex_pong"))
      assert [_] = Floki.find(waiting, ~s([data-pad][data-idle]))

      playing =
        render_component(&retro_games_panel/1,
          id: "retro-games-panel",
          status: "playing",
          selected_game: game("hex_pong"),
          difficulty: "normal",
          canvas_ready: true
        )
        |> Floki.parse_document!()

      assert [_] = Floki.find(playing, "[data-pad]")
      assert [] = Floki.find(playing, "[data-pad][data-idle]")
    end

    test "steps aside while the menu is open over the match" do
      held =
        render_component(&retro_games_panel/1,
          id: "retro-games-panel",
          status: "playing",
          selected_game: game("hex_pong"),
          difficulty: "normal",
          canvas_ready: true,
          menu_open: true
        )
        |> Floki.parse_document!()

      assert [_] = Floki.find(held, "[data-pad][data-hidden]")
      assert [] = Floki.find(panel(game("pixel_tanks")), "[data-pad]:not([data-hidden])")
    end

    test "is not there for a game played by touch" do
      assert [] = Floki.find(panel(game("hex_sudoku")), "[data-pad]")
    end
  end
end
