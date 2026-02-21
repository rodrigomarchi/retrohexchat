defmodule RetroHexChatWeb.Icons.Marks do
  @moduledoc """
  Icons depicting confirmation, cancellation, and status mark concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_btn_add(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_add(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6" fill="#008000" />
      <line x1="8" y1="5" x2="8" y2="11" stroke="#fff" stroke-width="2" stroke-linecap="round" />
      <line x1="5" y1="8" x2="11" y2="8" stroke="#fff" stroke-width="2" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_remove(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_remove(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6" fill="#FF0000" />
      <line x1="5" y1="5" x2="11" y2="11" stroke="#fff" stroke-width="2" stroke-linecap="round" />
      <line x1="11" y1="5" x2="5" y2="11" stroke="#fff" stroke-width="2" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_ok(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_ok(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M3 8l3.5 4L13 4"
        fill="none"
        stroke="#008000"
        stroke-width="2.5"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_cancel(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_cancel(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <line x1="4" y1="4" x2="12" y2="12" stroke="#808080" stroke-width="2" stroke-linecap="round" />
      <line x1="12" y1="4" x2="4" y2="12" stroke="#808080" stroke-width="2" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_mark_read(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_mark_read(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M1 8l3.5 4L11 4"
        fill="none"
        stroke="#000080"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
      <path
        d="M5 8l3.5 4L15 4"
        fill="none"
        stroke="#000080"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_accept(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_accept(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M3 8l3.5 4L13 4"
        fill="none"
        stroke="#008000"
        stroke-width="2.5"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_reject(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_reject(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <line x1="4" y1="4" x2="12" y2="12" stroke="#FF0000" stroke-width="2.5" stroke-linecap="round" />
      <line x1="12" y1="4" x2="4" y2="12" stroke="#FF0000" stroke-width="2.5" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_close(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_close(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <line x1="4" y1="4" x2="12" y2="12" stroke="#000" stroke-width="2" stroke-linecap="round" />
      <line x1="12" y1="4" x2="4" y2="12" stroke="#000" stroke-width="2" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_cancel(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_cancel(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" fill="none" stroke="#FF0000" stroke-width="1.2" />
      <line x1="5" y1="5" x2="11" y2="11" stroke="#FF0000" stroke-width="1.5" />
      <line x1="11" y1="5" x2="5" y2="11" stroke="#FF0000" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_checkmark(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_checkmark(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M3 8l3.5 4L13 4"
        fill="none"
        stroke="#008000"
        stroke-width="2.5"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_warning(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_warning(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="8,1 15,14 1,14" fill="#FFD700" stroke="#000" stroke-width="0.8" />
      <text
        x="8"
        y="13"
        text-anchor="middle"
        font-size="9"
        font-weight="bold"
        font-family="sans-serif"
        fill="#000"
      >
        !
      </text>
    </svg>
    """
  end
end
