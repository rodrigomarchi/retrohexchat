defmodule RetroHexChatWeb.Components.UI.Games.GameStageTest do
  use RetroHexChatWeb.ConnCase, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest
  import RetroHexChatWeb.Components.UI.Games.GameStage

  @moduletag :unit

  @pad %{dirs: ["up", "down"], actions: [%{key: " ", label: "Fire"}]}

  defp stage(attrs) do
    assigns = Map.merge(%{pad: nil, on_menu: nil, menu_open: false, menu_lock: false}, attrs)

    rendered_to_string(~H"""
    <.game_stage
      id="stage"
      pad={@pad}
      pad_idle={false}
      game_id="hex_pong"
      on_menu={@on_menu}
      menu_open={@menu_open}
      menu_lock={@menu_lock}
    >
      <canvas></canvas>
      <:menu>
        <p data-testid="the-menu">Menu</p>
      </:menu>
    </.game_stage>
    """)
    |> Floki.parse_document!()
  end

  test "the game fills an arcade stage, the menu a neon dialog scoped to it" do
    doc = stage(%{})

    assert [_] = Floki.find(doc, "#stage.arcade-ui.game-stage > canvas")
    assert [_] = Floki.find(doc, ~s(#stage-menu [role="dialog"][data-skin="arcade"]))
    assert [_] = Floki.find(doc, "#stage-menu .arcade-panel")
    # Shut, it is drawn hidden; open, its trigger shows it.
    assert Floki.find(doc, "#stage-menu-show-trigger") == []
    assert [_] = Floki.find(stage(%{menu_open: true}), "#stage-menu-show-trigger")
  end

  test "the corner key is there only to open a menu that is shut" do
    assert Floki.find(stage(%{}), ~s([data-testid="game-stage-menu-key"])) == []
    assert [_] = Floki.find(stage(%{on_menu: "open"}), ~s([data-testid="game-stage-menu-key"]))

    assert Floki.find(
             stage(%{on_menu: "open", menu_open: true}),
             ~s([data-testid="game-stage-menu-key"])
           ) == []
  end

  test "the pad wears the arcade's keys, and steps aside for the menu" do
    doc = stage(%{pad: @pad})

    assert [_] = Floki.find(doc, ~s(#stage-pad[data-pad][phx-hook="RetroGamePadHook"]))
    assert length(Floki.find(doc, "#stage-pad .arcade-arrow")) == 2
    assert Floki.find(doc, "#stage-pad .space-icon") == []
    assert [_] = Floki.find(stage(%{pad: @pad, menu_open: true}), "#stage-pad[data-hidden]")
  end

  test "the full-screen key presents the stage it names" do
    assigns = %{}

    doc =
      rendered_to_string(~H"""
      <.stage_fullscreen_button stage="stage" />
      """)
      |> Floki.parse_document!()

    assert [_] = Floki.find(doc, ~s(button[phx-hook="StageFullscreenHook"][data-stage="stage"]))
  end
end
