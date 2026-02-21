defmodule RetroHexChatWeb.Icons.Code do
  @moduledoc """
  Icons depicting programming, scripting, and automation concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_terminal(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_terminal(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="1" y="2" width="14" height="12" rx="1" fill="#000" stroke="#808080" stroke-width="1" />
      <text x="3" y="10" font-size="7" font-family="monospace" fill="#0f0">
        &gt;_
      </text>
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_git(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_git(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="4" r="2" fill="#FF0000" />
      <circle cx="4" cy="12" r="2" fill="#008000" />
      <circle cx="12" cy="12" r="2" fill="#000080" />
      <line x1="8" y1="6" x2="5" y2="10" stroke="#555" stroke-width="1.5" />
      <line x1="8" y1="6" x2="11" y2="10" stroke="#555" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_code(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_code(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M5 4L1 8l4 4" fill="none" stroke="#000080" stroke-width="1.5" stroke-linecap="round" />
      <path d="M11 4l4 4-4 4" fill="none" stroke="#000080" stroke-width="1.5" stroke-linecap="round" />
      <line x1="9" y1="2" x2="7" y2="14" stroke="#555" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_alias(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_alias(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <text
        x="2"
        y="11"
        font-size="10"
        font-weight="bold"
        font-family="sans-serif"
        fill="#fff"
      >
        A=
      </text>
      <line x1="11" y1="13" x2="14" y2="3" stroke="#FFD700" stroke-width="1.5" stroke-linecap="round" />
      <line
        x1="11"
        y1="13"
        x2="13"
        y2="11"
        stroke="#FFD700"
        stroke-width="1.5"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_ctcp(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_ctcp(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M3 5h4M5 3v4"
        fill="none"
        stroke="#fff"
        stroke-width="1.5"
        stroke-linecap="round"
      />
      <path
        d="M9 9h4M11 7v4"
        fill="none"
        stroke="#fff"
        stroke-width="1.5"
        stroke-linecap="round"
      />
      <path d="M7 6l2 4" fill="none" stroke="#FFD700" stroke-width="1.2" stroke-linecap="round" />
      <polygon points="10,9 8.5,10.5 10,10.5" fill="#FFD700" />
      <polygon points="7,7 8.5,5.5 7,5.5" fill="#FFD700" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_auto_respond(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_auto_respond(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M1 2h10v7H5l-3 2v-2H1z" fill="none" stroke="#fff" stroke-width="1" />
      <path
        d="M11 8h2v2l1.5-1.5"
        fill="none"
        stroke="#FFD700"
        stroke-width="1.2"
        stroke-linecap="round"
      />
      <polygon points="14,6 14,10 15.5,8.5" fill="#FFD700" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_perform(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_perform(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="2,2 2,12 9,7" fill="#fff" />
      <circle cx="12" cy="11" r="3.5" fill="none" stroke="#fff" stroke-width="1" />
      <circle cx="12" cy="11" r="1.2" fill="#fff" />
      <line x1="12" y1="7.5" x2="12" y2="8.5" stroke="#fff" stroke-width="1" />
      <line x1="12" y1="13.5" x2="12" y2="14.5" stroke="#fff" stroke-width="1" />
      <line x1="8.5" y1="11" x2="9.5" y2="11" stroke="#fff" stroke-width="1" />
      <line x1="14.5" y1="11" x2="15.5" y2="11" stroke="#fff" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_commands(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_commands(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="1" y="2" width="14" height="12" rx="1" fill="#000080" stroke="#000" stroke-width="0.5" />
      <text x="3" y="10" font-size="7" font-family="monospace" fill="#fff">
        &gt;_
      </text>
    </svg>
    """
  end
end
