defmodule RetroHexChatWeb.Icons.Alerts do
  @moduledoc """
  Icons depicting notifications, information, and alert concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_document_alert(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_document_alert(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow of document -->
      <rect x="7" y="3" width="18" height="24" rx="1" fill="#000" transform="translate(1,1)" />
      <!-- Document Base -->
      <rect x="7" y="3" width="18" height="24" rx="1" fill="#fff" stroke="#000" stroke-width="1.5" />
      
    <!-- Blue Lines -->
      <line x1="10" y1="9" x2="22" y2="9" stroke="#000080" stroke-width="1.5" stroke-linecap="round" />
      <line
        x1="10"
        y1="13"
        x2="22"
        y2="13"
        stroke="#000080"
        stroke-width="1.5"
        stroke-linecap="round"
      />
      <line
        x1="10"
        y1="17"
        x2="18"
        y2="17"
        stroke="#000080"
        stroke-width="1.5"
        stroke-linecap="round"
      />
      
    <!-- Alert Badge Shadow -->
      <circle cx="21" cy="20" r="7" fill="#000" transform="translate(1,1)" />
      <!-- Alert Badge -->
      <circle cx="21" cy="20" r="7" fill="#FFD700" stroke="#000" stroke-width="1.5" />
      <circle cx="19.5" cy="18.5" r="3" fill="none" stroke="#fff" stroke-width="1.5" opacity="0.6" />
      
    <!-- Exclamation point -->
      <path d="M21 15 L 21 21 L 21 21" stroke="#000" stroke-width="2" stroke-linecap="round" />
      <circle cx="21" cy="24" r="1" fill="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_question(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_question(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <circle cx="17" cy="17" r="13" fill="#000" />
      
    <!-- Base Base (Navy) -->
      <circle cx="16" cy="16" r="13" fill="#000080" stroke="#000" stroke-width="1.5" />
      
    <!-- Bevel Highlights -->
      <path
        d="M16 4 A 12 12 0 0 0 4 16"
        fill="none"
        stroke="#fff"
        stroke-width="2"
        opacity="0.6"
        stroke-linecap="round"
      />
      
    <!-- Question Mark -->
      <path
        d="M11 11.5 A 5 5 0 1 1 20 12 C 20 15 16 16 16 19"
        fill="none"
        stroke="#fff"
        stroke-width="3"
        stroke-linecap="round"
      />
      <circle cx="16" cy="24" r="2" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_about(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_about(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <polygon points="7,3 12,3 15,6 15,11 12,14 7,14 4,11 4,6" fill="#000" />
      
    <!-- Octagon base -->
      <polygon
        points="6,2 11,2 14,5 14,10 11,13 6,13 3,10 3,5"
        fill="#fff"
        stroke="#000"
        stroke-width="1"
      />
      
    <!-- 'i' symbol (Navy blue inside white box) -->
      <rect x="8" y="4" width="2" height="2" fill="#000080" />
      <rect x="7" y="7" width="3" height="4" fill="#000080" />
      <line x1="6" y1="11" x2="11" y2="11" stroke="#000080" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_notifications(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_notifications(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <polygon points="6,5 12,5 12,10 14,12 14,13 4,13 4,12 6,10" fill="#000" />
      
    <!-- Bell shape (Gold) -->
      <rect x="7" y="2" width="2" height="2" fill="#FFD700" stroke="#000" stroke-width="1" />
      <polygon
        points="5,4 11,4 11,9 13,11 13,12 3,12 3,11 5,9"
        fill="#FFD700"
        stroke="#000"
        stroke-width="1"
      />
      
    <!-- Highlight -->
      <polyline points="5,5 10,5" stroke="#fff" stroke-width="1" />
      
    <!-- Ringer (Silver) -->
      <rect x="6" y="13" width="4" height="2" fill="#C0C0C0" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_highlight(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_highlight(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Lines (White for dark bg) -->
      <rect x="2" y="3" width="12" height="2" fill="#fff" />
      <rect x="2" y="6" width="12" height="2" fill="#fff" />
      
    <!-- Highlighting block (Gold/Yellow) -->
      <rect x="1" y="9" width="14" height="4" fill="#FFD700" stroke="#000" stroke-width="1" />
      <!-- Line inside highlight (Black for contrast) -->
      <rect x="2" y="10" width="12" height="2" fill="#000" />

      <rect x="2" y="14" width="8" height="2" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_flood(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_flood(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <polygon points="8,3 2,14 14,14" fill="#000" />
      
    <!-- Warning Triangle (Gold) -->
      <polygon points="8,2 2,13 14,13" fill="#FFD700" />
      <polygon points="8,3 3,12 13,12" fill="none" stroke="#fff" stroke-width="1" />
      <polygon points="8,2 2,13 14,13" fill="none" stroke="#000" stroke-width="1" />
      
    <!-- ! marker (Black inside gold triangle) -->
      <rect x="7" y="6" width="2" height="3" fill="#000" />
      <rect x="7" y="10" width="2" height="2" fill="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_status(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_status(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="2" y="2" width="12" height="12" fill="#000080" />
      <!-- Content lines (White) -->
      <rect x="4" y="5" width="4" height="1" fill="#fff" />
      <rect x="4" y="8" width="6" height="1" fill="#fff" />
      <rect x="4" y="11" width="3" height="1" fill="#fff" />
      <!-- Square block (White) -->
      <rect x="9" y="10" width="2" height="2" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_general(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_general(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Octagon base -->
      <polygon
        points="5,2 11,2 14,5 14,11 11,14 5,14 2,11 2,5"
        fill="none"
        stroke="#000080"
        stroke-width="1"
      />
      
    <!-- 'i' symbol (Navy blue) -->
      <rect x="7" y="4" width="2" height="2" fill="#000080" />
      <rect x="6" y="7" width="3" height="4" fill="#000080" />
      <rect x="5" y="11" width="5" height="1" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_notify(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_notify(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Bell body -->
      <rect x="7" y="2" width="2" height="2" fill="#000080" />
      <polygon points="5,4 11,4 11,9 13,11 13,12 3,12 3,11 5,9" fill="#000080" />
      <!-- Ringer (Gold) -->
      <rect x="7" y="13" width="2" height="2" fill="#FFD700" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_notifications(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_notifications(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Bell body -->
      <rect x="7" y="2" width="2" height="2" fill="#000080" />
      <polygon points="5,4 11,4 11,9 13,11 13,12 3,12 3,11 5,9" fill="#000080" />
      <!-- Ringer (Gold) -->
      <rect x="7" y="13" width="2" height="2" fill="#FFD700" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_group_notifications(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_group_notifications(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Outer shadow -->
      <path
        d="M16 3 C 10 3 8 8 8 13 v 6 l -4 4 v 2 h 24 v -2 l -4 -4 v -6 C 24 8 22 3 16 3 z"
        fill="#000"
        transform="translate(1,1)"
      />
      <!-- Bell base -->
      <path
        d="M16 3 C 10 3 8 8 8 13 v 6 l -4 4 v 2 h 24 v -2 l -4 -4 v -6 C 24 8 22 3 16 3 z"
        fill="#FFD700"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      <!-- Top loop -->
      <path d="M14 3 v -1 a 2 2 0 0 1 4 0 v 1" fill="none" stroke="#000" stroke-width="1.5" />
      <!-- Ringer -->
      <path d="M12 25 a 4 4 0 0 0 8 0 z" fill="#FFD700" stroke="#000" stroke-width="1.5" />
      
    <!-- Highlight -->
      <path d="M11 13 v 6 l -3 3" fill="none" stroke="#fff" stroke-width="1.5" />
      <path d="M16 4 C 11 4 9 9 9 14" fill="none" stroke="#fff" stroke-width="1.5" />
      
    <!-- Red Alert -->
      <circle cx="26" cy="8" r="6" fill="#000" />
      <circle cx="26" cy="8" r="5" fill="#FF0000" />
      <text
        x="26"
        y="11"
        text-anchor="middle"
        font-size="10"
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

  @spec icon_group_help(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_group_help(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Outer border shadow -->
      <circle cx="16" cy="16" r="15" fill="#000" />
      <!-- Bevel Base -->
      <circle cx="15" cy="15" r="14" fill="#fff" />
      <!-- Main fill -->
      <circle cx="16" cy="16" r="13" fill="#000080" />
      
    <!-- Question Mark Shadow -->
      <path
        d="M11 11.5 A 5 5 0 1 1 20 12 C 20 15 16 16 16 19"
        fill="none"
        stroke="#000"
        stroke-width="5"
        stroke-linecap="round"
      />
      <circle cx="16" cy="24" r="2.5" fill="#000" />
      
    <!-- Question Mark -->
      <path
        d="M11 11.5 A 5 5 0 1 1 20 12 C 20 15 16 16 16 19"
        fill="none"
        stroke="#fff"
        stroke-width="3"
        stroke-linecap="round"
      />
      <circle cx="16" cy="24" r="1.5" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_lightbulb(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_lightbulb(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <path
        d="M16 2 C 11 2 7 6 7 11 C 7 14 9 17 11 19 V 23 H 21 V 19 C 23 17 25 14 25 11 C 25 6 21 2 16 2 z"
        fill="#000"
        transform="translate(1,1)"
        stroke-linejoin="round"
      />
      
    <!-- Lightbulb Glass (Yellow/Gold) -->
      <path
        d="M16 2 C 11 2 7 6 7 11 C 7 14 9 17 11 19 V 23 H 21 V 19 C 23 17 25 14 25 11 C 25 6 21 2 16 2 z"
        fill="#FFD700"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      
    <!-- Yellow glow lines -->
      <path
        d="M16 4 C 12 4 9 8 9 11"
        fill="none"
        stroke="#fff"
        stroke-width="1.5"
        opacity="0.6"
        stroke-linecap="round"
      />
      
    <!-- Filament -->
      <path
        d="M13 18 v -4 l 2 -2 l 2 2 v 4"
        fill="none"
        stroke="#B8860B"
        stroke-width="2"
        stroke-linejoin="round"
      />
      
    <!-- Screw Base -->
      <rect x="11" y="23" width="10" height="3" fill="#C0C0C0" stroke="#000" stroke-width="1.5" />
      <rect x="12" y="26" width="8" height="3" fill="#808080" stroke="#000" stroke-width="1.5" />
      <circle cx="16" cy="29" r="2" fill="#000" />
      
    <!-- Shine paths (optional outer rays) -->
      <line x1="16" y1="0" x2="16" y2="3" stroke="#FFD700" stroke-width="2" stroke-linecap="round" />
      <line x1="3" y1="11" x2="6" y2="11" stroke="#FFD700" stroke-width="2" stroke-linecap="round" />
      <line x1="26" y1="11" x2="29" y2="11" stroke="#FFD700" stroke-width="2" stroke-linecap="round" />
    </svg>
    """
  end

  # -- Toolbar: DND --

  attr :class, :string, default: nil

  @spec icon_btn_dnd(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_dnd(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <path
        d="M9 2h2v1h1v2h1v4h-1v2h-1v1H9v1H7v-1H6v-1h2v-1h1v-2h1V6h-1V5H8V4H6V3h1V2h2z"
        fill="#000080"
      />
    </svg>
    """
  end

  # -- Toolbar: DND Active --

  attr :class, :string, default: nil

  @spec icon_btn_dnd_active(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_dnd_active(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <path
        d="M9 2h2v1h1v2h1v4h-1v2h-1v1H9v1H7v-1H6v-1h2v-1h1v-2h1V6h-1V5H8V4H6V3h1V2h2z"
        fill="#000080"
      />
      <path
        d="M2 1h2v1h1v1h1v1h1v1h1v1h1v1h1v1h1v1h1v1h1v1h1v1h-2v-1h-1v-1h-1v-1h-1v-1h-1v-1h-1V7H7V6H6V5H5V4H4V3H3V2H2V1z"
        fill="#FF0000"
      />
    </svg>
    """
  end

  # -- Toolbar: Help Topics --

  attr :class, :string, default: nil

  @spec icon_btn_help_topics(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_help_topics(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <path d="M6 2h4v1h2v2h1v6h-1v2h-2v1H6v-1H4v-2H3V5h1V3h2V2z" fill="#000080" />
      <path d="M7 4h2v1h1v2H9v1H8v2H7V8h1V7h1V6H7V4z M7 11h2v2H7v-2z" fill="#fff" />
    </svg>
    """
  end

  # -- Button: Info (info circle, 16×16) --

  attr :class, :string, default: nil

  @spec icon_btn_info(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_info(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Circle -->
      <circle cx="8" cy="8" r="6" fill="#000080" stroke="#000" stroke-width="1" />
      <!-- Highlight -->
      <path d="M5 4 A 5 5 0 0 1 12 5" fill="none" stroke="#fff" stroke-width="1" opacity="0.4" />
      <!-- Letter i -->
      <rect x="7" y="4" width="2" height="2" fill="#fff" />
      <rect x="7" y="7" width="2" height="4" fill="#fff" />
    </svg>
    """
  end
end
