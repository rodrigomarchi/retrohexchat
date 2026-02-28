defmodule RetroHexChatWeb.Icons.Arrows do
  @moduledoc """
  Icons depicting directional arrows, navigation, and flow concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_btn_prev(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_prev(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <polygon points="11,5 7,9 11,13" fill="#555" />
      <!-- Arrow -->
      <polygon points="10,4 6,8 10,12" fill="#000080" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_next(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_next(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <polygon points="7,5 11,9 7,13" fill="#555" />
      <!-- Arrow -->
      <polygon points="6,4 10,8 6,12" fill="#000080" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_up(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_up(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <polygon points="5,11 9,7 13,11" fill="#555" />
      <!-- Arrow -->
      <polygon points="4,10 8,6 12,10" fill="#000080" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_down(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_down(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <polygon points="5,7 9,13 13,7" fill="#555" />
      <!-- Arrow -->
      <polygon points="4,6 8,12 12,6" fill="#000080" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_refresh(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_refresh(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Outer outline -->
      <path d="M11 5 V3 H4 V12 H9" fill="none" stroke="#000" stroke-width="3" />
      <!-- Inner navy -->
      <path d="M11 5 V3 H4 V12 H9" fill="none" stroke="#000080" stroke-width="1" />
      <polyline points="5,4 10,4" stroke="#fff" stroke-width="1" />
      <!-- Arrow head 1 -->
      <polygon points="9,5 11,8 13,5" fill="#000080" stroke="#000" stroke-width="1" />
      <!-- Arrow head 2 -->
      <polygon points="10,12 7,14 7,10" fill="#000080" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_export(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_export(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Box -->
      <rect x="3" y="9" width="10" height="5" fill="#C0C0C0" stroke="#000" stroke-width="1" />
      <line x1="4" y1="10" x2="12" y2="10" stroke="#fff" stroke-width="1" />
      <!-- Arrow UP -->
      <rect x="7" y="5" width="2" height="5" fill="#000080" stroke="#000" stroke-width="1" />
      <polygon points="5,5 8,2 11,5" fill="#000080" stroke="#000" stroke-width="1" />
      <polyline points="6,5 8,3 9,4" fill="none" stroke="#fff" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_reset(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_reset(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- U turn arrow -->
      <path d="M12 9 V5 H5" fill="none" stroke="#000" stroke-width="3" />
      <path d="M12 9 V5 H5" fill="none" stroke="#808080" stroke-width="1" />
      <polygon points="7,3 4,5 7,7" fill="#808080" stroke="#000" stroke-width="1" />
      <line x1="5" y1="4" x2="5" y2="6" stroke="#fff" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_join(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_join(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <polygon points="7,5 11,9 7,13" fill="#555" />
      <!-- Arrow -->
      <polygon points="6,4 10,8 6,12" fill="#008000" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_send(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_send(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <polygon points="3,3 15,9 3,15 5,9" fill="#555" />
      <!-- Main Plane -->
      <polygon points="2,2 14,8 2,14 4,8" fill="#000080" stroke="#000" stroke-width="1" />
      <polyline points="3,4 12,8 4,8" stroke="#fff" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_retry(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_retry(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <path
        d="M6 16 A 10 10 0 0 1 24 10"
        fill="none"
        stroke="#000"
        stroke-width="5"
        transform="translate(1,1)"
        stroke-linecap="round"
      />
      <polygon points="24,6 28,10 20,10" fill="#000" transform="translate(1,1)" />

      <path
        d="M26 16 A 10 10 0 0 1 8 22"
        fill="none"
        stroke="#000"
        stroke-width="5"
        transform="translate(1,1)"
        stroke-linecap="round"
      />
      <polygon points="8,26 4,22 12,22" fill="#000" transform="translate(1,1)" />
      
    <!-- Blue Arrows -->
      <path
        d="M6 16 A 10 10 0 0 1 24 10"
        fill="none"
        stroke="#000080"
        stroke-width="5"
        stroke-linecap="round"
      />
      <path
        d="M7 16 A 9 9 0 0 1 23 10"
        fill="none"
        stroke="#8080FF"
        stroke-width="1"
        stroke-linecap="round"
      />
      <polygon
        points="24,4 30,12 18,12"
        fill="#000080"
        stroke="#000080"
        stroke-width="1"
        stroke-linejoin="round"
      />
      <polygon points="24,7 27,11 21,11" fill="#8080FF" />

      <path
        d="M26 16 A 10 10 0 0 1 8 22"
        fill="none"
        stroke="#000080"
        stroke-width="5"
        stroke-linecap="round"
      />
      <path
        d="M25 16 A 9 9 0 0 1 9 22"
        fill="none"
        stroke="#8080FF"
        stroke-width="1"
        stroke-linecap="round"
      />
      <polygon
        points="8,28 2,20 14,20"
        fill="#000080"
        stroke="#000080"
        stroke-width="1"
        stroke-linejoin="round"
      />
      <polygon points="8,25 5,21 11,21" fill="#8080FF" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_chevron_down(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_chevron_down(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <polygon points="4,6 8,10 12,6 12,8 8,12 4,8" fill="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_chevron_right(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_chevron_right(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <polygon points="6,4 10,8 6,12 8,12 12,8 8,4" fill="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_chevron_left(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_chevron_left(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <polygon points="10,4 6,8 10,12 8,12 4,8 8,4" fill="#000" />
    </svg>
    """
  end
end
