defmodule RetroHexChatWeb.Icons.Tools do
  @moduledoc """
  Icons depicting configuration, editing, and customization concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_wrench(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_wrench(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M11 2c-1.5 0-2.8.8-3.5 2L3 8.5 2 10l1.5 1.5 1 1L6 14l1.5-1 4.5-4.5c1.2-.7 2-2 2-3.5 0-.5-.1-1-.2-1.5L12 5.5 10.5 4l2-1.8C12 2.1 11.5 2 11 2z"
        fill="#555"
        stroke="#000"
        stroke-width="0.5"
      />
      <path d="M3.5 10l2.5 2.5" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_palette(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_palette(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" fill="#fff" stroke="#555" stroke-width="1" />
      <circle cx="6" cy="5" r="1.2" fill="#FF0000" />
      <circle cx="9" cy="4.5" r="1.2" fill="#008000" />
      <circle cx="11" cy="7" r="1.2" fill="#000080" />
      <circle cx="5" cy="8" r="1.2" fill="#FFD700" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_edit(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_edit(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M11 2l3 3-8 8H3v-3z" fill="#000080" stroke="#000" stroke-width="0.5" />
      <path d="M10 3l3 3" fill="none" stroke="#fff" stroke-width="0.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_save(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_save(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="2" y="2" width="12" height="12" rx="1" fill="#000080" stroke="#000" stroke-width="0.5" />
      <rect x="4" y="2" width="8" height="5" fill="#C0C0C0" />
      <rect x="8" y="3" width="3" height="3" fill="#000080" />
      <rect x="4" y="9" width="8" height="4" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_apply(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_apply(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="7" cy="8" r="5.5" fill="none" stroke="#000080" stroke-width="1.2" />
      <circle cx="7" cy="8" r="2" fill="#000080" />
      <line x1="7" y1="2" x2="7" y2="4" stroke="#000080" stroke-width="1.2" />
      <line x1="7" y1="12" x2="7" y2="14" stroke="#000080" stroke-width="1.2" />
      <path
        d="M11 10l1.5 2L15 8"
        fill="none"
        stroke="#008000"
        stroke-width="1.5"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_search(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_search(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="7" cy="7" r="4.5" fill="none" stroke="#000080" stroke-width="1.5" />
      <line x1="10" y1="10" x2="14" y2="14" stroke="#000080" stroke-width="2" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_set_topic(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_set_topic(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <line x1="2" y1="4" x2="10" y2="4" stroke="#000080" stroke-width="1" />
      <line x1="2" y1="7" x2="10" y2="7" stroke="#000080" stroke-width="1" />
      <line x1="2" y1="10" x2="7" y2="10" stroke="#000080" stroke-width="1" />
      <path d="M12 7l2 2-5 5H7v-2z" fill="#000080" stroke="#000" stroke-width="0.3" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_options(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_options(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="5.5" fill="none" stroke="#555" stroke-width="1.2" />
      <circle cx="8" cy="8" r="2" fill="#555" />
      <line x1="8" y1="1" x2="8" y2="3.5" stroke="#555" stroke-width="1.5" />
      <line x1="8" y1="12.5" x2="8" y2="15" stroke="#555" stroke-width="1.5" />
      <line x1="1" y1="8" x2="3.5" y2="8" stroke="#555" stroke-width="1.5" />
      <line x1="12.5" y1="8" x2="15" y2="8" stroke="#555" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_custom_menus(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_custom_menus(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <line x1="2" y1="3" x2="11" y2="3" stroke="#555" stroke-width="1.5" stroke-linecap="round" />
      <line x1="2" y1="7" x2="11" y2="7" stroke="#555" stroke-width="1.5" stroke-linecap="round" />
      <line x1="2" y1="11" x2="11" y2="11" stroke="#555" stroke-width="1.5" stroke-linecap="round" />
      <polygon points="12,5 14,7.5 12,10" fill="#FFD700" stroke="#000" stroke-width="0.3" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_control(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_control(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="5.5" fill="none" stroke="#000080" stroke-width="1.2" />
      <circle cx="8" cy="8" r="2" fill="#000080" />
      <line x1="8" y1="1" x2="8" y2="3.5" stroke="#000080" stroke-width="1.5" />
      <line x1="8" y1="12.5" x2="8" y2="15" stroke="#000080" stroke-width="1.5" />
      <line x1="1" y1="8" x2="3.5" y2="8" stroke="#000080" stroke-width="1.5" />
      <line x1="12.5" y1="8" x2="15" y2="8" stroke="#000080" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_colors(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_colors(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" fill="#fff" stroke="#000080" stroke-width="1" />
      <circle cx="6" cy="5" r="1.2" fill="#FF0000" />
      <circle cx="9" cy="4.5" r="1.2" fill="#008000" />
      <circle cx="11" cy="7" r="1.2" fill="#000080" />
      <circle cx="5" cy="8" r="1.2" fill="#FFD700" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_group_view(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_group_view(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M1 8s3-5 7-5 7 5 7 5-3 5-7 5-7-5-7-5z" fill="none" stroke="#000080" stroke-width="1.5" />
      <circle cx="8" cy="8" r="2.5" fill="#000080" />
      <circle cx="8" cy="8" r="1" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_group_tools(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_group_tools(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="1" y="5" width="14" height="10" rx="1" fill="#555" stroke="#000" stroke-width="0.5" />
      <rect x="2" y="6" width="12" height="3" fill="#808080" />
      <rect x="5" y="3" width="6" height="3" rx="0.5" fill="none" stroke="#000" stroke-width="1" />
      <rect x="4" y="10" width="3" height="2" fill="#FFD700" />
      <rect x="9" y="10" width="3" height="2" fill="#FF0000" />
    </svg>
    """
  end
end
