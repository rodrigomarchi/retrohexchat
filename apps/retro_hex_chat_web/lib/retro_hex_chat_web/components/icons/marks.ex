defmodule RetroHexChatWeb.Icons.Marks do
  @moduledoc """
  Icons depicting confirmation, cancellation, and status mark concepts.
  """
  use Phoenix.Component

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
end
