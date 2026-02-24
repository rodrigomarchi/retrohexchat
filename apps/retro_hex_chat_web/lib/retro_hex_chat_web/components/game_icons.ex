defmodule RetroHexChatWeb.Components.GameIcons do
  @moduledoc """
  Retro pixel-art SVG icons for the 16 P2P games.
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
  def game_icon(assigns), do: icon_game_generic(assigns)

  # -- Hex Pong: paddle + ball --

  attr :class, :string, default: nil

  @spec icon_game_pong(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_pong(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <rect
        x="1"
        y="1"
        width="30"
        height="30"
        rx="2"
        fill="#000033"
        stroke="#008080"
        stroke-width="1"
      />
      <rect x="5" y="10" width="3" height="12" fill="#00ff00" />
      <rect x="24" y="10" width="3" height="12" fill="#00ff00" />
      <circle cx="16" cy="16" r="2" fill="#fff" />
      <line x1="16" y1="3" x2="16" y2="29" stroke="#006600" stroke-width="0.5" stroke-dasharray="2,2" />
    </svg>
    """
  end

  # -- Light Trails: grid + trails --

  attr :class, :string, default: nil

  @spec icon_game_trails(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_trails(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <rect
        x="1"
        y="1"
        width="30"
        height="30"
        rx="2"
        fill="#000033"
        stroke="#008080"
        stroke-width="1"
      />
      <polyline points="8,24 8,12 20,12" fill="none" stroke="#00ff00" stroke-width="2" />
      <polyline points="24,8 24,20 12,20" fill="none" stroke="#ff0000" stroke-width="2" />
      <rect x="7" y="11" width="2" height="2" fill="#00ff00" />
      <rect x="23" y="7" width="2" height="2" fill="#ff0000" />
    </svg>
    """
  end

  # -- Pixel Tanks: top-down tank --

  attr :class, :string, default: nil

  @spec icon_game_tanks(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_tanks(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <rect
        x="1"
        y="1"
        width="30"
        height="30"
        rx="2"
        fill="#000033"
        stroke="#008080"
        stroke-width="1"
      />
      <rect x="11" y="14" width="10" height="8" fill="#008000" stroke="#000" stroke-width="0.5" />
      <rect x="14" y="6" width="4" height="10" fill="#006600" stroke="#000" stroke-width="0.5" />
      <rect x="9" y="15" width="2" height="6" fill="#555" />
      <rect x="21" y="15" width="2" height="6" fill="#555" />
      <circle cx="16" cy="5" r="1.5" fill="#FFD700" />
    </svg>
    """
  end

  # -- Star Duel: spaceship --

  attr :class, :string, default: nil

  @spec icon_game_space(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_space(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <rect
        x="1"
        y="1"
        width="30"
        height="30"
        rx="2"
        fill="#000033"
        stroke="#008080"
        stroke-width="1"
      />
      <polygon points="16,6 22,24 16,20 10,24" fill="#C0C0C0" stroke="#000" stroke-width="0.5" />
      <polygon points="16,6 18,14 14,14" fill="#000080" />
      <circle cx="8" cy="10" r="1" fill="#FFD700" />
      <circle cx="25" cy="22" r="0.8" fill="#FFD700" />
      <circle cx="22" cy="6" r="0.6" fill="#fff" />
    </svg>
    """
  end

  # -- Gravity Well: star with gravity rings --

  attr :class, :string, default: nil

  @spec icon_game_gravity(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_gravity(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <rect
        x="1"
        y="1"
        width="30"
        height="30"
        rx="2"
        fill="#000033"
        stroke="#008080"
        stroke-width="1"
      />
      <circle cx="16" cy="16" r="4" fill="#ff8c00" />
      <circle cx="16" cy="16" r="4" fill="none" stroke="#FFD700" stroke-width="0.5" opacity="0.8" />
      <circle
        cx="16"
        cy="16"
        r="8"
        fill="none"
        stroke="#ff8c00"
        stroke-width="0.5"
        opacity="0.4"
        stroke-dasharray="2,2"
      />
      <circle
        cx="16"
        cy="16"
        r="12"
        fill="none"
        stroke="#ff8c00"
        stroke-width="0.3"
        opacity="0.2"
        stroke-dasharray="3,3"
      />
      <polygon points="8,8 6,12 9,11" fill="#C0C0C0" stroke="#000" stroke-width="0.3" />
      <polygon points="24,22 26,26 23,25" fill="#C0C0C0" stroke="#000" stroke-width="0.3" />
    </svg>
    """
  end

  # -- Debris Field: ship among rocks --

  attr :class, :string, default: nil

  @spec icon_game_debris(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_debris(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <rect
        x="1"
        y="1"
        width="30"
        height="30"
        rx="2"
        fill="#000033"
        stroke="#008080"
        stroke-width="1"
      />
      <polygon points="16,12 19,20 16,18 13,20" fill="#C0C0C0" stroke="#000" stroke-width="0.3" />
      <polygon points="6,6 10,5 9,9 5,8" fill="#555" stroke="#8b4513" stroke-width="0.5" />
      <polygon points="22,4 27,5 26,9 23,8" fill="#555" stroke="#8b4513" stroke-width="0.5" />
      <polygon points="4,20 8,19 7,24 3,23" fill="#666" stroke="#8b4513" stroke-width="0.5" />
      <polygon points="24,18 28,17 27,22 23,21" fill="#555" stroke="#8b4513" stroke-width="0.5" />
      <polygon points="12,25 16,24 15,28 11,27" fill="#666" stroke="#8b4513" stroke-width="0.5" />
    </svg>
    """
  end

  # -- Block Breakers: paddle + blocks --

  attr :class, :string, default: nil

  @spec icon_game_breakout(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_breakout(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <rect
        x="1"
        y="1"
        width="30"
        height="30"
        rx="2"
        fill="#000033"
        stroke="#008080"
        stroke-width="1"
      />
      <rect x="6" y="6" width="5" height="3" fill="#ff0000" />
      <rect x="13" y="6" width="5" height="3" fill="#FFD700" />
      <rect x="20" y="6" width="5" height="3" fill="#008000" />
      <rect x="6" y="11" width="5" height="3" fill="#000080" />
      <rect x="13" y="11" width="5" height="3" fill="#ff0000" />
      <rect x="20" y="11" width="5" height="3" fill="#FFD700" />
      <rect x="12" y="26" width="8" height="2" fill="#C0C0C0" />
      <circle cx="16" cy="22" r="1.5" fill="#fff" />
    </svg>
    """
  end

  # -- Hex Warlords: shield + fireball --

  attr :class, :string, default: nil

  @spec icon_game_warlords(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_warlords(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <rect
        x="1"
        y="1"
        width="30"
        height="30"
        rx="2"
        fill="#000033"
        stroke="#008080"
        stroke-width="1"
      />
      <rect x="4" y="8" width="3" height="16" fill="#C0C0C0" rx="1" />
      <rect x="25" y="8" width="3" height="16" fill="#C0C0C0" rx="1" />
      <rect x="9" y="6" width="2" height="4" fill="#ff4444" />
      <rect x="9" y="12" width="2" height="4" fill="#ff4444" />
      <rect x="9" y="18" width="2" height="4" fill="#ff4444" />
      <rect x="21" y="6" width="2" height="4" fill="#00e5ff" />
      <rect x="21" y="12" width="2" height="4" fill="#00e5ff" />
      <rect x="21" y="18" width="2" height="4" fill="#00e5ff" />
      <circle cx="16" cy="16" r="3" fill="#FFD700" />
      <circle cx="16" cy="16" r="1.5" fill="#ff8c00" />
    </svg>
    """
  end

  # -- Hex Raid: jet + river --

  attr :class, :string, default: nil

  @spec icon_game_raid(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_raid(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <rect
        x="1"
        y="1"
        width="30"
        height="30"
        rx="2"
        fill="#000033"
        stroke="#008080"
        stroke-width="1"
      />
      <rect x="1" y="1" width="8" height="30" fill="#1a2a1a" />
      <rect x="23" y="1" width="8" height="30" fill="#1a2a1a" />
      <rect x="9" y="1" width="14" height="30" fill="#0a1a2a" />
      <polygon points="16,8 13,16 14,15 16,18 18,15 19,16" fill="#39ff14" />
      <polygon points="16,20 14,26 15,25 16,27 17,25 18,26" fill="#00e5ff" />
      <rect x="15" y="5" width="2" height="2" fill="#ffee00" />
      <circle cx="12" cy="12" r="1.5" fill="#ff8c00" />
      <circle cx="20" cy="22" r="1.5" fill="#ff8c00" />
      <rect x="9" y="26" width="14" height="2" fill="#555" />
    </svg>
    """
  end

  # -- Hex Boxing: top-down ring with two fists --

  attr :class, :string, default: nil

  @spec icon_game_boxing(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_boxing(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <rect
        x="1"
        y="1"
        width="30"
        height="30"
        rx="2"
        fill="#000033"
        stroke="#008080"
        stroke-width="1"
      />
      <rect x="5" y="5" width="22" height="22" fill="none" stroke="#aaa" stroke-width="1.5" />
      <circle cx="12" cy="16" r="4" fill="#008000" stroke="#000" stroke-width="0.5" />
      <line x1="16" y1="16" x2="20" y2="16" stroke="#00cc00" stroke-width="2" stroke-linecap="round" />
      <circle cx="22" cy="16" r="4" fill="#008080" stroke="#000" stroke-width="0.5" />
      <line x1="18" y1="16" x2="14" y2="16" stroke="#00cccc" stroke-width="2" stroke-linecap="round" />
      <circle cx="20" cy="15" r="1.5" fill="#FFD700" />
      <circle cx="14" cy="17" r="1.5" fill="#FFD700" />
    </svg>
    """
  end

  # -- Hex Outlaw: crossed revolvers --

  attr :class, :string, default: nil

  @spec icon_game_outlaw(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_outlaw(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <rect
        x="1"
        y="1"
        width="30"
        height="30"
        rx="2"
        fill="#1a0a1e"
        stroke="#c4956a"
        stroke-width="1"
      />
      <line x1="8" y1="24" x2="24" y2="8" stroke="#aaa" stroke-width="2" stroke-linecap="round" />
      <line x1="24" y1="24" x2="8" y2="8" stroke="#aaa" stroke-width="2" stroke-linecap="round" />
      <rect x="6" y="22" width="5" height="3" rx="1" fill="#8b6914" />
      <rect x="21" y="22" width="5" height="3" rx="1" fill="#8b6914" />
      <circle cx="10" cy="10" r="2" fill="none" stroke="#aaa" stroke-width="1" />
      <circle cx="22" cy="10" r="2" fill="none" stroke="#aaa" stroke-width="1" />
      <circle cx="16" cy="16" r="2" fill="#ff4444" />
    </svg>
    """
  end

  # -- Generic game icon (fallback) --

  attr :class, :string, default: nil

  @spec icon_game_generic(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_game_generic(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <rect
        x="1"
        y="1"
        width="30"
        height="30"
        rx="2"
        fill="#000033"
        stroke="#008080"
        stroke-width="1"
      />
      <rect x="8" y="12" width="16" height="10" rx="2" fill="#555" stroke="#000" stroke-width="0.5" />
      <circle cx="12" cy="17" r="2" fill="#000" />
      <rect x="18" y="14" width="2" height="2" fill="#000" />
      <rect x="21" y="16" width="2" height="2" fill="#000" />
    </svg>
    """
  end
end
