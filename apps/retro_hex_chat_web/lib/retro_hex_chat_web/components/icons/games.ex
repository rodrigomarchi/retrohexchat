defmodule RetroHexChatWeb.Icons.Games do
  @moduledoc """
  Retro pixel-art SVG icons for the P2P games.
  Each icon is 32×32 and follows the project icon conventions.
  """
  use Phoenix.Component

  @doc """
  Renders the icon for a given game_id string.
  Falls back to a generic gamepad icon for unknown IDs.
  """
  attr :game_id, :string, required: true
  attr :class, :string, default: nil

  @spec game_icon(map()) :: Phoenix.LiveView.Rendered.t()
  def game_icon(%{game_id: "hex_pong"} = assigns), do: icon_game_pong(assigns)
  def game_icon(%{game_id: "light_trails"} = assigns), do: icon_game_trails(assigns)
  def game_icon(%{game_id: "pixel_tanks"} = assigns), do: icon_game_tanks(assigns)
  def game_icon(%{game_id: "star_duel"} = assigns), do: icon_game_space(assigns)
  def game_icon(%{game_id: "gravity_well"} = assigns), do: icon_game_gravity(assigns)
  def game_icon(%{game_id: "debris_field"} = assigns), do: icon_game_debris(assigns)
  def game_icon(%{game_id: "block_breakers"} = assigns), do: icon_game_breakout(assigns)
  def game_icon(%{game_id: "hex_warlords"} = assigns), do: icon_game_warlords(assigns)
  def game_icon(%{game_id: "hex_raid"} = assigns), do: icon_game_raid(assigns)
  def game_icon(%{game_id: "hex_raid_pacifist"} = assigns), do: icon_game_raid(assigns)
  def game_icon(%{game_id: "hex_raid_blitz"} = assigns), do: icon_game_raid(assigns)
  def game_icon(%{game_id: "hex_boxing"} = assigns), do: icon_game_boxing(assigns)
  def game_icon(%{game_id: "hex_outlaw"} = assigns), do: icon_game_outlaw(assigns)
  def game_icon(%{game_id: "hex_outlaw_ricochet"} = assigns), do: icon_game_outlaw(assigns)
  def game_icon(%{game_id: "hex_outlaw_stagecoach"} = assigns), do: icon_game_outlaw(assigns)
  def game_icon(%{game_id: "hex_outlaw_nml"} = assigns), do: icon_game_outlaw(assigns)
  def game_icon(%{game_id: "hex_invaders"} = assigns), do: icon_game_invaders(assigns)
  def game_icon(%{game_id: "hex_invaders_coop"} = assigns), do: icon_game_invaders(assigns)
  def game_icon(%{game_id: "hex_invaders_blitz"} = assigns), do: icon_game_invaders(assigns)
  def game_icon(%{game_id: "hex_enduro"} = assigns), do: icon_game_enduro(assigns)
  def game_icon(%{game_id: "hex_enduro_night"} = assigns), do: icon_game_enduro(assigns)
  def game_icon(%{game_id: "hex_enduro_sprint"} = assigns), do: icon_game_enduro(assigns)
  def game_icon(%{game_id: "hex_tennis"} = assigns), do: icon_game_tennis(assigns)
  def game_icon(%{game_id: "hex_tennis_quick"} = assigns), do: icon_game_tennis(assigns)
  def game_icon(%{game_id: "hex_tennis_sudden"} = assigns), do: icon_game_tennis(assigns)
  def game_icon(%{game_id: "hex_skiing"} = assigns), do: icon_game_skiing(assigns)
  def game_icon(%{game_id: "hex_skiing_escape"} = assigns), do: icon_game_skiing(assigns)
  def game_icon(%{game_id: "hex_skiing_clean"} = assigns), do: icon_game_skiing(assigns)
  def game_icon(assigns), do: icon_game_generic(assigns)

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
end
