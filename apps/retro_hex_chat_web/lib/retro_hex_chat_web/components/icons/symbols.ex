defmodule RetroHexChatWeb.Icons.Symbols do
  @moduledoc """
  Icons depicting abstract symbols, currency, and miscellaneous concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_dollar(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dollar(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" fill="#FFD700" stroke="#000" stroke-width="1" />
      <text
        x="8"
        y="12"
        text-anchor="middle"
        font-size="10"
        font-weight="bold"
        font-family="sans-serif"
        fill="#000"
      >
        $
      </text>
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_star(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_star(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon
        points="8,1 10,6 15,6.5 11,10 12.5,15 8,12 3.5,15 5,10 1,6.5 6,6"
        fill="#FFD700"
        stroke="#000"
        stroke-width="0.5"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_bug(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_bug(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <ellipse cx="8" cy="9" rx="3.5" ry="4.5" fill="#008000" />
      <circle cx="8" cy="5" r="2" fill="#008000" />
      <line x1="4" y1="7" x2="2" y2="5" stroke="#555" stroke-width="1" />
      <line x1="12" y1="7" x2="14" y2="5" stroke="#555" stroke-width="1" />
      <line x1="4.5" y1="10" x2="2" y2="11" stroke="#555" stroke-width="1" />
      <line x1="11.5" y1="10" x2="14" y2="11" stroke="#555" stroke-width="1" />
      <line x1="5" y1="4" x2="4" y2="2" stroke="#555" stroke-width="1" />
      <line x1="11" y1="4" x2="12" y2="2" stroke="#555" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_heart(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_heart(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M8 14s-5-3.5-5-7c0-2 1.5-3.5 3-3.5 1 0 1.7.5 2 1.3.3-.8 1-1.3 2-1.3 1.5 0 3 1.5 3 3.5 0 3.5-5 7-5 7z"
        fill="#FF0000"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_legal(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_legal(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="7" y="2" width="2" height="10" fill="#555" />
      <line x1="3" y1="5" x2="13" y2="5" stroke="#555" stroke-width="1.5" />
      <circle cx="3" cy="7" r="1.5" fill="#FFD700" stroke="#000" stroke-width="0.5" />
      <circle cx="13" cy="7" r="1.5" fill="#FFD700" stroke="#000" stroke-width="0.5" />
      <rect x="5" y="12" width="6" height="2" rx="0.5" fill="#555" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_clock(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_clock(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" fill="#fff" stroke="#000" stroke-width="1" />
      <line x1="8" y1="4" x2="8" y2="8" stroke="#000" stroke-width="1.2" />
      <line x1="8" y1="8" x2="11" y2="10" stroke="#000" stroke-width="1.2" />
      <circle cx="8" cy="8" r="0.8" fill="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_status_signal(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_status_signal(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="2" y="11" width="3" height="4" fill="#000080" />
      <rect x="6.5" y="7" width="3" height="8" fill="#000080" />
      <rect x="11" y="3" width="3" height="12" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_ignore(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_ignore(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6" fill="none" stroke="#555" stroke-width="1.5" />
      <line x1="4" y1="4" x2="12" y2="12" stroke="#555" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_kick(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_kick(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" fill="#FF0000" />
      <text
        x="8"
        y="12"
        text-anchor="middle"
        font-size="10"
        font-weight="bold"
        font-family="sans-serif"
        fill="#fff"
      >
        !
      </text>
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tag(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tag(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M1 1h6.5L15 8.5 8.5 15 1 7.5z" fill="#FFD700" stroke="#000" stroke-width="0.5" />
      <circle cx="4.5" cy="4.5" r="1.5" fill="#fff" stroke="#000" stroke-width="0.5" />
    </svg>
    """
  end
end
