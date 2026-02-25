defmodule RetroHexChatWeb.Icons.Code do
  @moduledoc """
  Icons depicting programming, scripting, and automation concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_terminal(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_terminal(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Terminal Shadow -->
      <rect x="2" y="4" width="28" height="24" rx="2" fill="#000" transform="translate(1,1)" />
      <!-- Terminal Body -->
      <rect x="2" y="4" width="28" height="24" rx="2" fill="#000" stroke="#808080" stroke-width="1.5" />
      <path d="M4 6 L 28 6" stroke="#fff" stroke-width="1" opacity="0.3" stroke-linecap="round" />
      
      <!-- Prompt '>' -->
      <path d="M6 10 L 12 16 L 6 22" fill="none" stroke="#00FF00" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
      <!-- Cursor '_' -->
      <line x1="14" y1="22" x2="20" y2="22" stroke="#00FF00" stroke-width="2" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_git(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_git(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow Lines -->
      <line x1="16" y1="12" x2="10" y2="20" stroke="#000" stroke-width="4" stroke-linecap="round" transform="translate(1,1)" />
      <line x1="16" y1="12" x2="22" y2="20" stroke="#000" stroke-width="4" stroke-linecap="round" transform="translate(1,1)" />
      <!-- Branches Lines -->
      <line x1="16" y1="12" x2="10" y2="20" stroke="#555" stroke-width="3" stroke-linecap="round" />
      <line x1="16" y1="12" x2="22" y2="20" stroke="#555" stroke-width="3" stroke-linecap="round" />
      
      <!-- Nodes Shadow -->
      <circle cx="16" cy="10" r="4" fill="#000" transform="translate(1,1)" />
      <circle cx="9" cy="22" r="4" fill="#000" transform="translate(1,1)" />
      <circle cx="23" cy="22" r="4" fill="#000" transform="translate(1,1)" />
      
      <!-- Nodes -->
      <circle cx="16" cy="10" r="4" fill="#FF0000" stroke="#000" stroke-width="1.5" />
      <circle cx="9" cy="22" r="4" fill="#008000" stroke="#000" stroke-width="1.5" />
      <circle cx="23" cy="22" r="4" fill="#000080" stroke="#000" stroke-width="1.5" />
      
      <!-- Nodes Reflection -->
      <circle cx="15" cy="8.5" r="1" fill="#fff" opacity="0.6" />
      <circle cx="8" cy="20.5" r="1" fill="#fff" opacity="0.6" />
      <circle cx="22" cy="20.5" r="1" fill="#fff" opacity="0.6" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_code(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_code(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <path d="M10 8 L 2 16 L 10 24" fill="none" stroke="#000" stroke-width="4" stroke-linecap="round" stroke-linejoin="round" transform="translate(1,1)" />
      <path d="M22 8 L 30 16 L 22 24" fill="none" stroke="#000" stroke-width="4" stroke-linecap="round" stroke-linejoin="round" transform="translate(1,1)" />
      <line x1="18" y1="4" x2="14" y2="28" stroke="#000" stroke-width="4" stroke-linecap="round" transform="translate(1,1)" />
      
      <!-- Base Color -->
      <path d="M10 8 L 2 16 L 10 24" fill="none" stroke="#000080" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" />
      <path d="M22 8 L 30 16 L 22 24" fill="none" stroke="#000080" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" />
      <line x1="18" y1="4" x2="14" y2="28" stroke="#808080" stroke-width="3" stroke-linecap="round" />
      <line x1="18" y1="4" x2="14" y2="28" stroke="#fff" stroke-width="1" stroke-linecap="round" opacity="0.6" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_alias(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_alias(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow of A= -->
      <rect x="2" y="3" width="2" height="10" fill="#000" />
      <rect x="5" y="3" width="2" height="10" fill="#000" />
      <rect x="2" y="8" width="5" height="2" fill="#000" />
      
      <!-- A= Text using pure blocks (White for dark bg) -->
      <rect x="1" y="2" width="2" height="10" fill="#fff" />
      <rect x="4" y="2" width="2" height="10" fill="#fff" />
      <rect x="1" y="7" width="5" height="2" fill="#fff" />
      
      <rect x="8" y="5" width="4" height="2" fill="#fff" />
      <rect x="8" y="9" width="4" height="2" fill="#fff" />
      
      <!-- Edit pencil (Gold) -->
      <polygon points="12,14 15,11 14,10 11,13" fill="#FFD700" stroke="#000" stroke-width="1" />
      <polygon points="11,13 14,10 13,9 10,12" fill="#fff" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_ctcp(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_ctcp(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <rect x="4" y="3" width="11" height="11" fill="#000" />
      
      <!-- Box lines (White for dark bg) -->
      <rect x="3" y="2" width="11" height="11" fill="none" stroke="#fff" stroke-width="2" />
      
      <!-- Arrow/Zap inside (Gold) -->
      <polygon points="5,7 9,5 8,8 11,8 7,12 8,9 5,9" fill="#FFD700" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_auto_respond(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_auto_respond(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <polygon points="3,3 13,3 15,6 15,10 10,10 6,14 6,10 3,10" fill="#000" />
      
      <!-- Message Balloon (White) -->
      <polygon points="2,2 12,2 14,5 14,9 9,9 5,13 5,9 2,9" fill="#fff" stroke="#000" stroke-width="1" />
      
      <!-- Arrow Return (Gold) -->
      <path d="M12 9 V5 H5" fill="none" stroke="#FFD700" stroke-width="2" />
      <polygon points="7,3 4,5 7,7" fill="#FFD700" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_perform(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_perform(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <polygon points="3,3 3,13 11,8" fill="#000" />
      <rect x="8" y="8" width="6" height="6" fill="#000" />
      
      <!-- Play button (Green instead of navy/blank for popup) -->
      <polygon points="2,2 2,12 10,7" fill="#00FF00" stroke="#000" stroke-width="1" />
      
      <!-- Gear (Silver) -->
      <rect x="9" y="8" width="4" height="4" fill="#C0C0C0" stroke="#000" stroke-width="1" />
      <rect x="10" y="7" width="2" height="6" fill="#C0C0C0" />
      <rect x="8" y="9" width="6" height="2" fill="#C0C0C0" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_commands(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_commands(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="2" y="3" width="12" height="10" fill="#000080" />
      <polygon points="4,5 6,7 4,9" fill="none" stroke="#fff" stroke-width="1" />
      <rect x="7" y="9" width="4" height="1" fill="#fff" />
    </svg>
    """
  end
end
