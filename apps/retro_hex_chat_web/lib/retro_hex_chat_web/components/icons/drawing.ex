defmodule RetroHexChatWeb.Icons.Drawing do
  @moduledoc """
  Icons depicting drawing: Hex Paint's tools and the two programs that make
  pictures, Hex Paint and ASCII Art.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_paint_pencil(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_paint_pencil(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <polygon points="11,1 15,5 6,14 2,14 2,10" fill="#ffd700" stroke="#000" />
      <polygon points="2,10 6,14 2,14" fill="#f5deb3" stroke="#000" />
      <rect x="2" y="13" width="1" height="1" fill="#000" />
      <line x1="11" y1="1" x2="15" y2="5" stroke="#ff69b4" stroke-width="2" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_paint_line(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_paint_line(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <line x1="2" y1="14" x2="14" y2="2" stroke="#000" stroke-width="2" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_paint_rect(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_paint_rect(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="2" y="3" width="12" height="10" fill="none" stroke="#000" stroke-width="2" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_paint_rect_fill(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_paint_rect_fill(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="2" y="3" width="12" height="10" fill="#000080" stroke="#000" stroke-width="2" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_paint_ellipse(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_paint_ellipse(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <ellipse cx="8" cy="8" rx="6" ry="5" fill="none" stroke="#000" stroke-width="2" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_paint_ellipse_fill(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_paint_ellipse_fill(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <ellipse cx="8" cy="8" rx="6" ry="5" fill="#000080" stroke="#000" stroke-width="2" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_paint_bucket(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_paint_bucket(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="3,7 8,2 13,7 8,12" fill="#c0c0c0" stroke="#000" />
      <path d="M13 7 Q15 10 14 12 Q13 13 13 11 Z" fill="#0000ff" stroke="#000" />
      <line x1="8" y1="2" x2="5" y2="0" stroke="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_paint_eraser(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_paint_eraser(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <polygon points="9,2 15,8 9,14 3,8" fill="#ff7f9f" stroke="#000" />
      <polygon points="3,8 6,11 3,14 1,12 1,10" fill="#fff" stroke="#000" />
      <line x1="1" y1="15" x2="15" y2="15" stroke="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_paint_picker(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_paint_picker(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M9 3 L12 0.5 L15.5 4 L13 7 Z" fill="#555" stroke="#000" />
      <path d="M9.5 5 L11 6.5 L4 13.5 L2.5 14 L2 13.5 L2.5 12 Z" fill="#fff" stroke="#000" />
      <rect x="0" y="14" width="2" height="2" fill="#0000ff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_paint_mirror(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_paint_mirror(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <line x1="8" y1="1" x2="8" y2="15" stroke="#000" stroke-dasharray="2 1" />
      <polygon points="6,4 2,8 6,12" fill="#000080" stroke="#000" />
      <polygon points="10,4 14,8 10,12" fill="#000080" stroke="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_paint_undo(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_paint_undo(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M5 4 L1 7 L5 10 Z" fill="#000" />
      <path d="M4 7 H10 A4 4 0 0 1 10 15 H6" fill="none" stroke="#000" stroke-width="2" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_paint_redo(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_paint_redo(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M11 4 L15 7 L11 10 Z" fill="#000" />
      <path d="M12 7 H6 A4 4 0 0 0 6 15 H10" fill="none" stroke="#000" stroke-width="2" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_paint_zoom_in(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_paint_zoom_in(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="6.5" cy="6.5" r="4.5" fill="#fff" stroke="#000" stroke-width="2" />
      <line x1="10" y1="10" x2="15" y2="15" stroke="#000" stroke-width="2" />
      <line x1="4" y1="6.5" x2="9" y2="6.5" stroke="#000" />
      <line x1="6.5" y1="4" x2="6.5" y2="9" stroke="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_paint_zoom_out(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_paint_zoom_out(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="6.5" cy="6.5" r="4.5" fill="#fff" stroke="#000" stroke-width="2" />
      <line x1="10" y1="10" x2="15" y2="15" stroke="#000" stroke-width="2" />
      <line x1="4" y1="6.5" x2="9" y2="6.5" stroke="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_paint(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_paint(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <path
        d="M16 3 C 7 3 2 9 2 16 C 2 23 8 28 14 28 C 17 28 17 25 15 23 C 13 21 15 19 18 19 L 23 19 C 27 19 30 16 30 12 C 30 7 24 3 16 3 z"
        fill="#000"
        transform="translate(1,1)"
      />
      <path
        d="M16 3 C 7 3 2 9 2 16 C 2 23 8 28 14 28 C 17 28 17 25 15 23 C 13 21 15 19 18 19 L 23 19 C 27 19 30 16 30 12 C 30 7 24 3 16 3 z"
        fill="#c0c0c0"
        stroke="#000"
        stroke-width="1.5"
      />
      <circle cx="9" cy="12" r="2.5" fill="#ff0000" stroke="#000" />
      <circle cx="15" cy="8" r="2.5" fill="#ffff00" stroke="#000" />
      <circle cx="22" cy="9" r="2.5" fill="#00fc00" stroke="#000" />
      <circle cx="9" cy="20" r="2.5" fill="#0000fc" stroke="#000" />
      <line x1="31" y1="1" x2="20" y2="24" stroke="#7f0000" stroke-width="2.5" />
      <path d="M20 24 L18 30 L22 26 Z" fill="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_ascii_art(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_ascii_art(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <rect x="3" y="4" width="26" height="19" fill="#000" transform="translate(1,1)" />
      <rect x="3" y="4" width="26" height="19" fill="#000" stroke="#c0c0c0" stroke-width="1.5" />
      <rect x="7" y="8" width="3" height="11" fill="#00fc00" />
      <rect x="10" y="8" width="5" height="3" fill="#00fc00" />
      <rect x="15" y="8" width="3" height="11" fill="#00fc00" />
      <rect x="10" y="13" width="5" height="3" fill="#00fc00" />
      <rect x="20" y="8" width="3" height="3" fill="#ffff00" />
      <rect x="23" y="11" width="3" height="3" fill="#ff00ff" />
      <rect x="20" y="14" width="3" height="3" fill="#00ffff" />
      <rect x="23" y="17" width="3" height="2" fill="#ff0000" />
      <rect x="11" y="24" width="10" height="3" fill="#c0c0c0" stroke="#000" />
      <rect x="7" y="27" width="18" height="2" fill="#808080" stroke="#000" />
    </svg>
    """
  end
end
