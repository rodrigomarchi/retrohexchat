defmodule RetroHexChat.Arcade.Content.Controls do
  @moduledoc """
  The control tables a game's sheet lists, by engine family.

  Games on one engine share their keys: every DOOM port moves, fires and opens
  doors the same way, and so do the Quake ports and the ScummVM adventures. A
  family is a keyword list of named rows; a game takes its family's list and
  `adapt/2`s what differs — one row reworded, one dropped, a few inserted.

      Controls.adapt(Controls.doom(), fire: {dgettext("arcade", "Left Click"), dgettext("arcade", "Fire Zorcher")}, jump: nil)

  A row is `{keys, action}`; the texts are translated when the sheet is built.
  """
  use Gettext, backend: RetroHexChat.Gettext

  @type row :: {String.t(), String.t()}

  @doc """
  `base`'s rows with `changes` applied by name: a row replaces the named one,
  a list of rows takes its place (to insert rows, list the named row among
  them), and `nil` drops it.
  """
  @spec adapt(keyword(row()), keyword(row() | [row()] | nil)) :: [row()]
  def adapt(base, changes \\ []) do
    Enum.flat_map(base, fn {name, row} ->
      case Keyword.fetch(changes, name) do
        :error -> [row]
        {:ok, nil} -> []
        {:ok, rows} when is_list(rows) -> rows
        {:ok, replacement} -> [replacement]
      end
    end)
  end

  @doc "DOOM and its ports (PrBoom+): the keyboard-and-mouse layout of the shareware episode."
  @spec doom() :: keyword(row())
  def doom do
    move() ++
      [
        aim: {dgettext("arcade", "Mouse"), dgettext("arcade", "Aim / turn")},
        fire: {dgettext("arcade", "Left Click"), dgettext("arcade", "Fire weapon")},
        use: {"E", dgettext("arcade", "Use / open doors")},
        jump: {dgettext("arcade", "Space"), dgettext("arcade", "Jump (PrBoom+)")},
        weapons: {"1–7", dgettext("arcade", "Select weapon")},
        map: {"Tab", dgettext("arcade", "Toggle automap")},
        run: {dgettext("arcade", "Shift"), dgettext("arcade", "Run (hold)")},
        menu: {dgettext("arcade", "Esc"), dgettext("arcade", "Menu")}
      ]
  end

  @doc "Quake and its ports: the shareware episode's layout."
  @spec quake() :: keyword(row())
  def quake do
    move() ++
      [
        aim: {dgettext("arcade", "Mouse"), dgettext("arcade", "Aim / look")},
        fire: {dgettext("arcade", "Left Click"), dgettext("arcade", "Fire weapon")},
        use: {"E", dgettext("arcade", "Use / interact")},
        jump: {dgettext("arcade", "Space"), dgettext("arcade", "Jump")},
        weapons: {"1–8", dgettext("arcade", "Select weapon")},
        scores: {"Tab", dgettext("arcade", "Show scores")},
        menu: {dgettext("arcade", "Esc"), dgettext("arcade", "Menu")}
      ]
  end

  @doc "ScummVM's point-and-click adventures."
  @spec scummvm() :: keyword(row())
  def scummvm do
    [
      walk: {dgettext("arcade", "Left Click"), dgettext("arcade", "Walk / interact with object")},
      examine: {dgettext("arcade", "Right Click"), dgettext("arcade", "Examine object")},
      save: {"F5", dgettext("arcade", "Save / load game")},
      skip_cutscene: {dgettext("arcade", "Esc"), dgettext("arcade", "Skip cutscene")},
      pause: {dgettext("arcade", "Space"), dgettext("arcade", "Pause game")},
      skip_line: {".", dgettext("arcade", "Skip dialogue line")}
    ]
  end

  defp move do
    [
      forward: {dgettext("arcade", "W / ↑"), dgettext("arcade", "Move forward")},
      backward: {dgettext("arcade", "S / ↓"), dgettext("arcade", "Move backward")},
      strafe_left: {"A", dgettext("arcade", "Strafe left")},
      strafe_right: {"D", dgettext("arcade", "Strafe right")}
    ]
  end
end
