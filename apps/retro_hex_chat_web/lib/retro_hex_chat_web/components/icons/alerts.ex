defmodule RetroHexChatWeb.Icons.Alerts do
  @moduledoc """
  Icons depicting notifications, information, and alert concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_document_alert(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_document_alert(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="3" y="1" width="10" height="14" rx="1" fill="#fff" stroke="#000" stroke-width="1" />
      <line x1="5" y1="4" x2="11" y2="4" stroke="#000080" stroke-width="1" />
      <line x1="5" y1="6" x2="11" y2="6" stroke="#000080" stroke-width="1" />
      <line x1="5" y1="8" x2="9" y2="8" stroke="#000080" stroke-width="1" />
      <circle cx="11" cy="11" r="3" fill="#FFD700" stroke="#000" stroke-width="0.5" />
      <text
        x="11"
        y="13"
        text-anchor="middle"
        font-size="5"
        font-weight="bold"
        font-family="sans-serif"
        fill="#000"
      >
        !
      </text>
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_question(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_question(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="7" fill="#000080" />
      <text
        x="8"
        y="12"
        text-anchor="middle"
        font-size="11"
        font-weight="bold"
        font-family="sans-serif"
        fill="#fff"
      >
        ?
      </text>
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_about(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_about(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" fill="none" stroke="#fff" stroke-width="1.2" />
      <text
        x="8"
        y="12"
        text-anchor="middle"
        font-size="10"
        font-weight="bold"
        font-family="serif"
        fill="#fff"
      >
        i
      </text>
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_notifications(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_notifications(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M8 1C5 1 4 3.5 4 6v3l-2 2v1h12v-1l-2-2V6c0-2.5-1-5-4-5z"
        fill="#fff"
      />
      <circle cx="8" cy="14" r="1.5" fill="#FFD700" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_highlight(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_highlight(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <line x1="2" y1="3" x2="14" y2="3" stroke="#fff" stroke-width="1" />
      <line x1="2" y1="6" x2="14" y2="6" stroke="#fff" stroke-width="1" />
      <rect x="2" y="8" width="12" height="3" rx="0.5" fill="#FFD700" opacity="0.7" />
      <line x1="2" y1="9.5" x2="14" y2="9.5" stroke="#fff" stroke-width="1" />
      <line x1="2" y1="13" x2="10" y2="13" stroke="#fff" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_flood(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_flood(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M8 1L2 4v4c0 3.5 3 6 6 7 3-1 6-3.5 6-7V4z" fill="none" stroke="#fff" stroke-width="1" />
      <text
        x="8"
        y="12"
        text-anchor="middle"
        font-size="8"
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

  @spec icon_tab_general(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_general(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" fill="none" stroke="#000080" stroke-width="1.2" />
      <text
        x="8"
        y="12"
        text-anchor="middle"
        font-size="10"
        font-weight="bold"
        font-family="serif"
        fill="#000080"
      >
        i
      </text>
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_notify(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_notify(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M8 1C5 1 4 3.5 4 6v3l-2 2v1h12v-1l-2-2V6c0-2.5-1-5-4-5z" fill="#000080" />
      <circle cx="8" cy="14" r="1.5" fill="#FFD700" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_notifications(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_notifications(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M8 1C5 1 4 3.5 4 6v3l-2 2v1h12v-1l-2-2V6c0-2.5-1-5-4-5z" fill="#000080" />
      <circle cx="8" cy="14" r="1.5" fill="#FFD700" />
    </svg>
    """
  end
end
