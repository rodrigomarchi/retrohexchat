defmodule RetroHexChatWeb.Icons.Arrows do
  @moduledoc """
  Icons depicting directional arrows, navigation, and flow concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_btn_prev(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_prev(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="10,3 4,8 10,13" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_next(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_next(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="6,3 12,8 6,13" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_up(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_up(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="3,10 8,4 13,10" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_down(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_down(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="3,6 8,12 13,6" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_refresh(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_refresh(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M3 8a5 5 0 0 1 9-3" fill="none" stroke="#000080" stroke-width="1.5" />
      <polygon points="12,3 14,5 10,5" fill="#000080" />
      <path d="M13 8a5 5 0 0 1-9 3" fill="none" stroke="#000080" stroke-width="1.5" />
      <polygon points="4,13 2,11 6,11" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_export(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_export(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="3" y="6" width="10" height="8" rx="1" fill="none" stroke="#000080" stroke-width="1.2" />
      <line x1="8" y1="2" x2="8" y2="9" stroke="#000080" stroke-width="1.5" />
      <polygon points="5,5 8,1.5 11,5" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_reset(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_reset(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M4 8a4.5 4.5 0 1 1 1 3" fill="none" stroke="#555" stroke-width="1.5" />
      <polygon points="2,9 5,11 5,7" fill="#555" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_join(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_join(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="4,3 12,8 4,13" fill="#008000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_send(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_send(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="2,2 14,8 2,14 4,8" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_retry(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_retry(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M3 8a5 5 0 0 1 9-3" fill="none" stroke="#000080" stroke-width="1.5" />
      <polygon points="12,3 14,5 10,5" fill="#000080" />
      <path d="M13 8a5 5 0 0 1-9 3" fill="none" stroke="#000080" stroke-width="1.5" />
      <polygon points="4,13 2,11 6,11" fill="#000080" />
    </svg>
    """
  end
end
