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
  def game_icon(%{game_id: "hex_frost"} = assigns), do: icon_game_frost(assigns)
  def game_icon(%{game_id: "hex_frost_blizzard"} = assigns), do: icon_game_frost(assigns)
  def game_icon(%{game_id: "hex_frost_peaceful"} = assigns), do: icon_game_frost(assigns)
  def game_icon(%{game_id: "hex_hockey"} = assigns), do: icon_game_hockey(assigns)
  def game_icon(%{game_id: "hex_hockey_blitz"} = assigns), do: icon_game_hockey(assigns)
  def game_icon(%{game_id: "hex_hockey_showdown"} = assigns), do: icon_game_hockey(assigns)
  def game_icon(%{game_id: "doom_shareware"} = assigns), do: icon_game_doom(assigns)
  def game_icon(%{game_id: "freedoom1"} = assigns), do: icon_game_freedoom1(assigns)
  def game_icon(%{game_id: "freedoom2"} = assigns), do: icon_game_freedoom2(assigns)
  def game_icon(%{game_id: "freedm"} = assigns), do: icon_game_freedm(assigns)
  def game_icon(%{game_id: "chex_quest"} = assigns), do: icon_game_chex(assigns)
  def game_icon(%{game_id: "hacx"} = assigns), do: icon_game_hacx(assigns)
  def game_icon(%{game_id: "rekkr"} = assigns), do: icon_game_rekkr(assigns)
  def game_icon(%{game_id: "quake_shareware"} = assigns), do: icon_game_quake(assigns)
  def game_icon(%{game_id: "librequake"} = assigns), do: icon_game_librequake(assigns)
  def game_icon(%{game_id: "quake2_shareware"} = assigns), do: icon_game_quake2(assigns)
  def game_icon(%{game_id: "wolfenstein_3d"} = assigns), do: icon_game_wolfenstein(assigns)
  def game_icon(%{game_id: "halflife_uplink"} = assigns), do: icon_game_halflife(assigns)
  def game_icon(%{game_id: "scummvm_bass"} = assigns), do: icon_game_bass(assigns)
  def game_icon(%{game_id: "scummvm_drascula"} = assigns), do: icon_game_drascula(assigns)
  def game_icon(%{game_id: "scummvm_dreamweb"} = assigns), do: icon_game_dreamweb(assigns)
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
