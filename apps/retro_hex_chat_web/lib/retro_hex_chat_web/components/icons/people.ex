defmodule RetroHexChatWeb.Icons.People do
  @moduledoc """
  Icons depicting people, users, and social concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_community(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_community(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="5" cy="4" r="2" fill="#000080" />
      <path d="M2 9c0-2 1.5-3 3-3s3 1 3 3" fill="#000080" />
      <circle cx="11" cy="4" r="2" fill="#008080" />
      <path d="M8 9c0-2 1.5-3 3-3s3 1 3 3" fill="#008080" />
      <circle cx="8" cy="10" r="2" fill="#555" />
      <path d="M5 15c0-2 1.5-3 3-3s3 1 3 3" fill="#555" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_connect(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_connect(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" fill="#008000" />
      <polygon points="6,4 6,12 13,8" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_robot(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_robot(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="4" y="5" width="8" height="8" rx="1" fill="#fff" stroke="#555" stroke-width="1" />
      <rect x="5" y="7" width="2" height="2" fill="#FF0000" />
      <rect x="9" y="7" width="2" height="2" fill="#FF0000" />
      <rect x="6" y="10" width="4" height="1" fill="#555" />
      <line x1="8" y1="3" x2="8" y2="5" stroke="#555" stroke-width="1" />
      <circle cx="8" cy="2.5" r="1" fill="#FF0000" />
      <line x1="3" y1="8" x2="4" y2="8" stroke="#555" stroke-width="1.5" />
      <line x1="12" y1="8" x2="13" y2="8" stroke="#555" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_address_book(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_address_book(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="3" y="1" width="10" height="14" rx="1" fill="none" stroke="#fff" stroke-width="1" />
      <rect x="1" y="3" width="3" height="2" rx="0.5" fill="#FFD700" />
      <rect x="1" y="7" width="3" height="2" rx="0.5" fill="#FFD700" />
      <rect x="1" y="11" width="3" height="2" rx="0.5" fill="#FFD700" />
      <line x1="6" y1="5" x2="11" y2="5" stroke="#fff" stroke-width="0.8" />
      <line x1="6" y1="8" x2="11" y2="8" stroke="#fff" stroke-width="0.8" />
      <line x1="6" y1="11" x2="11" y2="11" stroke="#fff" stroke-width="0.8" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_nick(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_nick(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="6" cy="5" r="3" fill="#fff" />
      <path d="M2 13c0-3 2-4 4-4s4 1 4 4" fill="#fff" />
      <path
        d="M12 4v5M10 6.5h4"
        fill="none"
        stroke="#FFD700"
        stroke-width="1.5"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_contacts(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_contacts(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="5" r="3" fill="#000080" />
      <path d="M3 14c0-3 2.5-5 5-5s5 2 5 5" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_nicklist(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_nicklist(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="5" r="3" fill="#000080" />
      <path d="M3 14c0-3 2.5-5 5-5s5 2 5 5" fill="#000080" />
    </svg>
    """
  end
end
