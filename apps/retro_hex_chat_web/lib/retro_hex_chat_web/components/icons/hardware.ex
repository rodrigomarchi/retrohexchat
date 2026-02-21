defmodule RetroHexChatWeb.Icons.Hardware do
  @moduledoc """
  Icons depicting hardware, infrastructure, and technology platforms.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_laptop(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_laptop(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect
        x="3"
        y="2"
        width="10"
        height="8"
        rx="0.5"
        fill="#000080"
        stroke="#000"
        stroke-width="1"
      />
      <rect x="4" y="3" width="8" height="6" fill="#008080" />
      <path d="M1 12h14l-1 2H2z" fill="#fff" stroke="#555" stroke-width="0.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_server(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_server(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="2" y="2" width="12" height="5" rx="1" fill="#000080" stroke="#000" stroke-width="0.5" />
      <circle cx="12" cy="4.5" r="1" fill="#008000" />
      <rect x="4" y="3.5" width="4" height="1" fill="#C0C0C0" />
      <rect x="2" y="9" width="12" height="5" rx="1" fill="#000080" stroke="#000" stroke-width="0.5" />
      <circle cx="12" cy="11.5" r="1" fill="#008000" />
      <rect x="4" y="10.5" width="4" height="1" fill="#C0C0C0" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_database(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_database(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <ellipse cx="8" cy="4" rx="5" ry="2.5" fill="#000080" />
      <rect x="3" y="4" width="10" height="8" fill="#000080" />
      <ellipse cx="8" cy="12" rx="5" ry="2.5" fill="#000080" />
      <ellipse cx="8" cy="4" rx="5" ry="2.5" fill="#008080" />
      <ellipse cx="8" cy="8" rx="5" ry="2" fill="none" stroke="#008080" stroke-width="0.8" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_elixir(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_elixir(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M8 1C6 4 4 7 4 10c0 3 2 5 4 5s4-2 4-5c0-3-2-6-4-9z" fill="#000080" />
      <path d="M8 3C6.5 5.5 5.5 7.5 5.5 10c0 2 1.2 3.5 2.5 3.5" fill="#008080" opacity="0.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_postgres(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_postgres(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <ellipse cx="8" cy="4" rx="5" ry="2.5" fill="#008080" stroke="#000" stroke-width="0.5" />
      <rect x="3" y="4" width="10" height="8" fill="#008080" />
      <ellipse cx="8" cy="12" rx="5" ry="2.5" fill="#008080" stroke="#000" stroke-width="0.5" />
      <ellipse cx="8" cy="4" rx="5" ry="2.5" fill="#008080" stroke="#000" stroke-width="0.5" />
      <ellipse cx="8" cy="8" rx="5" ry="2" fill="none" stroke="#000" stroke-width="0.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_display(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_display(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="2" y="2" width="12" height="9" rx="1" fill="#000080" stroke="#000" stroke-width="0.5" />
      <rect x="3" y="3" width="10" height="7" fill="#008080" />
      <rect x="6" y="11" width="4" height="1" fill="#000080" />
      <rect x="5" y="12" width="6" height="1" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_channel_list(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_channel_list(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <text
        x="2"
        y="7"
        font-size="7"
        font-weight="bold"
        font-family="sans-serif"
        fill="#fff"
      >
        #
      </text>
      <line x1="7" y1="4" x2="14" y2="4" stroke="#fff" stroke-width="1" />
      <line x1="7" y1="7" x2="14" y2="7" stroke="#fff" stroke-width="1" />
      <line x1="2" y1="10" x2="14" y2="10" stroke="#fff" stroke-width="1" />
      <line x1="2" y1="13" x2="14" y2="13" stroke="#fff" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_channel_central(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_channel_central(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="8,1 2,6 2,14 14,14 14,6" fill="none" stroke="#fff" stroke-width="1" />
      <polygon points="8,1 2,6 14,6" fill="#FF0000" />
      <rect x="6" y="9" width="4" height="5" fill="#fff" />
      <text
        x="8"
        y="7"
        text-anchor="middle"
        font-size="5"
        font-weight="bold"
        font-family="sans-serif"
        fill="#FFD700"
      >
        #
      </text>
    </svg>
    """
  end
end
