defmodule RetroHexChatWeb.Icons.Files do
  @moduledoc """
  Icons depicting files, folders, and document concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_folder(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_folder(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <path d="M2 8V26H30V10H16L13 7H2Z" fill="#FFD700" />
      <path d="M2 8H13L16 10H30V26H2Z" fill="#FFD700" stroke="#000" stroke-width="1" />
      <rect x="2" y="10" width="28" height="16" fill="#FFD700" />
      <path d="M2 10H30V12H2Z" fill="#FFC000" />
      <rect x="2" y="7" width="11" height="3" fill="#FFD700" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_notepad(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_notepad(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <rect x="6" y="2" width="20" height="28" rx="1" fill="#fff" stroke="#000" stroke-width="1" />
      <rect x="6" y="2" width="20" height="5" fill="#000080" />
      <line x1="9" y1="12" x2="23" y2="12" stroke="#000080" stroke-width="1" />
      <line x1="9" y1="16" x2="23" y2="16" stroke="#000080" stroke-width="1" />
      <line x1="9" y1="20" x2="23" y2="20" stroke="#000080" stroke-width="1" />
      <line x1="9" y1="24" x2="18" y2="24" stroke="#000080" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_trash(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_trash(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <rect
        x="9"
        y="8"
        width="14"
        height="20"
        rx="1"
        fill="#fff"
        stroke="#555"
        stroke-width="1"
      />
      <rect x="7" y="6" width="18" height="3" rx="1" fill="#555" />
      <rect x="13" y="4" width="6" height="3" fill="#555" />
      <line x1="13" y1="12" x2="13" y2="24" stroke="#555" stroke-width="1" />
      <line x1="16" y1="12" x2="16" y2="24" stroke="#555" stroke-width="1" />
      <line x1="19" y1="12" x2="19" y2="24" stroke="#555" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_backup(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_backup(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6" fill="#fff" stroke="#555" stroke-width="1" />
      <circle cx="8" cy="8" r="2" fill="#555" />
      <circle cx="8" cy="8" r="0.8" fill="#fff" />
      <path d="M4 4l1.5 1.5" stroke="#555" stroke-width="0.8" />
      <path d="M12 4l-1.5 1.5" stroke="#555" stroke-width="0.8" />
      <path d="M3 11l2-1" stroke="#008000" stroke-width="1.5" />
      <polygon points="2,10 3,12.5 4.5,10.5" fill="#008000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_file_send(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_file_send(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M2 2h7l3 3v9H2z" fill="#FFD700" stroke="#000" stroke-width="0.8" />
      <path d="M9 2v3h3" fill="none" stroke="#000" stroke-width="0.8" />
      <path
        d="M7 10h5M10 8l2 2-2 2"
        fill="none"
        stroke="#000080"
        stroke-width="1.5"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_choose_file(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_choose_file(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M1 4V14H15V6H8L6 4z" fill="#FFD700" stroke="#000" stroke-width="0.8" />
      <path d="M1 6H15V14H1z" fill="#FFD700" />
      <path d="M1 6H15V8H1z" fill="#FFC000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_cheatsheet(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_cheatsheet(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="1" y="4" width="14" height="10" rx="1" fill="none" stroke="#fff" stroke-width="1" />
      <rect x="3" y="6" width="3" height="2" rx="0.3" fill="#fff" />
      <rect x="7" y="6" width="3" height="2" rx="0.3" fill="#fff" />
      <rect x="11" y="6" width="2" height="2" rx="0.3" fill="#fff" />
      <rect x="4" y="9" width="8" height="2" rx="0.3" fill="#fff" />
      <rect x="2" y="9" width="1.5" height="2" rx="0.3" fill="#fff" />
      <rect x="13" y="9" width="1.5" height="2" rx="0.3" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_delete(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_delete(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="8,1 15,14 1,14" fill="#FFD700" stroke="#fff" stroke-width="0.5" />
      <text
        x="8"
        y="13"
        text-anchor="middle"
        font-size="9"
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

  @spec icon_dialog_log(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_log(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="3" y="1" width="10" height="14" rx="1" fill="none" stroke="#fff" stroke-width="1" />
      <line x1="5" y1="4" x2="11" y2="4" stroke="#fff" stroke-width="0.8" />
      <line x1="5" y1="6.5" x2="11" y2="6.5" stroke="#fff" stroke-width="0.8" />
      <line x1="5" y1="9" x2="11" y2="9" stroke="#fff" stroke-width="0.8" />
      <line x1="5" y1="11.5" x2="9" y2="11.5" stroke="#fff" stroke-width="0.8" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_paste(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_paste(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="3" y="3" width="10" height="12" rx="1" fill="none" stroke="#fff" stroke-width="1" />
      <rect x="6" y="1" width="4" height="3" rx="0.5" fill="#fff" />
      <line x1="5" y1="7" x2="11" y2="7" stroke="#fff" stroke-width="0.8" />
      <line x1="5" y1="9.5" x2="11" y2="9.5" stroke="#fff" stroke-width="0.8" />
      <line x1="5" y1="12" x2="9" y2="12" stroke="#fff" stroke-width="0.8" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_copy(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_copy(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="5" y="5" width="8" height="9" rx="0.5" fill="#fff" stroke="#000080" stroke-width="1" />
      <rect x="3" y="2" width="8" height="9" rx="0.5" fill="#fff" stroke="#000080" stroke-width="1" />
      <line x1="5" y1="5" x2="9" y2="5" stroke="#000080" stroke-width="0.8" />
      <line x1="5" y1="7.5" x2="9" y2="7.5" stroke="#000080" stroke-width="0.8" />
    </svg>
    """
  end
end
