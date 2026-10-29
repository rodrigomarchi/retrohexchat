defmodule RetroHexChatWeb.Icons.Games do
  @moduledoc """
  Retro pixel-art SVG icons for the P2P games.
  Each icon is 32×32 and follows the project icon conventions.
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  # -- Hex Pong: paddle + ball --

  attr :class, :string, default: nil

  @spec icon_game_pong(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_pong(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <rect x="5" y="10" width="3" height="12" fill="#00ff00" />
      <rect x="24" y="10" width="3" height="12" fill="#00ff00" />
      <rect x="15" y="15" width="2" height="2" fill="#fff" />
      <path
        d="M15 3h2v2h-2z M15 7h2v2h-2z M15 11h2v2h-2z M15 15h2v2h-2z M15 19h2v2h-2z M15 23h2v2h-2z M15 27h2v2h-2z"
        fill="#006600"
      />
    </svg>
    """
  end

  # -- Light Trails: grid + trails --

  attr :class, :string, default: nil

  @spec icon_game_trails(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_trails(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <path d="M8 2h1v28H8z M23 2h1v28h-1z M2 8h28v1H2z M2 23h28v1H2z" fill="#003366" />
      <rect x="7" y="12" width="2" height="13" fill="#00ff00" />
      <rect x="7" y="11" width="13" height="2" fill="#00ff00" />
      <rect x="18" y="10" width="4" height="4" fill="#fff" />

      <rect x="23" y="7" width="2" height="13" fill="#ff0000" />
      <rect x="12" y="19" width="13" height="2" fill="#ff0000" />
      <rect x="10" y="18" width="4" height="4" fill="#fff" />
    </svg>
    """
  end

  # -- Pixel Tanks: top-down tank --

  attr :class, :string, default: nil

  @spec icon_game_tanks(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_tanks(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <rect x="10" y="13" width="12" height="10" fill="#008000" />
      <rect x="14" y="5" width="4" height="8" fill="#006600" />
      <rect x="8" y="14" width="2" height="8" fill="#555" />
      <rect x="22" y="14" width="2" height="8" fill="#555" />
      <rect x="15" y="4" width="2" height="1" fill="#ff0000" />
      <rect x="15" y="16" width="2" height="2" fill="#004400" />
    </svg>
    """
  end

  # -- Star Duel: spaceship --

  attr :class, :string, default: nil

  @spec icon_game_space(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_space(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <rect x="15" y="6" width="2" height="4" fill="#C0C0C0" />
      <rect x="14" y="10" width="4" height="4" fill="#C0C0C0" />
      <rect x="12" y="14" width="8" height="4" fill="#C0C0C0" />
      <rect x="10" y="18" width="12" height="4" fill="#C0C0C0" />
      <rect x="8" y="22" width="16" height="2" fill="#C0C0C0" />

      <rect x="15" y="12" width="2" height="4" fill="#000080" />
      <rect x="14" y="24" width="4" height="2" fill="#ff8c00" />
      <rect x="7" y="9" width="2" height="2" fill="#FFD700" />
      <rect x="24" y="21" width="2" height="2" fill="#FFD700" />
      <rect x="22" y="5" width="1" height="1" fill="#fff" />
    </svg>
    """
  end

  # -- Gravity Well: star with gravity rings --

  attr :class, :string, default: nil

  @spec icon_game_gravity(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_gravity(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <rect x="14" y="12" width="4" height="8" fill="#ff8c00" />
      <rect x="12" y="14" width="8" height="4" fill="#ff8c00" />

      <path
        d="M15 4h2v2h-2z M22 6h2v2h-2z M26 10h2v2h-2z M28 15h2v2h-2z M26 21h2v2h-2z M21 26h2v2h-2z M15 28h2v2h-2z M10 26h2v2h-2z M6 21h2v2h-2z M4 15h2v2h-2z M6 10h2v2h-2z M10 6h2v2h-2z"
        fill="#FFD700"
      />

      <rect x="7" y="8" width="3" height="3" fill="#C0C0C0" />
      <rect x="23" y="22" width="3" height="3" fill="#C0C0C0" />
    </svg>
    """
  end

  # -- Debris Field: ship among rocks --

  attr :class, :string, default: nil

  @spec icon_game_debris(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_debris(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <path d="M15 13h2v7h-2z M13 18h6v2h-6z" fill="#C0C0C0" />

      <rect x="6" y="5" width="4" height="4" fill="#555" />
      <rect x="22" y="5" width="5" height="4" fill="#666" />
      <rect x="4" y="20" width="4" height="4" fill="#444" />
      <rect x="23" y="18" width="5" height="4" fill="#555" />
      <rect x="11" y="24" width="5" height="4" fill="#666" />
    </svg>
    """
  end

  # -- Block Breakers: paddle + blocks --

  attr :class, :string, default: nil

  @spec icon_game_breakout(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_breakout(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <rect x="5" y="6" width="6" height="3" fill="#ff0000" />
      <rect x="13" y="6" width="6" height="3" fill="#FFD700" />
      <rect x="21" y="6" width="6" height="3" fill="#008000" />

      <rect x="5" y="11" width="6" height="3" fill="#000080" />
      <rect x="13" y="11" width="6" height="3" fill="#ff0000" />
      <rect x="21" y="11" width="6" height="3" fill="#FFD700" />

      <rect x="11" y="26" width="10" height="2" fill="#C0C0C0" />
      <rect x="15" y="21" width="2" height="2" fill="#fff" />
    </svg>
    """
  end

  # -- Hex Warlords: shield + fireball --

  attr :class, :string, default: nil

  @spec icon_game_warlords(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_warlords(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <rect x="4" y="8" width="3" height="16" fill="#C0C0C0" />
      <rect x="25" y="8" width="3" height="16" fill="#C0C0C0" />

      <rect x="9" y="6" width="2" height="4" fill="#ff4444" />
      <rect x="9" y="12" width="2" height="4" fill="#ff4444" />
      <rect x="9" y="18" width="2" height="4" fill="#ff4444" />

      <rect x="21" y="6" width="2" height="4" fill="#00e5ff" />
      <rect x="21" y="12" width="2" height="4" fill="#00e5ff" />
      <rect x="21" y="18" width="2" height="4" fill="#00e5ff" />

      <rect x="14" y="14" width="4" height="4" fill="#FFD700" />
      <rect x="15" y="15" width="2" height="2" fill="#ff8c00" />
    </svg>
    """
  end

  # -- Hex Raid: jet + river --

  attr :class, :string, default: nil

  @spec icon_game_raid(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_raid(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />

      <rect x="2" y="2" width="6" height="28" fill="#1a2a1a" />
      <rect x="24" y="2" width="6" height="28" fill="#1a2a1a" />
      <rect x="8" y="2" width="16" height="28" fill="#0a1a2a" />

      <path d="M15 8h2v10h-2z M12 14h8v2h-8z" fill="#39ff14" />
      <path d="M15 20h2v6h-2z M13 24h6v2h-6z" fill="#00e5ff" />
      <rect x="15" y="5" width="2" height="2" fill="#ffee00" />
      <rect x="11" y="11" width="2" height="2" fill="#ff8c00" />
      <rect x="19" y="21" width="2" height="2" fill="#ff8c00" />

      <rect x="8" y="26" width="16" height="2" fill="#555" />
    </svg>
    """
  end

  # -- Hex Boxing: top-down ring with two fists --

  attr :class, :string, default: nil

  @spec icon_game_boxing(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_boxing(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <rect x="4" y="4" width="24" height="24" fill="none" stroke="#aaa" stroke-width="2" />

      <path d="M9 13h6v6H9z" fill="#008000" />
      <rect x="15" y="15" width="4" height="2" fill="#00cc00" />
      <rect x="19" y="14" width="4" height="4" fill="#FFD700" />

      <path d="M17 13h6v6h-6z" fill="#008080" />
      <rect x="13" y="15" width="4" height="2" fill="#00cccc" />
      <rect x="9" y="14" width="4" height="4" fill="#FFD700" />
    </svg>
    """
  end

  # -- Hex Outlaw: crossed revolvers --

  attr :class, :string, default: nil

  @spec icon_game_outlaw(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_outlaw(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#1a0a1e" />

      <line x1="8" y1="24" x2="24" y2="8" stroke="#aaa" stroke-width="2" />
      <line x1="24" y1="24" x2="8" y2="8" stroke="#aaa" stroke-width="2" />
      <rect x="6" y="22" width="4" height="4" fill="#8b6914" />
      <rect x="22" y="22" width="4" height="4" fill="#8b6914" />

      <rect x="9" y="9" width="4" height="4" fill="none" stroke="#aaa" stroke-width="1" />
      <rect x="19" y="9" width="4" height="4" fill="none" stroke="#aaa" stroke-width="1" />
      <rect x="15" y="15" width="2" height="2" fill="#ff4444" />
    </svg>
    """
  end

  # -- Hex Invaders: classic Space Invader silhouette --

  attr :class, :string, default: nil

  @spec icon_game_invaders(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_invaders(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000008" />

      <path
        d="M11 7h2v2h-2z M19 7h2v2h-2z M9 9h14v2H9z M7 11h4v2H7z M15 11h2v2h-2z M21 11h4v2h-2z M7 13h18v2H7z M9 15h2v2H9z M15 15h2v2h-2z M21 15h2v2h-2z M11 17h2v2h-2z M19 17h2v2h-2z"
        fill="#39ff14"
      />
      <rect x="12" y="23" width="8" height="2" fill="#008080" />
      <rect x="15" y="21" width="2" height="2" fill="#008080" />
      <rect x="15" y="25" width="2" height="3" fill="#fff" />
    </svg>
    """
  end

  # -- Hex Enduro: pseudo-3D road + car --

  attr :class, :string, default: nil

  @spec icon_game_enduro(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_enduro(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#0a0a1a" />

      <path d="M6 16h20v14H6z" fill="#2a2a3a" />
      <path d="M10 16h12v14H10z" fill="#1a1a2a" />

      <path d="M14 5h4v2h-4z M12 7h8v2h-8z M10 9h12v2H10z M8 11h16v2H8z M6 13h20v3H6z" fill="#151525" />

      <path d="M15 17v12M17 17v12" stroke="#555566" stroke-width="1" />

      <rect x="14" y="22" width="4" height="6" fill="#39ff14" />
      <rect x="15" y="21" width="2" height="1" fill="#39ff14" />
      <rect x="13" y="26" width="1" height="2" fill="#39ff14" />
      <rect x="18" y="26" width="1" height="2" fill="#39ff14" />

      <rect x="10" y="17" width="3" height="4" fill="#ff8c00" />
      <rect x="21" y="19" width="3" height="4" fill="#ff8c00" />

      <rect x="22" y="25" width="2" height="2" fill="#ffee00" />
    </svg>
    """
  end

  # -- Hex Tennis: racket + ball --

  attr :class, :string, default: nil

  @spec icon_game_tennis(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_tennis(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#0a0a14" />

      <rect x="6" y="6" width="20" height="20" fill="#0e1a0e" />
      <rect x="6" y="15" width="20" height="2" fill="#ff006688" />
      <path d="M6 6h20v1H6z M6 25h20v1H6z M6 6h1v20H6z M25 6h1v20h-1z" fill="#39ff1480" />

      <path d="M12 19h4v6h-4z" fill="#39ff14" />
      <rect x="13" y="17" width="2" height="2" fill="#39ff14" />
      <rect x="11" y="25" width="2" height="2" fill="#39ff14" />
      <rect x="15" y="25" width="2" height="2" fill="#39ff14" />

      <rect x="20" y="9" width="3" height="3" fill="#ffee00" />
      <rect x="21" y="10" width="1" height="1" fill="#fff" />
    </svg>
    """
  end

  # -- Hex Skiing: skier descending toxic mountain --

  attr :class, :string, default: nil

  @spec icon_game_skiing(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_skiing(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#0a0a14" />

      <path d="M10 4h4v2h2v2h6v2H10z" fill="#151525" />
      <path d="M8 8h6v2h4v2H6z" fill="#151525" />

      <rect x="15" y="11" width="2" height="2" fill="#39ff14" />
      <rect x="14" y="13" width="4" height="4" fill="#39ff14" />
      <rect x="13" y="17" width="2" height="3" fill="#39ff14" />
      <rect x="17" y="17" width="2" height="3" fill="#39ff14" />
      <rect x="11" y="19" width="3" height="2" fill="#39ff14" />
      <rect x="18" y="19" width="3" height="2" fill="#39ff14" />

      <path d="M6 14h3v4H6z" fill="#1a3a1a" />
      <rect x="7" y="18" width="1" height="3" fill="#3a2a1a" />
      <path d="M23 18h3v4h-3z" fill="#1a3a1a" />
      <rect x="24" y="22" width="1" height="2" fill="#3a2a1a" />

      <rect x="4" y="25" width="4" height="2" fill="#555" />

      <rect x="20" y="8" width="2" height="2" fill="#ffee00" />

      <path d="M3 28h26v1H3z" fill="#2a2a3a" />
    </svg>
    """
  end

  # -- Hex Frost: igloo + ice blocks + character --

  attr :class, :string, default: nil

  @spec icon_game_frost(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_frost(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#060818" />

      <rect x="3" y="8" width="26" height="4" fill="#2a3040" />
      <rect x="3" y="8" width="26" height="1" fill="#4a5060" />

      <rect x="4" y="4" width="10" height="4" fill="#30cc60" />
      <rect x="6" y="3" width="6" height="1" fill="#30cc60" />
      <rect x="8" y="6" width="2" height="2" fill="#000" />

      <rect x="22" y="5" width="6" height="3" fill="#30a0cc" />
      <rect x="23" y="4" width="4" height="1" fill="#30a0cc" />

      <rect x="4" y="14" width="7" height="3" fill="#c0d8e8" />
      <rect x="15" y="14" width="7" height="3" fill="#40ff80" />
      <rect x="25" y="14" width="5" height="3" fill="#40d0ff" />

      <rect x="6" y="20" width="6" height="3" fill="#40d0ff" />
      <rect x="16" y="20" width="7" height="3" fill="#c0d8e8" />

      <rect x="3" y="25" width="7" height="3" fill="#c0d8e8" />
      <rect x="14" y="25" width="6" height="3" fill="#40ff80" />
      <rect x="24" y="25" width="6" height="3" fill="#c0d8e8" />

      <rect x="12" y="11" width="2" height="2" fill="#39ff14" />
      <rect x="11" y="13" width="4" height="3" fill="#39ff14" />
      <rect x="11" y="16" width="2" height="2" fill="#39ff14" />
      <rect x="13" y="16" width="2" height="2" fill="#39ff14" />

      <rect x="20" y="8" width="2" height="1" fill="#e0e0e0" />
      <rect x="19" y="9" width="4" height="2" fill="#e0e0e0" />

      <rect x="3" y="29" width="26" height="1" fill="#0a1020" />
    </svg>
    """
  end

  # -- Hex Hockey: stick + puck on neon rink --

  attr :class, :string, default: nil

  @spec icon_game_hockey(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_hockey(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#060812" />

      <rect x="3" y="3" width="26" height="1" fill="#39ff1440" />
      <rect x="3" y="28" width="26" height="1" fill="#39ff1440" />
      <rect x="3" y="3" width="1" height="26" fill="#39ff1440" />
      <rect x="28" y="3" width="1" height="26" fill="#39ff1440" />

      <rect x="15" y="4" width="1" height="24" fill="#39ff1420" />

      <rect x="3" y="12" width="1" height="8" fill="#ff2222" />
      <rect x="28" y="12" width="1" height="8" fill="#ff2222" />

      <rect x="8" y="12" width="2" height="2" fill="#39ff14" />
      <rect x="7" y="14" width="4" height="4" fill="#39ff14" />
      <rect x="7" y="18" width="2" height="2" fill="#39ff14" />
      <rect x="9" y="18" width="2" height="2" fill="#39ff14" />
      <rect x="11" y="14" width="4" height="1" fill="#39ff14" />

      <rect x="22" y="12" width="2" height="2" fill="#00e5ff" />
      <rect x="21" y="14" width="4" height="4" fill="#00e5ff" />
      <rect x="21" y="18" width="2" height="2" fill="#00e5ff" />
      <rect x="23" y="18" width="2" height="2" fill="#00e5ff" />
      <rect x="18" y="14" width="3" height="1" fill="#00e5ff" />

      <rect x="15" y="15" width="2" height="2" fill="#ffffff" />

      <rect x="5" y="14" width="2" height="4" fill="#20aa0a" />
      <rect x="25" y="14" width="2" height="4" fill="#0090aa" />
    </svg>
    """
  end

  # -- Hex Jungle: an explorer swinging on a vine over a tar pit --

  attr :class, :string, default: nil

  @spec icon_game_jungle(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_jungle(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#0a1a0a" />

      <rect x="2" y="2" width="28" height="6" fill="#1d5e1d" />
      <path d="M2 8h4v2H2z M10 8h4v2h-4z M18 8h4v2h-4z M26 8h4v2h-4z" fill="#2f8a2f" />
      <rect x="4" y="8" width="2" height="16" fill="#5a3a1a" />
      <rect x="26" y="8" width="2" height="16" fill="#5a3a1a" />

      <path d="M15 8h2v3h1v3h1v2h1v2" fill="none" stroke="#3a7a2a" stroke-width="1" />
      <rect x="20" y="13" width="3" height="2" fill="#e8dca0" />
      <rect x="20" y="15" width="3" height="2" fill="#e0a070" />
      <rect x="20" y="17" width="3" height="3" fill="#4a8a3a" />
      <rect x="20" y="20" width="3" height="2" fill="#b89850" />
      <rect x="19" y="22" width="1" height="1" fill="#3a2410" />
      <rect x="23" y="22" width="1" height="1" fill="#3a2410" />

      <rect x="2" y="24" width="28" height="6" fill="#8a6a2a" />
      <rect x="9" y="24" width="14" height="3" fill="#101010" />
      <rect x="6" y="22" width="3" height="2" fill="#ffd030" />
    </svg>
    """
  end

  # -- Hex Solitaire: a navy card back under an ace of hearts, on the felt --

  attr :class, :string, default: nil

  @spec icon_game_solitaire(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_solitaire(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#08786c" />

      <rect x="5" y="5" width="13" height="18" fill="#828284" />
      <rect x="6" y="6" width="11" height="16" fill="#0e2369" />
      <rect x="7" y="7" width="9" height="14" fill="#fefefe" />
      <rect x="8" y="8" width="7" height="12" fill="#0e2369" />
      <rect x="10" y="12" width="3" height="3" fill="#fefefe" />

      <rect x="13" y="10" width="15" height="19" fill="#023e3e" />
      <rect x="12" y="9" width="15" height="19" fill="#828284" />
      <rect x="13" y="10" width="13" height="17" fill="#fefefe" />
      <path d="M19 18h7v9h-7z M23 13h3v5h-3z" fill="#e4e5e4" />
      <path d="M14 11h1v1h-1z M15 12h1v2h-1z M13 12h1v2h-1z M14 13h1v1h-1z" fill="#c51316" />
      <path
        d="M16 16h2v1h-2z M20 16h2v1h-2z M15 17h8v2h-8z M16 19h6v1h-6z M17 20h4v1h-4z M18 21h2v1h-2z"
        fill="#c51316"
      />
    </svg>
    """
  end

  # -- Hex FreeCell: four free cells above two cards face up, on the felt --

  attr :class, :string, default: nil

  @spec icon_game_freecell(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_freecell(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#08786c" />

      <path
        d="M4 4h5v7H4z M5 5v5h3V5z M10 4h5v7h-5z M11 5v5h3V5z M17 4h5v7h-5z M18 5v5h3V5z M23 4h5v7h-5z M24 5v5h3V5z"
        fill="#0a8f80"
        fill-rule="evenodd"
      />

      <rect x="5" y="13" width="12" height="16" fill="#828284" />
      <rect x="6" y="14" width="10" height="14" fill="#fefefe" />
      <path
        d="M10 17h2v1h-2z M9 18h4v1h-4z M8 19h6v2h-6z M10 21h2v2h-2z M9 23h4v1h-4z"
        fill="#090101"
      />

      <rect x="16" y="12" width="13" height="17" fill="#023e3e" />
      <rect x="15" y="11" width="13" height="17" fill="#828284" />
      <rect x="16" y="12" width="11" height="15" fill="#fefefe" />
      <path
        d="M17 16h2v1h-2z M21 16h2v1h-2z M16 17h8v2h-8z M17 19h6v1h-6z M18 20h4v1h-4z M19 21h2v1h-2z"
        fill="#c51316"
      />
    </svg>
    """
  end

  # -- Hex Spider: a pixel spider on its thread over a fan of spades, on the felt --

  attr :class, :string, default: nil

  @spec icon_game_spider(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_spider(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#08786c" />

      <rect x="4" y="14" width="10" height="14" fill="#828284" />
      <rect x="5" y="15" width="8" height="12" fill="#fefefe" />
      <rect x="10" y="15" width="10" height="14" fill="#828284" />
      <rect x="11" y="16" width="8" height="12" fill="#fefefe" />
      <rect x="16" y="16" width="10" height="13" fill="#828284" />
      <rect x="17" y="17" width="8" height="11" fill="#fefefe" />
      <path
        d="M21 19h1v1h-1z M20 20h3v1h-3z M19 21h5v2h-5z M21 23h1v2h-1z M20 25h3v1h-3z"
        fill="#090101"
      />

      <rect x="15" y="2" width="1" height="7" fill="#e4e5e4" />
      <path
        d="M14 9h3v4h-3z M12 9h2v1h-2z M17 9h2v1h-2z M11 10h1v1h-1z M19 10h1v1h-1z M12 12h2v1h-2z M17 12h2v1h-2z M11 13h1v1h-1z M19 13h1v1h-1z"
        fill="#090101"
      />
      <path d="M14 10h1v1h-1z M16 10h1v1h-1z" fill="#c51316" />
    </svg>
    """
  end

  # -- Hex Mines: a mine beside a red flag on the raised squares of a field --

  attr :class, :string, default: nil

  @spec icon_game_mines(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_mines(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#bdbfc5" />
      <path d="M2 16h28v1H2z M16 2h1v28h-1z" fill="#96989f" />

      <rect x="17" y="17" width="13" height="13" fill="#ccced4" />
      <path d="M17 17h13v1H18v12h-1z" fill="#fefefe" />
      <path d="M29 18h1v12H18v-1h11z" fill="#80828a" />
      <path
        d="M22 19h3v1h-3z M20 20h5v1h-5z M19 21h6v1h-6z M20 22h5v1h-5z M22 23h3v1h-3z"
        fill="#cd1c1e"
      />
      <path d="M24 19h1v8h-1z M21 27h7v1h-7z" fill="#101014" />

      <path
        d="M8 4h1v2H8z M5 7h7v1H5z M4 8h9v4H4z M5 12h7v1H5z M8 13h1v2H8z M2 9h2v2H2z M13 9h2v2h-2z M5 5h1v1H5z M11 5h1v1h-1z M5 14h1v1H5z M11 14h1v1h-1z"
        fill="#101014"
      />
      <path d="M6 8h2v2H6z" fill="#fefefe" />

      <path d="M21 4h3v1h-3z M20 5h1v6h-1z M24 5h1v6h-1z M21 11h3v1h-3z" fill="#1c48d6" />
      <path d="M5 21h5v1H5z M9 22h1v2H9z M6 24h3v1H6z M5 25h1v2H5z M5 27h5v1H5z" fill="#0e802c" />
    </svg>
    """
  end

  # -- Hex Sudoku: a grid of three boxes a side, a square chosen, digits in their inks --

  attr :class, :string, default: nil

  @spec icon_game_sudoku(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_sudoku(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#023e3e" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#fafaf6" />
      <rect x="12" y="12" width="8" height="8" fill="#ffe26e" />
      <path d="M2 12h10v8H2z M20 12h10v8H20z M12 2h8v10h-8z M12 20h8v10h-8z" fill="#dee8f8" />
      <path d="M11 2h1v28h-1z M20 2h1v28h-1z M2 11h28v1H2z M2 20h28v1H2z" fill="#24262e" />
      <path
        d="M4 4h3v1h-3z M4 5h1v1h-1z M4 6h2v1h-2z M6 7h1v1h-1z M4 8h2v1h-2z M24 4h2v1h-2z M26 5h1v1h-1z M25 6h1v1h-1z M26 7h1v1h-1z M24 8h2v1h-2z M5 23h3v1h-3z M5 24h1v1h-1z M7 24h1v1h-1z M5 25h3v1h-3z M7 26h1v1h-1z M5 27h2v1h-2z M25 23h1v1h-1z M24 24h2v1h-2z M25 25h1v1h-1z M25 26h1v1h-1z M24 27h3v1h-3z"
        fill="#101014"
      />
      <path
        d="M14 14h3v1h-3z M16 15h1v1h-1z M15 16h1v1h-1z M15 17h1v1h-1z M15 18h1v1h-1z"
        fill="#1c48d6"
      />
      <path
        d="M24 14h1v1h-1z M26 14h1v1h-1z M24 15h1v1h-1z M26 15h1v1h-1z M24 16h3v1h-3z M26 17h1v1h-1z M26 18h1v1h-1z"
        fill="#cd1c1e"
      />
    </svg>
    """
  end

  # -- Hex Blocks: a honeycomb well, a stack of gems and a piece falling into it --

  attr :class, :string, default: nil

  @spec icon_game_blocks(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_blocks(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#3c4260" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#0e101c" />
      <path
        d="M5 21h4v1h-4z M4 22h6v1h-6z M3 23h8v1h-8z M3 24h8v1h-8z M4 25h6v1h-6z M5 26h4v1h-4z M17 21h4v1h-4z M16 22h6v1h-6z M15 23h8v1h-8z M15 24h8v1h-8z M16 25h6v1h-6z M17 26h4v1h-4z"
        fill="#e03050"
      />
      <path
        d="M11 24h4v1h-4z M10 25h6v1h-6z M9 26h8v1h-8z M9 27h8v1h-8z M10 28h6v1h-6z M11 29h4v1h-4z M23 24h4v1h-4z M22 25h6v1h-6z M21 26h8v1h-8z M21 27h8v1h-8z M22 28h6v1h-6z M23 29h4v1h-4z"
        fill="#f5c81c"
      />
      <path
        d="M11 18h4v1h-4z M10 19h6v1h-6z M9 20h8v1h-8z M9 21h8v1h-8z M10 22h6v1h-6z M11 23h4v1h-4z M23 18h4v1h-4z M22 19h6v1h-6z M21 20h8v1h-8z M21 21h8v1h-8z M22 22h6v1h-6z M23 23h4v1h-4z"
        fill="#28b4f0"
      />
      <path
        d="M5 15h4v1h-4z M4 16h6v1h-6z M3 17h8v1h-8z M3 18h8v1h-8z M4 19h6v1h-6z M5 20h4v1h-4z"
        fill="#22d070"
      />
      <path
        d="M17 9h4v1h-4z M16 10h6v1h-6z M15 11h8v1h-8z M15 12h8v1h-8z M16 13h6v1h-6z M17 14h4v1h-4z M17 3h4v1h-4z M16 4h6v1h-6z M15 5h8v1h-8z M15 6h8v1h-8z M16 7h6v1h-6z M17 8h4v1h-4z M23 6h4v1h-4z M22 7h6v1h-6z M21 8h8v1h-8z M21 9h8v1h-8z M22 10h6v1h-6z M23 11h4v1h-4z"
        fill="#a04cf0"
      />
      <path
        d="M5 22h2v1h-2z M17 22h2v1h-2z M11 25h2v1h-2z M23 25h2v1h-2z M11 19h2v1h-2z M23 19h2v1h-2z M5 16h2v1h-2z M17 10h2v1h-2z M17 4h2v1h-2z M23 7h2v1h-2z"
        fill="#ffffff"
        fill-opacity="0.7"
      />
    </svg>
    """
  end

  # -- DOOM Shareware: shotgun with muzzle flash (red/orange) --

  attr :class, :string, default: nil

  @spec icon_game_doom(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_doom(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#1a0000" />

      <rect x="4" y="14" width="18" height="4" fill="#666" />
      <rect x="4" y="14" width="18" height="1" fill="#888" />
      <rect x="4" y="17" width="18" height="1" fill="#444" />
      <rect x="6" y="18" width="6" height="6" fill="#553300" />
      <rect x="6" y="18" width="6" height="1" fill="#774400" />
      <rect x="4" y="13" width="2" height="1" fill="#888" />

      <rect x="22" y="11" width="4" height="2" fill="#ff4400" />
      <rect x="23" y="9" width="2" height="2" fill="#ff8800" />
      <rect x="24" y="7" width="2" height="2" fill="#ffcc00" />
      <rect x="22" y="13" width="2" height="1" fill="#ff4400" />
      <rect x="25" y="12" width="2" height="2" fill="#ff6600" />
      <rect x="24" y="8" width="1" height="1" fill="#fff" />

      <rect x="15" y="15" width="1" height="2" fill="#444" />
      <rect x="18" y="15" width="1" height="2" fill="#444" />

      <rect x="5" y="5" width="8" height="3" fill="#cc0000" />
      <rect x="5" y="5" width="8" height="1" fill="#ff0000" />
      <path d="M6 6h1v1h1v1H6z" fill="#ff0000" />
      <rect x="10" y="6" width="2" height="1" fill="#ff0000" />

      <rect x="17" y="24" width="8" height="3" fill="#cc0000" />
      <rect x="17" y="24" width="8" height="1" fill="#ff0000" />
    </svg>
    """
  end

  # -- Freedoom Phase 1: liberty cap + fist (blue/teal) --

  attr :class, :string, default: nil

  @spec icon_game_freedoom1(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_freedoom1(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#001122" />

      <rect x="14" y="4" width="4" height="2" fill="#0088cc" />
      <rect x="12" y="6" width="8" height="2" fill="#0088cc" />
      <rect x="10" y="8" width="12" height="4" fill="#0077bb" />
      <rect x="8" y="12" width="16" height="2" fill="#006699" />
      <rect x="15" y="3" width="2" height="1" fill="#00aaff" />

      <rect x="12" y="10" width="3" height="2" fill="#00bbff" />
      <rect x="17" y="10" width="3" height="2" fill="#00bbff" />
      <rect x="13" y="10" width="1" height="1" fill="#fff" />
      <rect x="18" y="10" width="1" height="1" fill="#fff" />

      <rect x="14" y="16" width="4" height="4" fill="#ddaa77" />
      <rect x="13" y="17" width="1" height="2" fill="#ddaa77" />
      <rect x="18" y="17" width="1" height="2" fill="#ddaa77" />
      <rect x="12" y="20" width="3" height="4" fill="#ddaa77" />
      <rect x="17" y="20" width="3" height="4" fill="#ddaa77" />
      <rect x="11" y="22" width="2" height="2" fill="#ddaa77" />
      <rect x="19" y="22" width="2" height="2" fill="#ddaa77" />
      <rect x="14" y="20" width="4" height="2" fill="#cc9966" />

      <rect x="15" y="16" width="2" height="1" fill="#eebbaa" />

      <rect x="5" y="26" width="4" height="2" fill="#0077bb" />
      <rect x="5" y="26" width="4" height="1" fill="#0088cc" />
      <rect x="23" y="26" width="4" height="2" fill="#0077bb" />
      <rect x="23" y="26" width="4" height="1" fill="#0088cc" />
    </svg>
    """
  end

  # -- Freedoom Phase 2: double-barrel shotgun (green/olive) --

  attr :class, :string, default: nil

  @spec icon_game_freedoom2(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_freedoom2(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#0a1a00" />

      <rect x="4" y="12" width="20" height="2" fill="#777" />
      <rect x="4" y="14" width="20" height="2" fill="#666" />
      <rect x="4" y="12" width="20" height="1" fill="#999" />
      <rect x="4" y="15" width="20" height="1" fill="#444" />
      <rect x="4" y="11" width="2" height="1" fill="#999" />
      <rect x="4" y="16" width="2" height="1" fill="#444" />

      <rect x="24" y="10" width="3" height="2" fill="#ff6600" />
      <rect x="24" y="16" width="3" height="2" fill="#ff6600" />
      <rect x="25" y="9" width="2" height="1" fill="#ffaa00" />
      <rect x="25" y="18" width="2" height="1" fill="#ffaa00" />
      <rect x="26" y="8" width="2" height="2" fill="#ffcc00" />
      <rect x="26" y="18" width="2" height="2" fill="#ffcc00" />
      <rect x="27" y="9" width="1" height="1" fill="#fff" />
      <rect x="27" y="18" width="1" height="1" fill="#fff" />

      <rect x="6" y="16" width="8" height="7" fill="#553300" />
      <rect x="6" y="16" width="8" height="1" fill="#774400" />

      <rect x="10" y="13" width="1" height="2" fill="#444" />
      <rect x="16" y="13" width="1" height="2" fill="#444" />

      <rect x="5" y="4" width="6" height="3" fill="#338833" />
      <rect x="5" y="4" width="6" height="1" fill="#44aa44" />
      <rect x="7" y="5" width="2" height="2" fill="#44aa44" />
      <rect x="15" y="5" width="4" height="2" fill="#338833" />

      <rect x="21" y="24" width="6" height="3" fill="#338833" />
      <rect x="21" y="24" width="6" height="1" fill="#44aa44" />
    </svg>
    """
  end

  # -- Quake: dark nail with runic symbol (brown/amber) --

  attr :class, :string, default: nil

  @spec icon_game_quake(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_quake(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#0d0d00" />

      <path
        d="M12 4h8v2h2v2h2v4h2v8h-2v4h-2v2h-2v2h-8v-2h-2v-2H8v-4H6v-8h2V8h2V6h2z"
        fill="#3a2500"
      />
      <path
        d="M14 6h4v2h2v2h2v4h2v4h-2v4h-2v2h-2v2h-4v-2h-2v-2h-2v-4H8v-4h2V8h2V6z"
        fill="#4a3000"
      />

      <rect x="15" y="7" width="2" height="4" fill="#ffcc00" />
      <rect x="13" y="11" width="6" height="2" fill="#ffcc00" />
      <rect x="14" y="13" width="2" height="2" fill="#ffcc00" />
      <rect x="16" y="13" width="2" height="2" fill="#ffcc00" />
      <rect x="13" y="15" width="2" height="4" fill="#ffcc00" />
      <rect x="17" y="15" width="2" height="4" fill="#ffcc00" />
      <rect x="12" y="19" width="2" height="2" fill="#ffcc00" />
      <rect x="18" y="19" width="2" height="2" fill="#ffcc00" />
      <rect x="14" y="21" width="4" height="2" fill="#ffcc00" />

      <rect x="15" y="8" width="1" height="1" fill="#fff" />
      <rect x="14" y="11" width="1" height="1" fill="#fff" />
      <rect x="18" y="11" width="1" height="1" fill="#fff" />
      <rect x="15" y="21" width="1" height="1" fill="#fff" />

      <rect x="6" y="14" width="1" height="1" fill="#ff6600" />
      <rect x="8" y="8" width="1" height="1" fill="#ff6600" />
      <rect x="25" y="18" width="1" height="1" fill="#ff6600" />
      <rect x="23" y="10" width="1" height="1" fill="#ff6600" />
      <rect x="5" y="22" width="1" height="1" fill="#ff6600" />
      <rect x="26" y="6" width="1" height="1" fill="#ff6600" />
    </svg>
    """
  end

  # -- Quake II: strogg emblem (orange/red industrial) --

  attr :class, :string, default: nil

  @spec icon_game_quake2(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_quake2(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#1a0800" />

      <path
        d="M12 4h8v2h2v2h2v4h2v8h-2v4h-2v2h-2v2h-8v-2h-2v-2H8v-4H6v-8h2V8h2V6h2z"
        fill="#4a1500"
      />
      <path
        d="M14 6h4v2h2v2h2v4h2v4h-2v4h-2v2h-2v2h-4v-2h-2v-2h-2v-4H8v-4h2V8h2V6z"
        fill="#6a2000"
      />

      <rect x="14" y="7" width="4" height="2" fill="#ff6600" />
      <rect x="13" y="9" width="2" height="2" fill="#ff6600" />
      <rect x="17" y="9" width="2" height="2" fill="#ff6600" />
      <rect x="15" y="11" width="2" height="6" fill="#ff6600" />
      <rect x="13" y="13" width="2" height="2" fill="#ff6600" />
      <rect x="17" y="13" width="2" height="2" fill="#ff6600" />
      <rect x="12" y="17" width="2" height="2" fill="#ff6600" />
      <rect x="18" y="17" width="2" height="2" fill="#ff6600" />
      <rect x="13" y="19" width="6" height="2" fill="#ff6600" />
      <rect x="15" y="21" width="2" height="2" fill="#ff6600" />

      <rect x="15" y="7" width="1" height="1" fill="#ffcc00" />
      <rect x="13" y="9" width="1" height="1" fill="#ffcc00" />
      <rect x="18" y="9" width="1" height="1" fill="#ffcc00" />
      <rect x="15" y="12" width="1" height="1" fill="#ffcc00" />

      <rect x="5" y="5" width="1" height="1" fill="#cc3300" />
      <rect x="26" y="7" width="1" height="1" fill="#cc3300" />
      <rect x="7" y="24" width="1" height="1" fill="#cc3300" />
      <rect x="24" y="22" width="1" height="1" fill="#cc3300" />
      <rect x="4" y="15" width="1" height="1" fill="#cc3300" />
      <rect x="27" y="16" width="1" height="1" fill="#cc3300" />
    </svg>
    """
  end

  # -- Arcade: retro arcade cabinet --

  attr :class, :string, default: nil

  @spec icon_game_arcade(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_arcade(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <rect x="8" y="4" width="16" height="22" fill="#444" />
      <rect x="8" y="4" width="16" height="1" fill="#666" />
      <rect x="8" y="4" width="1" height="22" fill="#666" />
      <rect x="23" y="4" width="1" height="22" fill="#222" />
      <rect x="8" y="25" width="16" height="1" fill="#222" />

      <rect x="10" y="6" width="12" height="8" fill="#001a00" />
      <rect x="11" y="7" width="10" height="6" fill="#003300" />

      <rect x="13" y="8" width="2" height="2" fill="#00ff00" />
      <rect x="17" y="9" width="3" height="3" fill="#00ff00" />
      <rect x="14" y="11" width="1" height="1" fill="#00ff00" />

      <rect x="12" y="16" width="2" height="2" fill="#222" />
      <rect x="13" y="15" width="1" height="1" fill="#222" />
      <rect x="13" y="18" width="1" height="1" fill="#222" />
      <rect x="11" y="17" width="1" height="1" fill="#222" />
      <rect x="14" y="17" width="1" height="1" fill="#222" />
      <rect x="13" y="17" width="1" height="1" fill="#ff0000" />

      <rect x="18" y="16" width="2" height="2" fill="#ff0000" />
      <rect x="21" y="16" width="2" height="2" fill="#0000ff" />
      <rect x="19" y="19" width="2" height="2" fill="#ffff00" />

      <rect x="10" y="22" width="4" height="1" fill="#ff6600" />
      <rect x="18" y="22" width="4" height="1" fill="#ff6600" />

      <rect x="10" y="26" width="4" height="4" fill="#333" />
      <rect x="18" y="26" width="4" height="4" fill="#333" />
    </svg>
    """
  end

  # -- FreeDM: arena deathmatch flags (red/orange) --

  attr :class, :string, default: nil

  @spec icon_game_freedm(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_freedm(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#1a0800" />

      <rect x="10" y="4" width="12" height="10" fill="#2a1a0a" />
      <rect x="10" y="4" width="12" height="1" fill="#3a2a1a" />

      <rect x="8" y="6" width="2" height="18" fill="#666" />
      <rect x="6" y="6" width="4" height="6" fill="#cc3300" />
      <rect x="6" y="6" width="4" height="1" fill="#ff4400" />
      <rect x="7" y="8" width="2" height="2" fill="#ff6600" />

      <rect x="22" y="6" width="2" height="18" fill="#666" />
      <rect x="22" y="6" width="4" height="6" fill="#0066cc" />
      <rect x="22" y="6" width="4" height="1" fill="#0088ff" />
      <rect x="23" y="8" width="2" height="2" fill="#0099ff" />

      <rect x="12" y="16" width="8" height="8" fill="#333" />
      <rect x="12" y="16" width="8" height="1" fill="#555" />
      <rect x="14" y="18" width="4" height="4" fill="#ff6600" />
      <rect x="15" y="19" width="2" height="2" fill="#ffcc00" />

      <rect x="4" y="26" width="8" height="2" fill="#553300" />
      <rect x="20" y="26" width="8" height="2" fill="#553300" />
    </svg>
    """
  end

  # -- Chex Quest: cereal zapper (yellow/green) --

  attr :class, :string, default: nil

  @spec icon_game_chex(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_chex(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#0a1a00" />

      <rect x="10" y="8" width="12" height="16" fill="#ccaa00" />
      <rect x="10" y="8" width="12" height="2" fill="#ddbb00" />
      <rect x="10" y="22" width="12" height="2" fill="#aa8800" />
      <rect x="12" y="10" width="8" height="12" fill="#ddcc22" />

      <rect x="14" y="12" width="4" height="4" fill="#ffee44" />
      <rect x="15" y="13" width="2" height="2" fill="#fff" />

      <rect x="14" y="18" width="4" height="2" fill="#aa8800" />
      <rect x="13" y="17" width="6" height="1" fill="#ccaa00" />

      <rect x="4" y="12" width="6" height="4" fill="#33aa33" />
      <rect x="4" y="12" width="6" height="1" fill="#44cc44" />
      <rect x="5" y="14" width="4" height="1" fill="#22aa22" />

      <rect x="24" y="4" width="4" height="4" fill="#00ff00" />
      <rect x="25" y="3" width="2" height="1" fill="#00ff00" />
      <rect x="25" y="5" width="2" height="2" fill="#88ff88" />

      <rect x="5" y="25" width="6" height="2" fill="#33aa33" />
      <rect x="21" y="25" width="6" height="2" fill="#33aa33" />
    </svg>
    """
  end

  # -- HacX: cyberpunk terminal (cyan/purple) --

  attr :class, :string, default: nil

  @spec icon_game_hacx(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_hacx(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#0a001a" />

      <rect x="6" y="4" width="20" height="14" fill="#1a0a2a" />
      <rect x="6" y="4" width="20" height="1" fill="#3a1a4a" />
      <rect x="6" y="4" width="1" height="14" fill="#3a1a4a" />
      <rect x="25" y="4" width="1" height="14" fill="#1a0a1a" />
      <rect x="6" y="17" width="20" height="1" fill="#1a0a1a" />

      <rect x="8" y="6" width="16" height="10" fill="#000" />
      <rect x="9" y="7" width="2" height="1" fill="#00ffcc" />
      <rect x="12" y="7" width="6" height="1" fill="#00ffcc" />
      <rect x="9" y="9" width="8" height="1" fill="#00cc99" />
      <rect x="9" y="11" width="10" height="1" fill="#00ffcc" />
      <rect x="9" y="13" width="4" height="1" fill="#00cc99" />
      <rect x="14" y="13" width="2" height="2" fill="#ff00ff" />

      <rect x="21" y="7" width="2" height="2" fill="#ff00ff" />
      <rect x="21" y="10" width="2" height="2" fill="#cc00cc" />

      <rect x="10" y="20" width="12" height="4" fill="#333" />
      <rect x="10" y="20" width="12" height="1" fill="#555" />
      <rect x="11" y="21" width="2" height="2" fill="#00ffcc" />
      <rect x="14" y="21" width="2" height="2" fill="#00ffcc" />
      <rect x="17" y="21" width="2" height="2" fill="#00ffcc" />
      <rect x="20" y="21" width="1" height="1" fill="#ff00ff" />

      <rect x="4" y="26" width="6" height="2" fill="#3a1a4a" />
      <rect x="22" y="26" width="6" height="2" fill="#3a1a4a" />
    </svg>
    """
  end

  # -- REKKR: Viking axe + rune (gold/brown) --

  attr :class, :string, default: nil

  @spec icon_game_rekkr(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_rekkr(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#1a1000" />

      <rect x="15" y="4" width="2" height="20" fill="#774400" />
      <rect x="15" y="4" width="1" height="20" fill="#885500" />

      <rect x="10" y="6" width="5" height="6" fill="#999" />
      <rect x="17" y="6" width="5" height="6" fill="#999" />
      <rect x="10" y="6" width="12" height="1" fill="#bbb" />
      <rect x="9" y="7" width="1" height="4" fill="#aaa" />
      <rect x="22" y="7" width="1" height="4" fill="#aaa" />
      <rect x="8" y="8" width="1" height="2" fill="#999" />
      <rect x="23" y="8" width="1" height="2" fill="#999" />

      <rect x="12" y="8" width="2" height="2" fill="#bbb" />
      <rect x="18" y="8" width="2" height="2" fill="#bbb" />

      <rect x="13" y="24" width="6" height="4" fill="#553300" />
      <rect x="13" y="24" width="6" height="1" fill="#774400" />
      <rect x="14" y="25" width="4" height="2" fill="#664400" />

      <rect x="4" y="14" width="4" height="4" fill="#ffcc00" />
      <rect x="5" y="15" width="2" height="2" fill="#ffee44" />
      <rect x="24" y="14" width="4" height="4" fill="#ffcc00" />
      <rect x="25" y="15" width="2" height="2" fill="#ffee44" />

      <rect x="5" y="20" width="2" height="2" fill="#ffcc00" />
      <rect x="25" y="20" width="2" height="2" fill="#ffcc00" />
    </svg>
    """
  end

  # -- LibreQuake: open portal (blue/white) --

  attr :class, :string, default: nil

  @spec icon_game_librequake(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_librequake(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000022" />

      <path
        d="M12 4h8v2h2v2h2v4h2v8h-2v4h-2v2h-2v2h-8v-2h-2v-2H8v-4H6v-8h2V8h2V6h2z"
        fill="#003366"
      />
      <path
        d="M14 6h4v2h2v2h2v4h2v4h-2v4h-2v2h-2v2h-4v-2h-2v-2h-2v-4H8v-4h2V8h2V6z"
        fill="#004488"
      />
      <path d="M14 8h4v2h2v2h2v4h-2v4h-2v2h-2v2h-4v-2h-2v-2h-2v-4h2v-4h2V8z" fill="#0066aa" />

      <rect x="14" y="10" width="4" height="2" fill="#88ccff" />
      <rect x="12" y="12" width="8" height="2" fill="#88ccff" />
      <rect x="12" y="14" width="8" height="4" fill="#aaddff" />
      <rect x="12" y="18" width="8" height="2" fill="#88ccff" />
      <rect x="14" y="20" width="4" height="2" fill="#88ccff" />

      <rect x="15" y="13" width="2" height="2" fill="#fff" />
      <rect x="14" y="15" width="4" height="2" fill="#fff" />
      <rect x="15" y="17" width="2" height="1" fill="#fff" />

      <rect x="5" y="5" width="2" height="2" fill="#0088ff" />
      <rect x="25" y="5" width="2" height="2" fill="#0088ff" />
      <rect x="5" y="25" width="2" height="2" fill="#0088ff" />
      <rect x="25" y="25" width="2" height="2" fill="#0088ff" />
    </svg>
    """
  end

  # -- Wolfenstein 3D: stone castle wall + BJ helmet --

  attr :class, :string, default: nil

  @spec icon_game_wolfenstein(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_wolfenstein(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#1a1a2e" />

      <rect x="4" y="4" width="24" height="4" fill="#666" />
      <rect x="4" y="4" width="24" height="1" fill="#888" />
      <rect x="4" y="7" width="24" height="1" fill="#444" />
      <rect x="4" y="8" width="4" height="12" fill="#555" />
      <rect x="24" y="8" width="4" height="12" fill="#555" />
      <rect x="4" y="20" width="24" height="4" fill="#666" />
      <rect x="4" y="20" width="24" height="1" fill="#888" />
      <rect x="4" y="23" width="24" height="1" fill="#444" />

      <rect x="8" y="8" width="16" height="12" fill="#222" />

      <rect x="11" y="9" width="10" height="4" fill="#556b2f" />
      <rect x="11" y="9" width="10" height="1" fill="#6b8e23" />
      <rect x="12" y="13" width="8" height="3" fill="#deb887" />
      <rect x="13" y="12" width="2" height="1" fill="#fff" />
      <rect x="14" y="12" width="1" height="1" fill="#336" />
      <rect x="17" y="12" width="2" height="1" fill="#fff" />
      <rect x="18" y="12" width="1" height="1" fill="#336" />
      <rect x="15" y="15" width="2" height="1" fill="#a0522d" />

      <rect x="10" y="24" width="12" height="3" fill="#556b2f" />
      <rect x="10" y="24" width="12" height="1" fill="#6b8e23" />
      <rect x="15" y="25" width="2" height="2" fill="#222" />
      <rect x="15" y="25" width="2" height="1" fill="#444" />
    </svg>
    """
  end

  # -- Half-Life: lambda symbol (orange on dark) --

  attr :class, :string, default: nil

  @spec icon_game_halflife(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_halflife(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#1a1a1a" />

      <circle cx="16" cy="16" r="11" fill="#2a2a2a" />
      <circle cx="16" cy="16" r="10" fill="#222" />

      <rect x="10" y="7" width="3" height="18" fill="#ff8c00" />
      <rect x="10" y="7" width="3" height="1" fill="#ffa500" />
      <rect x="13" y="14" width="2" height="3" fill="#ff8c00" />
      <rect x="15" y="16" width="2" height="3" fill="#ff8c00" />
      <rect x="17" y="18" width="2" height="3" fill="#ff8c00" />
      <rect x="19" y="20" width="3" height="5" fill="#ff8c00" />
      <rect x="19" y="24" width="3" height="1" fill="#cc7000" />

      <rect x="15" y="7" width="3" height="4" fill="#ff8c00" />
      <rect x="15" y="7" width="3" height="1" fill="#ffa500" />
      <rect x="18" y="9" width="2" height="3" fill="#ff8c00" />
      <rect x="20" y="10" width="2" height="3" fill="#ff8c00" />
    </svg>
    """
  end

  # -- Beneath a Steel Sky: cyberpunk city skyline with robot companion --

  attr :class, :string, default: nil

  @spec icon_game_bass(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_bass(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#0a0a1a" />

      <rect x="4" y="14" width="4" height="14" fill="#1a2a3a" />
      <rect x="5" y="15" width="1" height="1" fill="#4af" />
      <rect x="5" y="17" width="1" height="1" fill="#4af" />
      <rect x="6" y="16" width="1" height="1" fill="#4af" />

      <rect x="10" y="10" width="5" height="18" fill="#1e2e3e" />
      <rect x="11" y="11" width="1" height="1" fill="#4af" />
      <rect x="13" y="11" width="1" height="1" fill="#4af" />
      <rect x="11" y="13" width="1" height="1" fill="#4af" />
      <rect x="13" y="14" width="1" height="1" fill="#4af" />
      <rect x="12" y="16" width="1" height="1" fill="#ff4" />

      <rect x="17" y="8" width="4" height="20" fill="#223344" />
      <rect x="18" y="9" width="1" height="1" fill="#4af" />
      <rect x="18" y="11" width="1" height="1" fill="#4af" />
      <rect x="19" y="10" width="1" height="1" fill="#ff4" />
      <rect x="18" y="13" width="1" height="1" fill="#4af" />

      <rect x="23" y="12" width="5" height="16" fill="#1a2a3a" />
      <rect x="24" y="13" width="1" height="1" fill="#4af" />
      <rect x="26" y="14" width="1" height="1" fill="#ff4" />
      <rect x="24" y="16" width="1" height="1" fill="#4af" />

      <rect x="4" y="4" width="2" height="2" fill="#334" />
      <rect x="4" y="4" width="1" height="1" fill="#f80" />
      <rect x="8" y="5" width="1" height="1" fill="#556" />
      <rect x="22" y="4" width="1" height="1" fill="#556" />
      <rect x="26" y="6" width="1" height="1" fill="#f80" />
    </svg>
    """
  end

  # -- Drascula: The Vampire Strikes Back: castle + moon --

  attr :class, :string, default: nil

  @spec icon_game_drascula(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_drascula(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#1a0a1a" />

      <rect x="22" y="4" width="4" height="4" fill="#ff4" />
      <rect x="23" y="5" width="2" height="2" fill="#ffa" />

      <rect x="6" y="12" width="3" height="16" fill="#2a1a2a" />
      <rect x="6" y="10" width="3" height="2" fill="#3a2a3a" />
      <rect x="7" y="9" width="1" height="1" fill="#3a2a3a" />
      <rect x="7" y="14" width="1" height="1" fill="#f82" />
      <rect x="7" y="17" width="1" height="1" fill="#f82" />

      <rect x="11" y="8" width="5" height="20" fill="#2a1a2a" />
      <rect x="11" y="6" width="5" height="2" fill="#3a2a3a" />
      <rect x="12" y="5" width="3" height="1" fill="#3a2a3a" />
      <rect x="12" y="10" width="1" height="2" fill="#f82" />
      <rect x="14" y="10" width="1" height="2" fill="#f82" />
      <rect x="13" y="14" width="1" height="1" fill="#f82" />

      <rect x="18" y="14" width="4" height="14" fill="#2a1a2a" />
      <rect x="18" y="12" width="4" height="2" fill="#3a2a3a" />
      <rect x="19" y="11" width="2" height="1" fill="#3a2a3a" />
      <rect x="19" y="16" width="1" height="1" fill="#f82" />
      <rect x="20" y="18" width="1" height="1" fill="#f82" />

      <rect x="24" y="16" width="3" height="12" fill="#2a1a2a" />
      <rect x="24" y="14" width="3" height="2" fill="#3a2a3a" />
      <rect x="25" y="18" width="1" height="1" fill="#f82" />

      <rect x="5" y="6" width="1" height="1" fill="#445" />
      <rect x="17" y="4" width="1" height="1" fill="#445" />
      <rect x="27" y="8" width="1" height="1" fill="#445" />

      <rect x="9" y="26" width="2" height="2" fill="#a22" />
      <rect x="10" y="25" width="1" height="1" fill="#a22" />
    </svg>
    """
  end

  # -- Dreamweb: dark cyberpunk top-down --

  attr :class, :string, default: nil

  @spec icon_game_dreamweb(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_dreamweb(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#0a0a12" />

      <rect x="4" y="4" width="6" height="8" fill="#1a1a2a" />
      <rect x="4" y="4" width="6" height="1" fill="#2a2a3a" />
      <rect x="5" y="6" width="1" height="1" fill="#446" />
      <rect x="8" y="6" width="1" height="1" fill="#446" />
      <rect x="5" y="8" width="4" height="1" fill="#333" />

      <rect x="22" y="4" width="6" height="10" fill="#1a1a2a" />
      <rect x="22" y="4" width="6" height="1" fill="#2a2a3a" />
      <rect x="23" y="7" width="1" height="1" fill="#446" />
      <rect x="26" y="7" width="1" height="1" fill="#446" />

      <rect x="12" y="14" width="8" height="10" fill="#1a1a2a" />
      <rect x="12" y="14" width="8" height="1" fill="#2a2a3a" />
      <rect x="14" y="17" width="1" height="1" fill="#446" />
      <rect x="17" y="17" width="1" height="1" fill="#446" />
      <rect x="14" y="20" width="4" height="1" fill="#333" />

      <rect x="14" y="10" width="4" height="4" fill="#0f0f1f" />
      <rect x="15" y="11" width="2" height="2" fill="#4af" />
      <rect x="15" y="11" width="1" height="1" fill="#8cf" />

      <rect x="4" y="26" width="24" height="1" fill="#222" />
      <rect x="6" y="27" width="3" height="1" fill="#1a1a2a" />
      <rect x="15" y="27" width="3" height="1" fill="#1a1a2a" />
      <rect x="23" y="27" width="3" height="1" fill="#1a1a2a" />

      <rect x="3" y="16" width="1" height="1" fill="#224" />
      <rect x="28" y="10" width="1" height="1" fill="#224" />
      <rect x="10" y="6" width="1" height="1" fill="#224" />

      <rect x="8" y="22" width="2" height="3" fill="#0a1a0a" />
      <rect x="8" y="22" width="2" height="1" fill="#1a3a1a" />
      <rect x="9" y="23" width="1" height="1" fill="#0f2" />
    </svg>
    """
  end

  # -- FOTAQ: jungle adventure with biplane --

  attr :class, :string, default: nil

  @spec icon_game_fotaq(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_fotaq(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#1a4a1a" />

      <rect x="2" y="2" width="28" height="8" fill="#2a6a2a" />
      <rect x="2" y="2" width="28" height="3" fill="#3a8a3a" />

      <rect x="18" y="5" width="8" height="3" fill="#c0c0c0" />
      <rect x="21" y="4" width="2" height="1" fill="#c0c0c0" />
      <rect x="19" y="6" width="6" height="1" fill="#808080" />
      <rect x="25" y="6" width="1" height="1" fill="#a00" />

      <rect x="3" y="12" width="3" height="16" fill="#2a5a1a" />
      <rect x="3" y="10" width="3" height="2" fill="#3a7a2a" />
      <rect x="4" y="9" width="1" height="1" fill="#3a7a2a" />
      <rect x="2" y="14" width="2" height="3" fill="#2a5a1a" />
      <rect x="5" y="13" width="2" height="4" fill="#2a5a1a" />

      <rect x="8" y="10" width="4" height="18" fill="#2a5a1a" />
      <rect x="8" y="8" width="4" height="2" fill="#3a7a2a" />
      <rect x="9" y="7" width="2" height="1" fill="#3a7a2a" />
      <rect x="7" y="12" width="2" height="5" fill="#2a5a1a" />
      <rect x="11" y="11" width="2" height="6" fill="#2a5a1a" />

      <rect x="14" y="14" width="3" height="14" fill="#2a5a1a" />
      <rect x="14" y="12" width="3" height="2" fill="#3a7a2a" />
      <rect x="15" y="11" width="1" height="1" fill="#3a7a2a" />

      <rect x="19" y="16" width="4" height="12" fill="#2a5a1a" />
      <rect x="19" y="14" width="4" height="2" fill="#3a7a2a" />
      <rect x="20" y="13" width="2" height="1" fill="#3a7a2a" />

      <rect x="25" y="18" width="3" height="10" fill="#2a5a1a" />
      <rect x="25" y="16" width="3" height="2" fill="#3a7a2a" />

      <rect x="12" y="22" width="2" height="2" fill="#ffa" />
      <rect x="21" y="24" width="1" height="1" fill="#ffa" />
    </svg>
    """
  end

  # -- Lure of the Temptress: medieval castle + torch --

  attr :class, :string, default: nil

  @spec icon_game_lure(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_lure(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#1a2a1a" />

      <rect x="4" y="10" width="5" height="18" fill="#4a3a2a" />
      <rect x="4" y="8" width="5" height="2" fill="#5a4a3a" />
      <rect x="3" y="8" width="1" height="2" fill="#5a4a3a" />
      <rect x="9" y="8" width="1" height="2" fill="#5a4a3a" />
      <rect x="5" y="12" width="1" height="1" fill="#332" />
      <rect x="7" y="12" width="1" height="1" fill="#332" />
      <rect x="5" y="18" width="3" height="4" fill="#332" />

      <rect x="12" y="6" width="8" height="22" fill="#4a3a2a" />
      <rect x="12" y="4" width="8" height="2" fill="#5a4a3a" />
      <rect x="11" y="4" width="1" height="2" fill="#5a4a3a" />
      <rect x="20" y="4" width="1" height="2" fill="#5a4a3a" />
      <rect x="14" y="9" width="1" height="2" fill="#332" />
      <rect x="17" y="9" width="1" height="2" fill="#332" />
      <rect x="14" y="14" width="4" height="5" fill="#332" />
      <rect x="15" y="21" width="2" height="7" fill="#5a3a1a" />

      <rect x="23" y="12" width="5" height="16" fill="#4a3a2a" />
      <rect x="23" y="10" width="5" height="2" fill="#5a4a3a" />
      <rect x="22" y="10" width="1" height="2" fill="#5a4a3a" />
      <rect x="28" y="10" width="1" height="2" fill="#5a4a3a" />
      <rect x="24" y="15" width="1" height="1" fill="#332" />
      <rect x="26" y="15" width="1" height="1" fill="#332" />

      <rect x="9" y="4" width="1" height="4" fill="#5a3a1a" />
      <rect x="9" y="2" width="1" height="2" fill="#f82" />
      <rect x="9" y="2" width="1" height="1" fill="#ff4" />
    </svg>
    """
  end

  # -- Soltys: underground cartoon puzzle --

  attr :class, :string, default: nil

  @spec icon_game_soltys(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_soltys(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#4a8af4" />

      <rect x="2" y="16" width="28" height="12" fill="#5a3a1a" />
      <rect x="2" y="14" width="28" height="2" fill="#3a7a2a" />

      <rect x="6" y="5" width="4" height="9" fill="#c44" />
      <rect x="7" y="3" width="2" height="2" fill="#c44" />
      <rect x="6" y="5" width="4" height="1" fill="#e66" />
      <rect x="7" y="7" width="1" height="1" fill="#fff" />
      <rect x="7" y="9" width="2" height="1" fill="#fca" />

      <rect x="10" y="18" width="12" height="8" fill="#3a2a0a" />
      <rect x="10" y="18" width="12" height="1" fill="#4a3a1a" />
      <rect x="14" y="20" width="4" height="6" fill="#2a1a0a" />
      <rect x="15" y="21" width="2" height="2" fill="#ffa" />

      <rect x="4" y="20" width="4" height="2" fill="#888" />
      <rect x="4" y="20" width="4" height="1" fill="#aaa" />
      <rect x="5" y="22" width="2" height="4" fill="#666" />

      <rect x="24" y="18" width="4" height="3" fill="#888" />
      <rect x="24" y="18" width="4" height="1" fill="#aaa" />
      <rect x="25" y="21" width="2" height="5" fill="#666" />

      <rect x="20" y="7" width="2" height="2" fill="#ff4" />
      <rect x="20" y="7" width="1" height="1" fill="#ffa" />
    </svg>
    """
  end

  # -- Generic game icon (fallback) --

  attr :class, :string, default: nil

  @spec icon_game_generic(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_generic(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <rect x="8" y="12" width="16" height="10" fill="#555" />
      <path d="M11 15h2v1h1v2h-1v1h-2v-1h-1v-2h1v-1z" fill="#000" />
      <rect x="11" y="16" width="2" height="2" fill="#111" />
      <rect x="18" y="14" width="2" height="2" fill="#000" />
      <rect x="21" y="16" width="2" height="2" fill="#000" />
    </svg>
    """
  end

  # Genres — the category folders of the Retro Games and the Arcade.

  # -- Sports: a trophy --

  attr :class, :string, default: nil

  @spec icon_game_genre_sports(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_genre_sports(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <path
        d="M9 6h14v1h-14zM9 7h1v4h-1zM12 7h10v1h-10zM11 8h11v3h-11zM9 11h13v2h-13zM10 13h11v1h-11zM11 14h9v1h-9zM12 15h7v1h-7zM14 16h3v1h-3zM15 17h1v2h-1zM14 19h3v1h-3zM13 20h5v1h-5z"
        fill="#ffcc00"
      />
      <path
        d="M5 7h4v1h-4zM22 7h5v1h-5zM5 8h1v3h-1zM8 8h1v4h-1zM22 8h1v4h-1zM26 8h1v3h-1zM6 11h1v1h-1zM25 11h1v1h-1zM7 12h2v1h-2zM22 12h3v1h-3zM9 13h1v1h-1zM21 13h1v1h-1zM10 14h1v1h-1zM20 14h1v1h-1zM11 15h1v1h-1zM19 15h1v1h-1zM13 16h1v1h-1zM17 16h1v1h-1zM14 17h1v2h-1zM16 17h1v2h-1zM13 19h1v1h-1zM17 19h1v1h-1zM12 20h1v1h-1zM18 20h1v1h-1z"
        fill="#ff6600"
      />
      <path d="M10 7h2v1h-2zM10 8h1v3h-1z" fill="#fff" />
      <path d="M10 21h11v1h-11zM10 22h1v3h-1zM20 22h1v3h-1zM9 25h13v1h-13z" fill="#8b5a2b" />
      <path d="M11 22h9v1h-9zM11 23h1v1h-1zM19 23h1v1h-1zM11 24h9v1h-9z" fill="#b08850" />
      <path d="M12 23h7v1h-7z" fill="#e8c98a" />
    </svg>
    """
  end

  # -- Shooters: a crosshair --

  attr :class, :string, default: nil

  @spec icon_game_genre_shooters(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_genre_shooters(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <path
        d="M15 3h2v2h-2zM13 5h6v1h-6zM10 6h12v1h-12zM9 7h4v1h-4zM15 7h2v4h-2zM19 7h4v1h-4zM8 8h3v1h-3zM21 8h3v1h-3zM7 9h3v1h-3zM22 9h3v1h-3zM6 10h3v1h-3zM23 10h3v1h-3zM6 11h2v2h-2zM24 11h2v2h-2zM5 13h2v2h-2zM25 13h2v2h-2zM3 15h8v2h-8zM21 15h8v2h-8zM5 17h2v2h-2zM25 17h2v2h-2zM6 19h2v2h-2zM24 19h2v2h-2zM6 21h3v1h-3zM15 21h2v4h-2zM23 21h3v1h-3zM7 22h3v1h-3zM22 22h3v1h-3zM8 23h3v1h-3zM21 23h3v1h-3zM9 24h4v1h-4zM19 24h4v1h-4zM10 25h12v1h-12zM13 26h6v1h-6zM15 27h2v2h-2z"
        fill="#ff0000"
      />
      <path
        d="M14 11h4v1h-4zM12 12h2v1h-2zM18 12h2v1h-2zM12 13h1v1h-1zM19 13h1v1h-1zM11 14h1v4h-1zM20 14h1v4h-1zM12 18h1v1h-1zM19 18h1v1h-1zM12 19h2v1h-2zM18 19h2v1h-2zM14 20h4v1h-4z"
        fill="#990000"
      />
      <path d="M15 15h2v2h-2z" fill="#ffcc00" />
    </svg>
    """
  end

  # -- Action: a lightning bolt --

  attr :class, :string, default: nil

  @spec icon_game_genre_action(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_genre_action(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <path
        d="M18 5h8v1h-8zM17 6h1v1h-1zM24 6h1v1h-1zM16 7h1v1h-1zM23 7h1v1h-1zM15 8h1v1h-1zM22 8h1v1h-1zM14 9h1v1h-1zM21 9h1v1h-1zM13 10h1v1h-1zM20 10h1v1h-1zM12 11h1v1h-1zM19 11h1v1h-1zM11 12h1v1h-1zM18 12h7v1h-7zM10 13h1v1h-1zM23 13h1v1h-1zM9 14h7v1h-7zM22 14h1v1h-1zM14 15h1v1h-1zM20 15h1v1h-1zM13 16h1v1h-1zM19 16h1v1h-1zM12 17h1v1h-1zM18 17h1v1h-1zM11 18h1v1h-1zM16 18h1v1h-1zM10 19h1v1h-1zM15 19h1v1h-1zM9 20h1v1h-1zM13 20h1v1h-1zM8 21h1v1h-1zM12 21h1v1h-1zM7 22h1v2h-1zM10 22h1v1h-1zM9 23h1v1h-1zM6 24h1v1h-1zM8 24h1v1h-1zM6 25h2v1h-2z"
        fill="#ff6600"
      />
      <path
        d="M18 6h6v1h-6zM17 7h6v1h-6zM16 8h6v1h-6zM15 9h6v1h-6zM14 10h6v1h-6zM13 11h6v1h-6zM12 12h6v1h-6zM11 13h12v1h-12zM16 14h6v1h-6zM15 15h5v1h-5zM14 16h5v1h-5zM13 17h5v1h-5zM12 18h4v1h-4zM11 19h4v1h-4zM10 20h3v1h-3zM9 21h3v1h-3zM8 22h2v1h-2zM8 23h1v1h-1zM7 24h1v1h-1z"
        fill="#ffcc00"
      />
    </svg>
    """
  end

  # -- Cards: a card face over a card back --

  attr :class, :string, default: nil

  @spec icon_game_genre_cards(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_genre_cards(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <path
        d="M5 5h13v1h-13zM5 6h1v16h-1zM17 6h1v3h-1zM13 9h14v1h-14zM13 10h1v12h-1zM26 10h1v17h-1zM5 22h9v1h-9zM13 23h1v4h-1zM13 27h14v1h-14z"
        fill="#000"
      />
      <path
        d="M6 6h11v1h-11zM6 7h1v14h-1zM16 7h1v2h-1zM14 10h12v1h-12zM14 11h1v2h-1zM16 11h1v1h-1zM18 11h8v2h-8zM14 13h2v1h-2zM17 13h9v1h-9zM14 14h12v1h-12zM14 15h3v1h-3zM19 15h1v1h-1zM22 15h4v1h-4zM14 16h2v2h-2zM23 16h3v2h-3zM14 18h3v1h-3zM22 18h4v1h-4zM14 19h4v1h-4zM21 19h5v1h-5zM14 20h5v1h-5zM20 20h6v1h-6zM6 21h7v1h-7zM14 21h12v6h-12z"
        fill="#fff"
      />
      <path
        d="M7 7h1v1h-1zM9 7h1v1h-1zM11 7h1v1h-1zM13 7h1v1h-1zM15 7h1v1h-1zM8 8h1v1h-1zM10 8h1v1h-1zM12 8h1v1h-1zM14 8h1v1h-1zM7 9h1v1h-1zM9 9h1v1h-1zM11 9h1v1h-1zM8 10h1v1h-1zM10 10h1v1h-1zM12 10h1v1h-1zM7 11h1v1h-1zM9 11h1v1h-1zM11 11h1v1h-1zM8 12h1v1h-1zM10 12h1v1h-1zM12 12h1v1h-1zM7 13h1v1h-1zM9 13h1v1h-1zM11 13h1v1h-1zM8 14h1v1h-1zM10 14h1v1h-1zM12 14h1v1h-1zM7 15h1v1h-1zM9 15h1v1h-1zM11 15h1v1h-1zM8 16h1v1h-1zM10 16h1v1h-1zM12 16h1v1h-1zM7 17h1v1h-1zM9 17h1v1h-1zM11 17h1v1h-1zM8 18h1v1h-1zM10 18h1v1h-1zM12 18h1v1h-1zM7 19h1v1h-1zM9 19h1v1h-1zM11 19h1v1h-1zM8 20h1v1h-1zM10 20h1v1h-1zM12 20h1v1h-1z"
        fill="#003399"
      />
      <path
        d="M8 7h1v1h-1zM10 7h1v1h-1zM12 7h1v1h-1zM14 7h1v1h-1zM7 8h1v1h-1zM9 8h1v1h-1zM11 8h1v1h-1zM13 8h1v1h-1zM15 8h1v1h-1zM8 9h1v1h-1zM10 9h1v1h-1zM12 9h1v1h-1zM7 10h1v1h-1zM9 10h1v1h-1zM11 10h1v1h-1zM8 11h1v1h-1zM10 11h1v1h-1zM12 11h1v1h-1zM7 12h1v1h-1zM9 12h1v1h-1zM11 12h1v1h-1zM8 13h1v1h-1zM10 13h1v1h-1zM12 13h1v1h-1zM7 14h1v1h-1zM9 14h1v1h-1zM11 14h1v1h-1zM8 15h1v1h-1zM10 15h1v1h-1zM12 15h1v1h-1zM7 16h1v1h-1zM9 16h1v1h-1zM11 16h1v1h-1zM8 17h1v1h-1zM10 17h1v1h-1zM12 17h1v1h-1zM7 18h1v1h-1zM9 18h1v1h-1zM11 18h1v1h-1zM8 19h1v1h-1zM10 19h1v1h-1zM12 19h1v1h-1zM7 20h1v1h-1zM9 20h1v1h-1zM11 20h1v1h-1z"
        fill="#0066ff"
      />
      <path
        d="M15 11h1v1h-1zM17 11h1v1h-1zM15 12h3v1h-3zM16 13h1v1h-1zM17 15h2v1h-2zM20 15h2v1h-2zM16 16h7v2h-7zM17 18h5v1h-5zM18 19h3v1h-3zM19 20h1v1h-1z"
        fill="#ff0000"
      />
    </svg>
    """
  end

  # -- Puzzles: a jigsaw piece --

  attr :class, :string, default: nil

  @spec icon_game_genre_puzzles(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_genre_puzzles(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <path
        d="M14 3h1v1h-1zM12 4h5v2h-5zM11 6h7v1h-7zM12 7h6v1h-6zM12 8h5v1h-5zM13 9h4v1h-4zM13 10h3v1h-3zM6 11h16v4h-16zM8 15h14v1h-14zM9 16h18v1h-18zM9 17h19v4h-19zM8 21h15v1h-15zM25 21h1v1h-1zM6 22h16v4h-16z"
        fill="#00ccff"
      />
      <path
        d="M15 3h1v1h-1zM17 4h1v2h-1zM18 6h1v2h-1zM11 7h1v1h-1zM17 8h1v2h-1zM12 9h1v1h-1zM16 10h1v1h-1zM22 11h1v5h-1zM6 15h2v1h-2zM25 15h1v1h-1zM8 16h1v1h-1zM27 16h1v1h-1zM28 17h1v4h-1zM23 21h2v1h-2zM26 21h2v1h-2zM22 22h1v4h-1zM25 22h1v1h-1zM6 26h17v1h-17z"
        fill="#006699"
      />
    </svg>
    """
  end

  # -- First-person shooters: a corridor seen down the barrel --

  attr :class, :string, default: nil

  @spec icon_game_genre_fps(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_genre_fps(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <path
        d="M2 2h28v1h-28zM3 3h26v1h-26zM4 4h24v1h-24zM5 5h22v1h-22zM6 6h20v1h-20zM7 7h18v1h-18zM8 8h16v1h-16zM9 9h14v1h-14zM10 10h12v1h-12zM11 11h10v1h-10zM15 18h2v1h-2z"
        fill="#000"
      />
      <path
        d="M2 3h1v1h-1zM29 3h1v1h-1zM2 4h2v1h-2zM28 4h2v1h-2zM2 5h3v1h-3zM27 5h3v1h-3zM2 6h4v1h-4zM26 6h4v1h-4zM2 7h5v1h-5zM25 7h5v1h-5zM2 8h6v1h-6zM24 8h6v1h-6zM2 9h7v1h-7zM23 9h7v1h-7zM2 10h8v1h-8zM22 10h8v1h-8zM2 11h9v1h-9zM21 11h9v1h-9zM2 12h10v8h-10zM20 12h10v8h-10zM13 18h1v6h-1zM18 18h1v6h-1zM2 20h9v1h-9zM21 20h9v1h-9zM2 21h8v1h-8zM22 21h8v1h-8zM2 22h7v1h-7zM23 22h7v1h-7zM2 23h6v1h-6zM24 23h6v1h-6zM2 24h5v1h-5zM25 24h5v1h-5zM2 25h4v1h-4zM26 25h4v1h-4zM2 26h3v1h-3zM27 26h3v1h-3zM2 27h2v1h-2zM28 27h2v1h-2zM2 28h1v1h-1zM29 28h1v1h-1z"
        fill="#888"
      />
      <path
        d="M12 12h8v2h-8zM12 14h2v1h-2zM15 14h2v1h-2zM18 14h2v1h-2zM12 15h8v3h-8zM12 18h1v2h-1zM19 18h1v2h-1z"
        fill="#444"
      />
      <path d="M14 14h1v1h-1zM17 14h1v1h-1z" fill="#ff0000" />
      <path d="M14 18h1v1h-1zM17 18h1v1h-1zM14 19h4v5h-4z" fill="#c0c0c0" />
      <path
        d="M11 20h2v1h-2zM19 20h2v1h-2zM10 21h3v1h-3zM19 21h3v1h-3zM9 22h4v1h-4zM19 22h4v1h-4zM8 23h5v1h-5zM19 23h5v1h-5zM7 24h5v1h-5zM20 24h5v1h-5zM6 25h6v1h-6zM20 25h6v1h-6zM5 26h6v1h-6zM20 26h7v1h-7zM4 27h7v1h-7zM20 27h8v1h-8zM3 28h8v1h-8zM20 28h9v1h-9zM2 29h9v1h-9zM20 29h10v1h-10z"
        fill="#8b5a2b"
      />
      <path d="M12 24h8v1h-8zM11 26h1v4h-1z" fill="#b08850" />
      <path d="M12 25h8v5h-8z" fill="#e8c98a" />
    </svg>
    """
  end

  # -- Adventures: a magnifying glass over a map --

  attr :class, :string, default: nil

  @spec icon_game_genre_adventure(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_genre_adventure(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="0" width="32" height="32" fill="#333" />
      <path d="M0 0h32v2H2v28H0z" fill="#777" />
      <path d="M0 32h32v-2H2V2h30V0h-2v30H0z" fill="#000" />
      <rect x="2" y="2" width="28" height="28" fill="#000033" />

      <path
        d="M3 6h1v20h-1zM24 6h1v13h-1zM22 19h3v1h-3zM22 20h1v1h-1zM24 20h1v1h-1zM23 21h1v1h-1zM25 21h1v1h-1zM24 22h1v1h-1zM26 22h1v1h-1zM24 23h2v1h-2zM27 23h1v1h-1zM24 24h1v2h-1zM26 24h1v1h-1zM28 24h1v1h-1zM27 25h1v1h-1z"
        fill="#8b5a2b"
      />
      <path
        d="M4 6h20v1h-20zM23 20h1v1h-1zM24 21h1v1h-1zM25 22h1v1h-1zM26 23h1v1h-1zM27 24h1v1h-1zM4 25h20v1h-20zM28 25h1v1h-1z"
        fill="#b08850"
      />
      <path
        d="M4 7h10v1h-10zM20 7h4v1h-4zM4 8h2v2h-2zM8 8h5v1h-5zM21 8h3v1h-3zM9 9h3v1h-3zM22 9h2v1h-2zM4 10h3v1h-3zM8 10h3v1h-3zM23 10h1v1h-1zM4 11h6v6h-6zM4 17h7v1h-7zM23 17h1v1h-1zM4 18h8v1h-8zM22 18h2v1h-2zM4 19h9v1h-9zM21 19h1v1h-1zM4 20h10v1h-10zM20 20h2v1h-2zM4 21h6v1h-6zM11 21h12v1h-12zM4 22h4v1h-4zM9 22h3v1h-3zM13 22h11v1h-11zM4 23h2v1h-2zM7 23h17v1h-17zM4 24h20v1h-20z"
        fill="#e8c98a"
      />
      <path
        d="M14 7h6v1h-6zM13 8h8v1h-8zM12 9h3v1h-3zM19 9h3v1h-3zM11 10h2v1h-2zM21 10h2v1h-2zM10 11h3v1h-3zM21 11h3v1h-3zM10 12h2v4h-2zM22 12h2v4h-2zM10 16h3v1h-3zM21 16h3v1h-3zM11 17h2v1h-2zM21 17h2v1h-2zM12 18h3v1h-3zM19 18h3v1h-3zM13 19h8v1h-8zM14 20h6v1h-6z"
        fill="#c0c0c0"
      />
      <path d="M6 8h2v1h-2zM6 9h3v1h-3zM7 10h1v1h-1z" fill="#006600" />
      <path
        d="M15 9h4v1h-4zM13 10h8v1h-8zM13 11h1v1h-1zM16 11h5v1h-5zM12 12h2v1h-2zM15 12h7v1h-7zM12 13h10v3h-10zM13 16h8v2h-8zM15 18h4v1h-4z"
        fill="#00ccff"
      />
      <path d="M14 11h2v1h-2zM14 12h1v1h-1z" fill="#fff" />
      <path d="M10 21h1v1h-1zM8 22h1v1h-1zM12 22h1v1h-1zM6 23h1v1h-1z" fill="#990000" />
    </svg>
    """
  end
end
