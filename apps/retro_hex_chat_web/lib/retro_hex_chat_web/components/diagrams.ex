defmodule RetroHexChatWeb.Components.Diagrams do
  @moduledoc """
  SVG diagrams and illustrations for landing pages and informational displays.

  This module is a **facade** — every public function delegates to a
  subject-based submodule under `RetroHexChatWeb.Components.Diagrams.*`.

  ## Submodule Index

  | Module              | Subject                                    |
  |---------------------|--------------------------------------------|
  | `Diagrams.P2P`      | P2P flow and architecture diagrams         |
  | `Diagrams.Security` | Encryption layers and protocol diagrams    |
  | `Diagrams.Voice`    | Voice/video call mockups                   |
  | `Diagrams.Games`    | P2P multiplayer and solo arcade flow       |
  """
  use Phoenix.Component

  # ── P2P ───────────────────────────────────────────
  defdelegate diagram_p2p_flow(assigns), to: RetroHexChatWeb.Components.Diagrams.P2P
  defdelegate diagram_p2p_architecture(assigns), to: RetroHexChatWeb.Components.Diagrams.P2P

  # ── Security ──────────────────────────────────────
  defdelegate diagram_security_layers(assigns), to: RetroHexChatWeb.Components.Diagrams.Security

  # ── Voice ─────────────────────────────────────────
  defdelegate diagram_voice_call_mockup(assigns), to: RetroHexChatWeb.Components.Diagrams.Voice

  # ── Games ─────────────────────────────────────────
  defdelegate diagram_p2p_games(assigns), to: RetroHexChatWeb.Components.Diagrams.Games
  defdelegate diagram_arcade_flow(assigns), to: RetroHexChatWeb.Components.Diagrams.Games
end
