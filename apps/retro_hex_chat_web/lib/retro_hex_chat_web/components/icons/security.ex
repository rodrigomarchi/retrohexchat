defmodule RetroHexChatWeb.Icons.Security do
  @moduledoc """
  Icons depicting security, privacy, and access control concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_lock(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_lock(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <path
        d="M10 14V10C10 6.7 12.7 4 16 4C19.3 4 22 6.7 22 10V14"
        fill="none"
        stroke="#555"
        stroke-width="2"
      />
      <rect x="8" y="14" width="16" height="14" rx="2" fill="#FFD700" stroke="#000" stroke-width="1" />
      <circle cx="16" cy="21" r="2" fill="#000" />
      <rect x="15" y="22" width="2" height="3" fill="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_shield(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_shield(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M8 1L2 4v4c0 3.5 3 6 6 7 3-1 6-3.5 6-7V4z" fill="#000080" />
      <path d="M8 3L4 5.5v3c0 2.5 2 4.5 4 5.2 2-.7 4-2.7 4-5.2v-3z" fill="#fff" />
      <path d="M7 7.5l1.5 2L11 6" fill="none" stroke="#008000" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_security(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_security(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M8 1L2 4v4c0 3.5 3 6 6 7 3-1 6-3.5 6-7V4z" fill="#000080" />
      <path d="M8 3L4 5.5v3c0 2.5 2 4.5 4 5.2 2-.7 4-2.7 4-5.2v-3z" fill="#fff" />
      <rect
        x="6.5"
        y="6"
        width="3"
        height="4"
        rx="0.5"
        fill="#FFD700"
        stroke="#000"
        stroke-width="0.5"
      />
      <path
        d="M7 6.5V5.5C7 4.7 7.4 4 8 4s1 .7 1 1.5V6.5"
        fill="none"
        stroke="#555"
        stroke-width="0.8"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_ban(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_ban(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" fill="none" stroke="#FF0000" stroke-width="1.5" />
      <line x1="4" y1="4" x2="12" y2="12" stroke="#FF0000" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_globe_blocked(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_globe_blocked(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6" fill="none" stroke="#000080" stroke-width="1" />
      <ellipse cx="8" cy="8" rx="3" ry="6" fill="none" stroke="#000080" stroke-width="0.8" />
      <line x1="2" y1="8" x2="14" y2="8" stroke="#000080" stroke-width="0.8" />
      <line x1="3" y1="3" x2="13" y2="13" stroke="#FF0000" stroke-width="2" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_rules(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_rules(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="3" y="1" width="10" height="14" rx="1" fill="#fff" stroke="#000" stroke-width="1" />
      <rect x="5" y="3" width="2" height="2" fill="none" stroke="#000080" stroke-width="1" />
      <line x1="8" y1="4" x2="11" y2="4" stroke="#000080" stroke-width="1" />
      <rect x="5" y="7" width="2" height="2" fill="none" stroke="#000080" stroke-width="1" />
      <line x1="8" y1="8" x2="11" y2="8" stroke="#000080" stroke-width="1" />
      <rect x="5" y="11" width="2" height="2" fill="none" stroke="#000080" stroke-width="1" />
      <line x1="8" y1="12" x2="11" y2="12" stroke="#000080" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_ignore(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_ignore(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="7" cy="5" r="3" fill="#555" />
      <path d="M3 13c0-3 2-4 4-4s4 1 4 4" fill="#555" />
      <circle cx="10" cy="10" r="4" fill="none" stroke="#FF0000" stroke-width="1.5" />
      <line x1="7.5" y1="7.5" x2="12.5" y2="12.5" stroke="#FF0000" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_modes(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_modes(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M10 6V4.5C10 3.1 9.1 2 8 2S6 3.1 6 4.5V6"
        fill="none"
        stroke="#000080"
        stroke-width="1.2"
      />
      <rect x="5" y="6" width="6" height="7" rx="1" fill="#000080" />
      <circle cx="8" cy="9.5" r="1" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_bans(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_bans(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6" fill="none" stroke="#FF0000" stroke-width="1.5" />
      <line x1="4" y1="4" x2="12" y2="12" stroke="#FF0000" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_exceptions(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_exceptions(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M8 1L2 4v4c0 3.5 3 6 6 7 3-1 6-3.5 6-7V4z" fill="#000080" />
      <path d="M7 7.5l1.5 2L11 6" fill="none" stroke="#fff" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_privacy(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_privacy(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M8 1L2 4v4c0 3.5 3 6 6 7 3-1 6-3.5 6-7V4z" fill="#000080" />
      <path d="M8 3L4 5.5v3c0 2.5 2 4.5 4 5.2 2-.7 4-2.7 4-5.2v-3z" fill="#fff" />
      <rect
        x="6.5"
        y="6"
        width="3"
        height="4"
        rx="0.5"
        fill="#FFD700"
        stroke="#000"
        stroke-width="0.5"
      />
      <path
        d="M7 6.5V5.5C7 4.7 7.4 4 8 4s1 .7 1 1.5V6.5"
        fill="none"
        stroke="#555"
        stroke-width="0.8"
      />
    </svg>
    """
  end
end
