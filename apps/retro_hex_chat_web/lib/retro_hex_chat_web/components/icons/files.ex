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
      <!-- Shadow projection -->
      <path d="M4 10 L 15 10 L 18 13 L 29 13 L 29 27 L 4 27 z" fill="#000" transform="translate(1,1)" />
      
    <!-- Back flap of folder -->
      <path
        d="M3 9 L 14 9 L 17 12 L 28 12 L 28 25 L 3 25 z"
        fill="#FFC000"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      
    <!-- Folder Tab Detail -->
      <rect x="4" y="9" width="10" height="2" fill="#FFC000" stroke="#000" stroke-width="1" />
      
    <!-- Inside darkness -->
      <rect x="4" y="11" width="24" height="2" fill="#806b00" />
      
    <!-- Front flap of folder -->
      <rect
        x="3"
        y="13"
        width="26"
        height="13"
        rx="1"
        fill="#FFD700"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      
    <!-- 3D Bevel Highlight (Top/Left) -->
      <path
        d="M4 25 L 4 14 L 28 14"
        fill="none"
        stroke="#fff"
        stroke-width="1.5"
        stroke-linecap="round"
      />
      <path
        d="M4 11 L 4 10 L 14 10 L 17 13 L 28 13"
        fill="none"
        stroke="#fff"
        stroke-width="1"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_notepad(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_notepad(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <path d="M7 4 L 21 4 L 27 10 L 27 28 L 7 28 z" fill="#000" transform="translate(1,1)" />
      
    <!-- Main Paper Body -->
      <path
        d="M6 3 L 20 3 L 26 9 L 26 27 L 6 27 z"
        fill="#fff"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      
    <!-- Paper Fold Detail (Top Right) -->
      <path
        d="M20 3 L 20 9 L 26 9"
        fill="#dfdfdf"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      <path d="M21 8 L 22 8" stroke="#fff" stroke-width="1.5" />
      
    <!-- Blue Header with Bevel -->
      <rect x="7" y="4" width="13" height="4" fill="#000080" />
      <line x1="7" y1="4" x2="19" y2="4" stroke="#fff" stroke-width="1.5" />
      
    <!-- Line rules with pixel precision spacing -->
      <line x1="9" y1="13" x2="23" y2="13" stroke="#000080" stroke-width="1.5" stroke-linecap="round" />
      <line x1="9" y1="17" x2="23" y2="17" stroke="#000080" stroke-width="1.5" stroke-linecap="round" />
      <line x1="9" y1="21" x2="23" y2="21" stroke="#000080" stroke-width="1.5" stroke-linecap="round" />
      <line x1="9" y1="25" x2="18" y2="25" stroke="#000080" stroke-width="1.5" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_trash(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_trash(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow projection -->
      <path d="M10 9 L 11 29 L 25 29 L 25 9 z" fill="#000" transform="translate(1,1)" />
      
    <!-- Main Bin Body -->
      <path
        d="M9 8 L 23 8 L 21 28 L 11 28 z"
        fill="#C0C0C0"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      
    <!-- Body Highlights (Left light, Right shadow) -->
      <line x1="11.5" y1="10" x2="13" y2="27" stroke="#fff" stroke-width="1.5" stroke-linecap="round" />
      
    <!-- Internal Ribs -->
      <path d="M 14.5 12 L 15.5 25" stroke="#fff" stroke-width="1.5" stroke-linecap="round" />
      <path d="M 17.5 12 L 17.5 25" stroke="#fff" stroke-width="1.5" stroke-linecap="round" />
      <path d="M 20.5 12 L 19.5 25" stroke="#fff" stroke-width="1.5" stroke-linecap="round" />
      
    <!-- Bin Lid Shadow -->
      <rect x="8" y="7" width="16" height="3" rx="1" fill="#000" transform="translate(1,1)" />
      <!-- Bin Lid Main -->
      <rect x="7" y="6" width="18" height="3" rx="1" fill="#C0C0C0" stroke="#000" stroke-width="1.5" />
      <!-- Bin Lid Highlight -->
      <line x1="8" y1="7" x2="24" y2="7" stroke="#fff" stroke-width="1" stroke-linecap="round" />
      
    <!-- Lid Handle -->
      <path d="M13 6 v -2 h 6 v 2" fill="none" stroke="#000" stroke-width="2" />
      <path d="M13.5 6 v -1.5 h 5 v 1.5" fill="none" stroke="#C0C0C0" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_backup(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_backup(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <circle cx="17" cy="17" r="12" fill="#000" />
      
    <!-- Disc base -->
      <circle cx="16" cy="16" r="12" fill="#fff" stroke="#000" stroke-width="1.5" />
      
    <!-- Disc Hole -->
      <circle cx="16" cy="16" r="4" fill="#C0C0C0" stroke="#000" stroke-width="1.5" />
      <circle cx="16" cy="16" r="1.5" fill="#fff" />
      
    <!-- Disc Reflection -->
      <path d="M10 10 L 13 13" stroke="#dfdfdf" stroke-width="2" />
      <path d="M22 10 L 19 13" stroke="#dfdfdf" stroke-width="2" />
      
    <!-- Update Arrow (Green) -->
      <path
        d="M7 23 A 9 9 0 0 0 25 23"
        fill="none"
        stroke="#008000"
        stroke-width="3"
        stroke-linecap="round"
      />
      <polygon
        points="21,20 28,23 23,28"
        fill="#008000"
        stroke="#008000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_file_send(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_file_send(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <path d="M5 5 l 14 0 l 6 6 l 0 18 l -20 0 z" fill="#000" transform="translate(1,1)" />
      <!-- Paper -->
      <path
        d="M4 4 l 14 0 l 6 6 l 0 18 l -20 0 z"
        fill="#fff"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      <!-- Fold -->
      <path
        d="M18 4 l 0 6 l 6 0"
        fill="#dfdfdf"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      
    <!-- Speed lines -->
      <line x1="14" y1="20" x2="26" y2="20" stroke="#000080" stroke-width="2" stroke-linecap="round" />
      <line x1="10" y1="16" x2="22" y2="16" stroke="#000080" stroke-width="2" stroke-linecap="round" />
      
    <!-- Arrow Send -->
      <path
        d="M22 17 l 4 3 l -4 3"
        fill="none"
        stroke="#000080"
        stroke-width="2"
        stroke-linejoin="round"
        stroke-linecap="round"
      />
      <path
        d="M18 13 l 4 3 l -4 3"
        fill="none"
        stroke="#000080"
        stroke-width="2"
        stroke-linejoin="round"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_choose_file(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_choose_file(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <path d="M2 9 L 14 9 L 17 12 L 28 12 L 28 25 L 2 25 z" fill="#000" transform="translate(1,1)" />
      
    <!-- Back flap of folder -->
      <path
        d="M2 9 L 14 9 L 17 12 L 28 12 L 28 25 L 2 25 z"
        fill="#FFC000"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      
    <!-- File inside -->
      <rect
        x="6"
        y="5"
        width="16"
        height="20"
        fill="#fff"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      <line x1="9" y1="9" x2="19" y2="9" stroke="#000" stroke-width="1" />
      <line x1="9" y1="12" x2="19" y2="12" stroke="#000" stroke-width="1" />
      
    <!-- Front flap of folder (open wider) -->
      <path
        d="M2 15 L 28 15 L 30 29 L 4 29 z"
        fill="#FFD700"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      <path d="M2 15 L 28 15" fill="none" stroke="#fff" stroke-width="1.5" stroke-linecap="round" />
      <path d="M2 16 L 4 29" fill="none" stroke="#fff" stroke-width="1" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_cheatsheet(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_cheatsheet(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <rect x="3" y="3" width="12" height="12" fill="#000" />
      <!-- Sheet Base (White) -->
      <rect x="2" y="2" width="12" height="12" fill="#fff" stroke="#000" stroke-width="1" />
      <!-- Text lines -->
      <rect x="4" y="4" width="8" height="2" fill="#000080" />
      <rect x="4" y="8" width="5" height="2" fill="#000080" />
      <rect x="4" y="12" width="8" height="2" fill="#000080" />
      <rect x="11" y="8" width="1" height="2" fill="#FF0000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_delete(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_delete(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Outline shadow -->
      <polygon points="8,1 1,14 15,14" fill="#000" />
      <!-- Solid Triangle (Gold) -->
      <polygon points="8,2 2,13 14,13" fill="#FFD700" />
      <!-- Exclamation point (Black) -->
      <rect x="7" y="6" width="2" height="4" fill="#000" />
      <rect x="7" y="11" width="2" height="2" fill="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_paste(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_paste(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <rect x="5" y="4" width="8" height="12" fill="#000" />
      <!-- Paper Body (White) -->
      <rect x="4" y="3" width="8" height="12" fill="#fff" stroke="#000" stroke-width="1" />
      <!-- Clip (Silver/Gray) -->
      <rect x="6" y="1" width="4" height="4" fill="#C0C0C0" stroke="#000" stroke-width="1" />
      <line x1="7" y1="2" x2="9" y2="2" stroke="#fff" stroke-width="1" />
      <!-- Paper lines -->
      <rect x="5" y="7" width="6" height="1" fill="#000" />
      <rect x="5" y="9" width="6" height="1" fill="#000" />
      <rect x="5" y="11" width="4" height="1" fill="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_copy(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_copy(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow of back document -->
      <rect x="6" y="4" width="16" height="20" rx="1" fill="#000" transform="translate(2,2)" />
      <!-- Back document -->
      <rect x="6" y="4" width="16" height="20" rx="1" fill="#dfdfdf" stroke="#000" stroke-width="1.5" />
      
    <!-- Shadow of front document -->
      <rect x="12" y="10" width="16" height="20" rx="1" fill="#000" transform="translate(1,1)" />
      <!-- Front document -->
      <rect x="12" y="10" width="16" height="20" rx="1" fill="#fff" stroke="#000" stroke-width="1.5" />
      
    <!-- Front doc lines -->
      <line
        x1="15"
        y1="16"
        x2="25"
        y2="16"
        stroke="#000080"
        stroke-width="1.5"
        stroke-linecap="round"
      />
      <line
        x1="15"
        y1="20"
        x2="25"
        y2="20"
        stroke="#000080"
        stroke-width="1.5"
        stroke-linecap="round"
      />
      <line
        x1="15"
        y1="24"
        x2="21"
        y2="24"
        stroke="#000080"
        stroke-width="1.5"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  # -- Toolbar: Keyboard --

  attr :class, :string, default: nil

  @spec icon_btn_keyboard(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_keyboard(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="1" y="3" width="14" height="10" rx="1" fill="#fff" stroke="#000" stroke-width="1" />
      <rect x="3" y="5" width="2" height="2" rx="0.3" fill="#000080" />
      <rect x="6" y="5" width="2" height="2" rx="0.3" fill="#000080" />
      <rect x="9" y="5" width="2" height="2" rx="0.3" fill="#000080" />
      <rect x="12" y="5" width="2" height="2" rx="0.3" fill="#000080" />
      <rect x="3" y="8" width="2" height="2" rx="0.3" fill="#000080" />
      <rect x="6" y="8" width="6" height="2" rx="0.3" fill="#000080" />
      <rect x="12" y="8" width="2" height="2" rx="0.3" fill="#000080" />
    </svg>
    """
  end
end
