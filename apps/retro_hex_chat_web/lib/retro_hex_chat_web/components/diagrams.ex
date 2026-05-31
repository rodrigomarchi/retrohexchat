defmodule RetroHexChatWeb.Components.Diagrams do
  @moduledoc """
  SVG diagrams and illustrations for landing pages and informational displays.

  This module is a **facade** — every public function delegates to a
  subject-based submodule under `RetroHexChatWeb.Components.Diagrams.*`.

  ## Convention

  **One diagram per file.** Each submodule contains exactly one public
  diagram function. The shared `win98_chrome/1` helper lives in
  `Diagrams.GameScreens` and is imported by modules that need it.

  ## Submodule Index

  | Module                 | Subject                                        |
  |------------------------|------------------------------------------------|
  | `Diagrams.P2pFlow`         | P2P connection flow diagram                |
  | `Diagrams.P2pArchitecture` | P2P architecture diagram                   |
  | `Diagrams.Security`        | Encryption layers and protocol diagram     |
  | `Diagrams.Voice`           | Voice/video call mockup                    |
  | `Diagrams.GameP2pFlow`     | P2P multiplayer game flow                  |
  | `Diagrams.GameArcadeFlow`  | Solo arcade game flow                      |
  | `Diagrams.GameScreens`     | Shared `win98_chrome/1` helper only        |
  | `Diagrams.Game*`           | Win98-style game screen (1 per game)       |
  | `Diagrams.Arcade*`         | Solo Arcade game logos/cover art (1 per game) |
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  # ── P2P ───────────────────────────────────────────
  defdelegate diagram_p2p_flow(assigns), to: RetroHexChatWeb.Components.Diagrams.P2pFlow

  defdelegate diagram_p2p_architecture(assigns),
    to: RetroHexChatWeb.Components.Diagrams.P2pArchitecture

  # ── Security ──────────────────────────────────────
  defdelegate diagram_security_layers(assigns), to: RetroHexChatWeb.Components.Diagrams.Security

  # ── Voice ─────────────────────────────────────────
  defdelegate diagram_voice_call_mockup(assigns), to: RetroHexChatWeb.Components.Diagrams.Voice

  # ── Game Flows ────────────────────────────────────
  defdelegate diagram_p2p_games(assigns), to: RetroHexChatWeb.Components.Diagrams.GameP2pFlow
  defdelegate diagram_arcade_flow(assigns), to: RetroHexChatWeb.Components.Diagrams.GameArcadeFlow

  # ── Game Screens ──────────────────────────────────
  defdelegate diagram_game_pong(assigns), to: RetroHexChatWeb.Components.Diagrams.GamePong
  defdelegate diagram_game_trails(assigns), to: RetroHexChatWeb.Components.Diagrams.GameTrails
  defdelegate diagram_game_tanks(assigns), to: RetroHexChatWeb.Components.Diagrams.GameTanks
  defdelegate diagram_game_space(assigns), to: RetroHexChatWeb.Components.Diagrams.GameSpace
  defdelegate diagram_game_breakout(assigns), to: RetroHexChatWeb.Components.Diagrams.GameBreakout
  defdelegate diagram_game_warlords(assigns), to: RetroHexChatWeb.Components.Diagrams.GameWarlords
  defdelegate diagram_game_raid(assigns), to: RetroHexChatWeb.Components.Diagrams.GameRaid
  defdelegate diagram_game_boxing(assigns), to: RetroHexChatWeb.Components.Diagrams.GameBoxing
  defdelegate diagram_game_outlaw(assigns), to: RetroHexChatWeb.Components.Diagrams.GameOutlaw
  defdelegate diagram_game_hockey(assigns), to: RetroHexChatWeb.Components.Diagrams.GameHockey
  defdelegate diagram_game_tennis(assigns), to: RetroHexChatWeb.Components.Diagrams.GameTennis
  defdelegate diagram_game_enduro(assigns), to: RetroHexChatWeb.Components.Diagrams.GameEnduro
  defdelegate diagram_game_invaders(assigns), to: RetroHexChatWeb.Components.Diagrams.GameInvaders
  defdelegate diagram_game_frost(assigns), to: RetroHexChatWeb.Components.Diagrams.GameFrost
  defdelegate diagram_game_skiing(assigns), to: RetroHexChatWeb.Components.Diagrams.GameSkiing

  # ── Arcade Logos ──────────────────────────────────
  defdelegate diagram_arcade_doom(assigns), to: RetroHexChatWeb.Components.Diagrams.ArcadeDoom
  defdelegate diagram_arcade_quake(assigns), to: RetroHexChatWeb.Components.Diagrams.ArcadeQuake

  defdelegate diagram_arcade_wolfenstein(assigns),
    to: RetroHexChatWeb.Components.Diagrams.ArcadeWolfenstein

  defdelegate diagram_arcade_halflife(assigns),
    to: RetroHexChatWeb.Components.Diagrams.ArcadeHalflife

  defdelegate diagram_arcade_quake2(assigns), to: RetroHexChatWeb.Components.Diagrams.ArcadeQuake2

  defdelegate diagram_arcade_scummvm(assigns),
    to: RetroHexChatWeb.Components.Diagrams.ArcadeScummvm
end
