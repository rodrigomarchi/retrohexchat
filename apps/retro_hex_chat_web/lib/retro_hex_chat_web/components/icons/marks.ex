defmodule RetroHexChatWeb.Icons.Marks do
  @moduledoc """
  Icons depicting confirmation, cancellation, and status mark concepts.
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  attr :class, :string, default: nil

  @spec icon_btn_add(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_add(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <rect x="3" y="4" width="10" height="10" fill="#555" />
      <!-- Square Body -->
      <rect x="2" y="3" width="10" height="10" fill="#008000" stroke="#000" stroke-width="1" />
      <!-- Inner Plus -->
      <rect x="6" y="5" width="2" height="6" fill="#fff" />
      <rect x="4" y="7" width="6" height="2" fill="#fff" />
      <!-- Highlight -->
      <line x1="3" y1="4" x2="11" y2="4" stroke="#fff" stroke-width="1" />
      <line x1="3" y1="4" x2="3" y2="12" stroke="#fff" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_remove(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_remove(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <rect x="3" y="4" width="10" height="10" fill="#555" />
      <!-- Square Body -->
      <rect x="2" y="3" width="10" height="10" fill="#FF0000" stroke="#000" stroke-width="1" />
      <!-- Inner Cross (Diagonal) -->
      <polygon points="5,4 7,4 7,12 5,12" fill="#fff" transform="rotate(45 7 8)" />
      <polygon points="5,4 7,4 7,12 5,12" fill="#fff" transform="rotate(-45 7 8)" />
      <!-- Since crispEdges + rotation is often ugly, let's draw the cross via pixel coords instead -->
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_ok(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_ok(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <polygon points="4,10 7,13 14,6 14,8 7,15 4,12" fill="#555" />
      <!-- Checkmark pure stroke, sharp -->
      <path d="M4 9 L7 12 L13 5" fill="none" stroke="#000" stroke-width="3" />
      <path d="M4 9 L7 12 L13 5" fill="none" stroke="#00FF00" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_cancel(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_cancel(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <path d="M4 4 L12 12 M12 4 L4 12" fill="none" stroke="#000" stroke-width="3" />
      <path d="M4 4 L12 12 M12 4 L4 12" fill="none" stroke="#FF0000" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_mark_read(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_mark_read(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <path d="M2 9 L5 12 L10 6" fill="none" stroke="#000" stroke-width="3" />
      <path d="M2 9 L5 12 L10 6" fill="none" stroke="#000080" stroke-width="1.5" />

      <path d="M7 9 L10 12 L15 6" fill="none" stroke="#000" stroke-width="3" />
      <path d="M7 9 L10 12 L15 6" fill="none" stroke="#000080" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_accept(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_accept(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <path
        d="M7 16 L 14 23 L 27 9"
        fill="none"
        stroke="#000"
        stroke-width="6"
        stroke-linecap="square"
        stroke-linejoin="miter"
        transform="translate(1, 1)"
      />
      <!-- Green Check -->
      <path
        d="M7 16 L 14 23 L 27 9"
        fill="none"
        stroke="#008000"
        stroke-width="6"
        stroke-linecap="square"
        stroke-linejoin="miter"
      />
      <path
        d="M8 15 L 14 21 L 26 8"
        fill="none"
        stroke="#00FF00"
        stroke-width="2"
        stroke-linecap="square"
        stroke-linejoin="miter"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_reject(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_reject(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <path
        d="M8 8 L 24 24 M 24 8 L 8 24"
        fill="none"
        stroke="#000"
        stroke-width="6"
        stroke-linecap="square"
        transform="translate(1, 1)"
      />
      <!-- Red Cross -->
      <path
        d="M8 8 L 24 24 M 24 8 L 8 24"
        fill="none"
        stroke="#FF0000"
        stroke-width="6"
        stroke-linecap="square"
      />
      <!-- Bevel Highlight -->
      <path
        d="M9 7 L 25 23 M 23 7 L 7 23"
        fill="none"
        stroke="#FF8080"
        stroke-width="2"
        stroke-linecap="square"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_close(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_close(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Flat bold X -->
      <path
        d="M8 8 L 24 24 M 24 8 L 8 24"
        fill="none"
        stroke="#000"
        stroke-width="5"
        stroke-linecap="square"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_cancel(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_cancel(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <circle cx="17" cy="17" r="13" fill="#000" />
      <!-- Red Circle -->
      <circle cx="16" cy="16" r="13" fill="#fff" stroke="#FF0000" stroke-width="3" />
      <!-- X -->
      <path
        d="M10 10 L 22 22 M 22 10 L 10 22"
        fill="none"
        stroke="#FF0000"
        stroke-width="4"
        stroke-linecap="square"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_checkmark(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_checkmark(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Green Check mark without shadow -->
      <path
        d="M7 16 L 14 23 L 27 9"
        fill="none"
        stroke="#008000"
        stroke-width="5"
        stroke-linecap="square"
        stroke-linejoin="miter"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_warning(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_warning(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <polygon points="17,3 30,27 4,27" fill="#000" />
      <!-- Base Triangle -->
      <polygon
        points="16,2 29,26 3,26"
        fill="#FFD700"
        stroke="#000"
        stroke-width="2"
        stroke-linejoin="round"
      />
      <!-- Bevel -->
      <polygon points="16,5 27,25 5,25" fill="none" stroke="#fff" stroke-width="1.5" />
      <!-- Exclamation -->
      <rect x="14.5" y="10" width="3" height="8" fill="#000" />
      <circle cx="16" cy="22" r="1.5" fill="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_ellipsis(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_ellipsis(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="3" y="7" width="2" height="2" fill="#000" />
      <rect x="7" y="7" width="2" height="2" fill="#000" />
      <rect x="11" y="7" width="2" height="2" fill="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_radio_dot(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_radio_dot(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="6" y="6" width="4" height="4" fill="#000" />
      <rect x="7" y="5" width="2" height="1" fill="#000" />
      <rect x="7" y="10" width="2" height="1" fill="#000" />
      <rect x="5" y="7" width="1" height="2" fill="#000" />
      <rect x="10" y="7" width="1" height="2" fill="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_check_thin(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_check_thin(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <path d="M4 9 L7 12 L13 5" fill="none" stroke="#000" stroke-width="2" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_close_pixel(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_close_pixel(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 8 7" shape-rendering="crispEdges" aria-hidden="true">
      <path d="M0 0L1 0L4 3L7 0L8 0L8 1L5 4L8 7L7 7L4 4L1 7L0 7L3 4L0 1Z" fill="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_close_thin(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_close_thin(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <path d="M4 4 L12 12 M12 4 L4 12" fill="none" stroke="#000" stroke-width="2" />
    </svg>
    """
  end

  @doc "Win98 window minimize control — 6×2 horizontal line at bottom."
  attr :class, :string, default: nil

  @spec icon_win_minimize(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_win_minimize(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 6 2" shape-rendering="crispEdges" aria-hidden="true">
      <path fill="#000" d="M0 0h6v2H0z" />
    </svg>
    """
  end

  @doc "Win98 window maximize control — 9×9 square outline."
  attr :class, :string, default: nil

  @spec icon_win_maximize(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_win_maximize(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 9 9" shape-rendering="crispEdges" aria-hidden="true">
      <path
        fill-rule="evenodd"
        clip-rule="evenodd"
        d="M9 0H0v9h9V0zM8 2H1v6h7V2z"
        fill="#000"
      />
    </svg>
    """
  end

  @doc "Win98 window restore control — overlapping windows."
  attr :class, :string, default: nil

  @spec icon_win_restore(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_win_restore(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 8 9" shape-rendering="crispEdges" aria-hidden="true">
      <path
        fill="#000"
        d="M2 0h6v2H2zM7 2h1v4H7zM2 2h1v1H2zM6 5h1v1H6zM0 3h6v2H0zM5 5h1v4H5zM0 5h1v4H0zM1 8h4v1H1z"
      />
    </svg>
    """
  end

  @doc "Win98 window help control — question mark."
  attr :class, :string, default: nil

  @spec icon_win_help(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_win_help(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 6 9" shape-rendering="crispEdges" aria-hidden="true">
      <path fill="#000" d="M0 1h2v2H0zM1 0h4v1H1zM4 1h2v2H4zM3 3h2v1H3zM2 4h2v2H2zM2 7h2v2H2z" />
    </svg>
    """
  end
end
