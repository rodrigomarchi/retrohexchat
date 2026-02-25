defmodule RetroHexChatWeb.Icons.Formatting do
  @moduledoc """
  Icons for text formatting toolbar controls (bold, italic, underline, etc.).
  All icons use a 14×14 viewBox and `fill="currentColor"` for theme inheritance.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_fmt_bold(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_fmt_bold(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" fill="currentColor" aria-hidden="true">
      <path d="M3 1h5a3 3 0 0 1 2.1 5.1A3.5 3.5 0 0 1 8.5 13H3V1zm2 5h3a1 1 0 1 0 0-2H5v2zm0 2v3h3.5a1.5 1.5 0 0 0 0-3H5z" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_fmt_italic(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_fmt_italic(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" fill="currentColor" aria-hidden="true">
      <path d="M5 1h6v2H9.2L7.3 11H9v2H3v-2h1.8L6.7 3H5V1z" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_fmt_underline(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_fmt_underline(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" fill="currentColor" aria-hidden="true">
      <path d="M3 1v5.5a4 4 0 0 0 8 0V1h-2v5.5a2 2 0 0 1-4 0V1H3zm-1 11h10v2H2v-2z" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_fmt_color(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_fmt_color(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" fill="currentColor" aria-hidden="true">
      <rect x="1" y="1" width="4" height="4" fill="#ff0000" />
      <rect x="5" y="1" width="4" height="4" fill="#00ff00" />
      <rect x="9" y="1" width="4" height="4" fill="#0000ff" />
      <rect x="1" y="5" width="4" height="4" fill="#ffff00" />
      <rect x="5" y="5" width="4" height="4" fill="#ff00ff" />
      <rect x="9" y="5" width="4" height="4" fill="#00ffff" />
      <rect x="1" y="9" width="12" height="4" fill="#555" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_fmt_reverse(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_fmt_reverse(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" fill="currentColor" aria-hidden="true">
      <rect x="1" y="1" width="6" height="12" fill="#000" />
      <rect x="7" y="1" width="6" height="12" fill="#fff" stroke="#555" stroke-width="0.5" />
      <text
        x="4"
        y="10.5"
        text-anchor="middle"
        font-size="8"
        font-weight="bold"
        font-family="sans-serif"
        fill="#fff"
      >
        R
      </text>
      <text
        x="10"
        y="10.5"
        text-anchor="middle"
        font-size="8"
        font-weight="bold"
        font-family="sans-serif"
        fill="#000"
      >
        R
      </text>
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_fmt_reset(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_fmt_reset(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" fill="currentColor" aria-hidden="true">
      <text
        x="7"
        y="10"
        text-anchor="middle"
        font-size="9"
        font-weight="bold"
        font-family="sans-serif"
        fill="#555"
      >
        Aa
      </text>
      <line x1="2" y1="2" x2="12" y2="12" stroke="#FF0000" stroke-width="2" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_fmt_strip(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_fmt_strip(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" fill="currentColor" aria-hidden="true">
      <circle cx="7" cy="7" r="6" fill="none" stroke="currentColor" stroke-width="1.5" />
      <line x1="3" y1="11" x2="11" y2="3" stroke="currentColor" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_fmt_emoji(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_fmt_emoji(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" fill="currentColor" aria-hidden="true">
      <circle cx="7" cy="7" r="6" fill="none" stroke="currentColor" stroke-width="1.5" />
      <circle cx="5" cy="5.5" r="0.8" />
      <circle cx="9" cy="5.5" r="0.8" />
      <path d="M4.5 8.5 Q7 11 9.5 8.5" fill="none" stroke="currentColor" stroke-width="1" />
    </svg>
    """
  end
end
