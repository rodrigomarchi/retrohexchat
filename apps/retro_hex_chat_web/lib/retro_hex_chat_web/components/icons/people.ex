defmodule RetroHexChatWeb.Icons.People do
  @moduledoc """
  Icons depicting people, users, and social concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_community(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_community(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <path d="M4 18 C4 14 7 12 10 12 C13 12 16 14 16 18 M16 18 C16 14 19 12 22 12 C25 12 28 14 28 18 M10 26 C10 22 13 20 16 20 C19 20 22 22 22 26" fill="none" stroke="#000" stroke-width="4" stroke-linecap="round" transform="translate(1,1)" />
      
      <!-- Back figure (Navy) -->
      <circle cx="10" cy="8" r="4" fill="#000080" stroke="#000" stroke-width="1.5" />
      <path d="M4 18 C4 14 7 12 10 12 C13 12 16 14 16 18" fill="#000080" stroke="#000" stroke-width="1.5" stroke-linecap="round" />
      <path d="M5 18 C5 15 7 13 10 13" fill="none" stroke="#fff" stroke-width="1" opacity="0.6" stroke-linecap="round" />
      
      <!-- Middle figure (Teal) -->
      <circle cx="22" cy="8" r="4" fill="#008080" stroke="#000" stroke-width="1.5" />
      <path d="M16 18 C16 14 19 12 22 12 C25 12 28 14 28 18" fill="#008080" stroke="#000" stroke-width="1.5" stroke-linecap="round" />
      <path d="M17 18 C17 15 19 13 22 13" fill="none" stroke="#fff" stroke-width="1" opacity="0.6" stroke-linecap="round" />
      
      <!-- Front figure (Gray/Silver) -->
      <circle cx="16" cy="16" r="4" fill="#C0C0C0" stroke="#000" stroke-width="1.5" />
      <path d="M10 26 C10 22 13 20 16 20 C19 20 22 22 22 26" fill="#C0C0C0" stroke="#000" stroke-width="1.5" stroke-linecap="round" />
      <path d="M11 26 C11 23 13 21 16 21" fill="none" stroke="#fff" stroke-width="1.5" opacity="0.8" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_connect(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_connect(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow Base -->
      <circle cx="17" cy="17" r="13" fill="#000" />
      <path d="M12 9 L 12 25 L 26 17 z" fill="#000" transform="translate(1,1)" />
      
      <!-- Base Circle (Green) -->
      <circle cx="16" cy="16" r="13" fill="#008000" stroke="#000" stroke-width="1.5" />
      <!-- Bevel -->
      <path d="M16 4 A 12 12 0 0 0 4 16" fill="none" stroke="#fff" stroke-width="2" opacity="0.6" stroke-linecap="round" />
      
      <!-- Connect Arrow -->
      <path d="M12 9 L 12 25 L 26 17 z" fill="#fff" stroke="#000" stroke-width="1.5" stroke-linejoin="round" />
      <line x1="13" y1="12" x2="13" y2="22" stroke="#dfdfdf" stroke-width="1.5" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_robot(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_robot(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Antenna Shadow -->
      <line x1="16" y1="8" x2="16" y2="10" stroke="#000" stroke-width="3" transform="translate(1,1)" />
      <!-- Antenna -->
      <line x1="16" y1="6" x2="16" y2="10" stroke="#808080" stroke-width="2" />
      <circle cx="16" cy="5" r="2" fill="#FF0000" stroke="#000" stroke-width="1.5" />
      
      <!-- Head Shadow -->
      <rect x="8" y="10" width="16" height="16" rx="2" fill="#000" transform="translate(1,1)" />
      <!-- Head Base -->
      <rect x="8" y="10" width="16" height="16" rx="2" fill="#C0C0C0" stroke="#000" stroke-width="1.5" />
      <!-- Bevel -->
      <path d="M9 11 h 14" stroke="#fff" stroke-width="1.5" opacity="0.6" stroke-linecap="round" />
      <path d="M9 11 v 14" stroke="#fff" stroke-width="1.5" opacity="0.6" stroke-linecap="round" />
      
      <!-- Eyes -->
      <rect x="10" y="13" width="4" height="4" fill="#FF0000" stroke="#000" stroke-width="1" />
      <rect x="18" y="13" width="4" height="4" fill="#FF0000" stroke="#000" stroke-width="1" />
      
      <!-- Mouth -->
      <rect x="12" y="20" width="8" height="2" fill="#000080" />
      
      <!-- Ears -->
      <path d="M6 16 v 4 M26 16 v 4" stroke="#000" stroke-width="2" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_address_book(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_address_book(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <rect x="5" y="2" width="10" height="13" fill="#000" />
      <!-- Book Body -->
      <rect x="4" y="1" width="10" height="13" fill="#fff" stroke="#000" stroke-width="1" />
      <!-- Tabs (Gold) -->
      <rect x="2" y="3" width="2" height="2" fill="#FFD700" stroke="#000" stroke-width="1" />
      <rect x="2" y="7" width="2" height="2" fill="#FFD700" stroke="#000" stroke-width="1" />
      <rect x="2" y="11" width="2" height="2" fill="#FFD700" stroke="#000" stroke-width="1" />
      <!-- Lines (Black instead of Navy) -->
      <line x1="6" y1="4" x2="12" y2="4" stroke="#000" stroke-width="1" />
      <line x1="6" y1="7" x2="12" y2="7" stroke="#000" stroke-width="1" />
      <line x1="6" y1="10" x2="12" y2="10" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_nick(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_nick(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <rect x="4" y="3" width="6" height="5" fill="#000" />
      <polygon points="1,15 13,15 13,10 10,8 4,8 1,10" fill="#000" />
      
      <!-- Person (White for dark bg) -->
      <rect x="3" y="2" width="6" height="5" fill="#fff" stroke="#000" stroke-width="1" />
      <polygon points="1,14 12,14 12,10 9,8 3,8 1,10" fill="#fff" stroke="#000" stroke-width="1" />
      
      <!-- Edit Pencil or Plus (Gold) -->
      <polygon points="12,5 15,5 15,6 12,6" fill="#FFD700" stroke="#000" stroke-width="1" />
      <polygon points="13,4 14,4 14,7 13,7" fill="#FFD700" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_contacts(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_contacts(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="5" y="2" width="6" height="5" fill="#000080" />
      <polygon points="3,14 13,14 13,10 10,8 6,8 3,10" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_status_user(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_status_user(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="5" y="2" width="6" height="5" fill="#000080" />
      <polygon points="3,14 13,14 13,10 10,8 6,8 3,10" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_role_owner(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_role_owner(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Crown Base -->
      <polygon points="4,10 12,10 11,13 5,13" fill="#FFD700" stroke="#000" stroke-width="1" />
      <polygon points="3,6 5,6 6,9 10,9 11,6 13,6 12,10 4,10" fill="#FFD700" stroke="#000" stroke-width="1" />
      
      <!-- Crown Points -->
      <rect x="3" y="5" width="2" height="2" fill="#FF0000" stroke="#000" stroke-width="1" />
      <rect x="7" y="4" width="2" height="2" fill="#008000" stroke="#000" stroke-width="1" />
      <rect x="11" y="5" width="2" height="2" fill="#000080" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_role_operator(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_role_operator(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Outline/Shadow -->
      <polygon points="3,2 13,2 13,8 8,14 3,8" fill="#000" />
      
      <!-- Navy Shield Base -->
      <polygon points="4,3 12,3 12,8 8,12 4,8" fill="#000080" />
      
      <!-- Star (Gold) -->
      <rect x="7" y="5" width="2" height="2" fill="#FFD700" />
      <rect x="6" y="6" width="4" height="1" fill="#FFD700" />
      <rect x="6" y="8" width="1" height="1" fill="#FFD700" />
      <rect x="9" y="8" width="1" height="1" fill="#FFD700" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_role_halfop(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_role_halfop(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Outline/Shadow -->
      <polygon points="3,2 13,2 13,8 8,14 3,8" fill="#000" />
      
      <!-- Shield Base -->
      <polygon points="4,3 12,3 12,8 8,12 4,8" fill="#C0C0C0" />
      
      <!-- Half (Green) -->
      <polygon points="4,3 8,3 8,12 4,8" fill="#008000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_role_voiced(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_role_voiced(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Speaker Cone -->
      <polygon points="7,5 3,7 3,9 7,11" fill="#000080" />
      <rect x="7" y="5" width="2" height="6" fill="#000080" />
      
      <!-- Waves -->
      <rect x="10" y="6" width="1" height="4" fill="#000080" />
      <rect x="12" y="5" width="1" height="6" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_role_regular(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_role_regular(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="6" y="5" width="4" height="3" fill="#555" />
      <polygon points="5,11 11,11 11,9 9,8 7,8 5,9" fill="#555" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_nicklist(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_nicklist(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="5" y="2" width="6" height="5" fill="#000080" />
      <polygon points="3,14 13,14 13,10 10,8 6,8 3,10" fill="#000080" />
    </svg>
    """
  end
end
