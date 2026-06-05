defmodule RetroHexChatWeb.Icons.Tools do
  @moduledoc """
  Icons depicting configuration, editing, and customization concepts.
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  attr :class, :string, default: nil

  @spec icon_wrench(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_wrench(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <path
        d="M22 4 C 19 4 16.4 5.6 15 8 L 6 17 L 4 20 L 7 23 L 9 22 L 12 28 L 15 26 L 24 17 C 26.4 15.6 28 13 28 10 C 28 9 27.8 8 27.6 7 L 24 11 L 21 8 L 24.6 4.4 C 23.6 4.2 22.6 4 22 4 z"
        fill="#000"
        transform="translate(1,1)"
        stroke-linejoin="round"
      />
      
    <!-- Wrench Base (Silver) -->
      <path
        d="M22 4 C 19 4 16.4 5.6 15 8 L 6 17 L 4 20 L 7 23 L 9 22 L 12 28 L 15 26 L 24 17 C 26.4 15.6 28 13 28 10 C 28 9 27.8 8 27.6 7 L 24 11 L 21 8 L 24.6 4.4 C 23.6 4.2 22.6 4 22 4 z"
        fill="#C0C0C0"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      
    <!-- Highlights and details -->
      <path d="M7 20 l 5 5" fill="none" stroke="#000" stroke-width="1.5" stroke-linecap="round" />
      <path
        d="M15 8 L 6 17 M 24 17 L 26.4 14"
        fill="none"
        stroke="#fff"
        stroke-width="1.5"
        opacity="0.6"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_palette(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_palette(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <circle cx="17" cy="17" r="13" fill="#000" />
      
    <!-- Wooden Palette Base -->
      <circle cx="16" cy="16" r="13" fill="#D2B48C" stroke="#000" stroke-width="1.5" />
      <path
        d="M16 4 A 12 12 0 0 0 4 16"
        fill="none"
        stroke="#fff"
        stroke-width="2"
        opacity="0.4"
        stroke-linecap="round"
      />
      
    <!-- Thumb Hole -->
      <circle cx="23" cy="22" r="3" fill="#000080" />
      <!-- Empty background-like color for hole -->
      <circle cx="23" cy="22" r="3" fill="none" stroke="#555" stroke-width="1.5" />
      
    <!-- Colors -->
      <circle cx="12" cy="9" r="2.5" fill="#FF0000" stroke="#000" stroke-width="1" />
      <circle cx="18" cy="8" r="2.5" fill="#008000" stroke="#000" stroke-width="1" />
      <circle cx="23" cy="14" r="2.5" fill="#000080" stroke="#000" stroke-width="1" />
      <circle cx="10" cy="16" r="2.5" fill="#FFD700" stroke="#000" stroke-width="1" />
      <circle cx="14" cy="23" r="2.5" fill="#800080" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_edit(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_edit(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <polygon points="12,4 12,6 6,12 4,12 4,10 10,4" fill="#555" />
      <rect x="2" y="11" width="3" height="3" fill="#555" />
      
    <!-- Body -->
      <polygon points="11,3 11,5 5,11 3,11 3,9 9,3" fill="#000080" stroke="#000" stroke-width="1" />
      <rect x="2" y="10" width="3" height="3" fill="#C0C0C0" stroke="#000" stroke-width="1" />
      
    <!-- Highlight -->
      <polyline points="10,3 9,3 3,9 3,10" fill="none" stroke="#fff" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_save(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_save(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Floppy Shadow -->
      <rect x="3" y="3" width="12" height="12" fill="#555" />
      <!-- Floppy Body -->
      <rect x="2" y="2" width="12" height="12" fill="#000080" stroke="#000" stroke-width="1" />
      <!-- Metal Slider -->
      <rect x="4" y="2" width="8" height="5" fill="#C0C0C0" stroke="#000" stroke-width="1" />
      <!-- Slider Window -->
      <rect x="9" y="3" width="2" height="3" fill="#000080" />
      <!-- Label -->
      <rect x="4" y="9" width="8" height="5" fill="#fff" stroke="#000" stroke-width="1" />
      <!-- Label Lines -->
      <line x1="5" y1="11" x2="11" y2="11" stroke="#000080" stroke-width="1" />
      <!-- Body highlight -->
      <polyline points="2,14 2,2 14,2" fill="none" stroke="#fff" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_apply(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_apply(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Outer Target -->
      <path d="M7 1h2v3H7z M7 12h2v3H7z" fill="#000080" />
      <path d="M1 7h3v2H1z M12 7h3v2H12z" fill="#000080" />
      <rect x="6" y="6" width="4" height="4" fill="#000080" />
      
    <!-- High contrast Sharp Checkmark overlaid -->
      <path d="M8 10 L11 13 L16 7" fill="none" stroke="#000" stroke-width="3" />
      <path d="M8 10 L11 13 L16 7" fill="none" stroke="#00FF00" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_search(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_search(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Handle shadow -->
      <line x1="11" y1="11" x2="15" y2="15" stroke="#555" stroke-width="3" />
      
    <!-- Handle -->
      <line x1="10" y1="10" x2="14" y2="14" stroke="#000" stroke-width="3" />
      <line x1="10" y1="10" x2="14" y2="14" stroke="#000080" stroke-width="1" />
      
    <!-- Mag glass frame -->
      <rect x="2" y="2" width="7" height="7" fill="none" stroke="#000" stroke-width="3" />
      <rect x="2" y="2" width="7" height="7" fill="none" stroke="#000080" stroke-width="1" />
      
    <!-- Glass reflection -->
      <rect x="4" y="4" width="2" height="2" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_btn_set_topic(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_set_topic(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Lines -->
      <rect x="2" y="3" width="12" height="2" fill="#000080" />
      <rect x="2" y="7" width="8" height="2" fill="#000080" />
      <rect x="2" y="11" width="5" height="2" fill="#000080" />
      
    <!-- Edit pencil overlaid -->
      <polygon points="12,8 14,10 10,14 8,14 8,12" fill="#555" />
      <polygon points="11,7 13,9 9,13 7,13 7,11" fill="#fff" stroke="#000" stroke-width="1" />
      <polygon points="11,7 13,9 12,10 10,8" fill="#FFC000" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_options(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_options(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadows -->
      <rect x="3" y="4" width="12" height="2" fill="#000" />
      <rect x="3" y="12" width="12" height="2" fill="#000" />
      <rect x="5" y="3" width="2" height="4" fill="#000" />
      <rect x="11" y="11" width="2" height="4" fill="#000" />
      
    <!-- Sliders (White) -->
      <rect x="2" y="3" width="12" height="2" fill="#fff" />
      <rect x="2" y="11" width="12" height="2" fill="#fff" />
      
    <!-- Knobs (Gold) -->
      <rect x="4" y="2" width="2" height="4" fill="#FFD700" stroke="#000" stroke-width="1" />
      <rect x="10" y="10" width="2" height="4" fill="#FFD700" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_custom_menus(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_custom_menus(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadows -->
      <rect x="3" y="4" width="9" height="2" fill="#000" />
      <rect x="3" y="8" width="9" height="2" fill="#000" />
      <rect x="3" y="12" width="9" height="2" fill="#000" />
      
    <!-- Menu lines (White) -->
      <rect x="2" y="3" width="9" height="2" fill="#fff" />
      <rect x="2" y="7" width="9" height="2" fill="#fff" />
      <rect x="2" y="11" width="9" height="2" fill="#fff" />
      
    <!-- Gold Arrow -->
      <polygon points="10,6 14,9 10,12" fill="#FFD700" stroke="#000" stroke-width="1" />
      <!-- Inner highlight -->
      <polygon points="11,7 13,9 11,11" fill="none" stroke="#fff" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_control(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_control(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Target ring -->
      <polygon
        points="5,3 11,3 13,5 13,11 11,13 5,13 3,11 3,5"
        fill="none"
        stroke="#000080"
        stroke-width="1"
      />
      <!-- Center -->
      <rect x="7" y="7" width="2" height="2" fill="#000080" />
      <!-- Crosshairs -->
      <rect x="7" y="1" width="2" height="3" fill="#000080" />
      <rect x="7" y="12" width="2" height="3" fill="#000080" />
      <rect x="1" y="7" width="3" height="2" fill="#000080" />
      <rect x="12" y="7" width="3" height="2" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_tab_colors(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_tab_colors(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Palette body -->
      <polygon
        points="5,2 11,2 14,5 14,11 11,14 5,14 2,11 2,5"
        fill="#fff"
        stroke="#000080"
        stroke-width="1"
      />
      <!-- Thumb hole -->
      <rect x="10" y="9" width="2" height="2" fill="#000080" />
      <!-- Colors -->
      <rect x="5" y="4" width="2" height="2" fill="#FF0000" />
      <rect x="9" y="4" width="2" height="2" fill="#008000" />
      <rect x="11" y="6" width="2" height="2" fill="#0000FF" />
      <rect x="4" y="8" width="2" height="2" fill="#FFD700" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_group_view(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_group_view(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <path d="M2 16 Q 16 28 30 16 Q 16 4 2 16 z" fill="#000" transform="translate(1,1)" />
      
    <!-- Eye White -->
      <path
        d="M2 16 Q 16 28 30 16 Q 16 4 2 16 z"
        fill="#fff"
        stroke="#000080"
        stroke-width="2"
        stroke-linejoin="round"
      />
      
    <!-- Top Eyelid line to add depth -->
      <path
        d="M4 16 Q 16 7 28 16"
        fill="none"
        stroke="#000080"
        stroke-width="3"
        stroke-linecap="round"
      />
      
    <!-- Iris Outline -->
      <circle cx="16" cy="16" r="6" fill="#000" />
      <!-- Iris -->
      <circle cx="16" cy="16" r="5" fill="#008080" />
      <!-- Pupil -->
      <circle cx="16" cy="16" r="2.5" fill="#000" />
      <!-- Highlight -->
      <circle cx="14.5" cy="14.5" r="1.5" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_group_tools(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_group_tools(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Handle shadow -->
      <path
        d="M10 9 v -4 a 2 2 0 0 1 2 -2 h 8 a 2 2 0 0 1 2 2 v 4"
        fill="none"
        stroke="#000"
        stroke-width="4"
        transform="translate(1,1)"
      />
      <!-- Handle -->
      <path
        d="M10 9 v -4 a 2 2 0 0 1 2 -2 h 8 a 2 2 0 0 1 2 2 v 4"
        fill="none"
        stroke="#555"
        stroke-width="4"
      />
      <path
        d="M11 9 v -4 a 1 1 0 0 1 1 -1 h 8 a 1 1 0 0 1 1 1 v 4"
        fill="none"
        stroke="#A0A0A0"
        stroke-width="1.5"
      />
      
    <!-- Base box shadow -->
      <rect x="3" y="10" width="27" height="19" rx="1.5" fill="#000" />
      
    <!-- Base box -->
      <rect
        x="2"
        y="9"
        width="28"
        height="19"
        rx="1.5"
        fill="#808080"
        stroke="#000"
        stroke-width="1.5"
      />
      
    <!-- Top Lid -->
      <rect x="2" y="9" width="28" height="6" rx="1.5" fill="#A0A0A0" stroke="#000" stroke-width="1" />
      <line x1="2" y1="15" x2="30" y2="15" stroke="#000" stroke-width="1.5" />
      <line x1="3" y1="10" x2="29" y2="10" stroke="#fff" stroke-width="1.5" />
      <line x1="3" y1="16" x2="29" y2="16" stroke="#fff" stroke-width="1" opacity="0.6" />
      
    <!-- Details/Drawers -->
      <rect x="7" y="19" width="8" height="5" fill="#FFD700" stroke="#000" stroke-width="1.5" />
      <rect x="17" y="19" width="8" height="5" fill="#FF0000" stroke="#000" stroke-width="1.5" />
      <line x1="8" y1="20" x2="14" y2="20" stroke="#fff" stroke-width="1" opacity="0.8" />
      <line x1="18" y1="20" x2="24" y2="20" stroke="#fff" stroke-width="1" opacity="0.8" />
    </svg>
    """
  end

  # -- Toolbar: Find --

  attr :class, :string, default: nil

  @spec icon_btn_find(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_find(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <path
        d="M4 2h6v1h2v2h1v6h-1v2H9v-1H5v-1H3V5h1V3h2V2z M5 4h4v6H5V4z"
        fill-rule="evenodd"
        fill="#000080"
      />
      <path d="M10 10h2v2h2v3h-3v-2h-2v-2h1z" fill="#8B4513" />
      <rect x="6" y="5" width="2" height="2" fill="#000080" />
    </svg>
    """
  end

  # -- Toolbar: Settings --

  attr :class, :string, default: nil

  @spec icon_btn_settings(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_settings(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <path d="M6 1h4v2h2v1h2v4h-2v2h-2v4H6v-4H4v-2H2V4h2V3h2V1z" fill="#555" />
      <path d="M7 2h2v2h2v2h2v2h-2v2h-2v2H7v-2H5V8H3V6h2V4h2V2z" fill="#aaa" />
      <rect x="6" y="6" width="4" height="4" fill="#000080" />
      <rect x="7" y="7" width="2" height="2" fill="#fff" />
    </svg>
    """
  end

  # -- Toolbar: Address Book --

  attr :class, :string, default: nil

  @spec icon_btn_address_book(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_address_book(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="3" y="1" width="10" height="14" fill="#000080" />
      <rect x="4" y="2" width="8" height="12" fill="#FFD700" />
      <rect x="5" y="5" width="6" height="1" fill="#000080" />
      <rect x="5" y="7" width="6" height="1" fill="#000080" />
      <rect x="5" y="9" width="4" height="1" fill="#000080" />
      <rect x="1" y="4" width="2" height="2" fill="#FF0000" />
      <rect x="1" y="8" width="2" height="2" fill="#FF0000" />
    </svg>
    """
  end

  # -- Toolbar: Alias Editor --

  attr :class, :string, default: nil

  @spec icon_btn_alias_editor(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_alias_editor(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- A= -->
      <path d="M2 5h2v6H2v-2H1v-2h1z M4 5h1v6H4z M1 8h3v1H1z" fill="#000080" />
      <rect x="6" y="7" width="3" height="1" fill="#000080" />
      <rect x="6" y="9" width="3" height="1" fill="#000080" />
      <!-- Pencil -->
      <path
        d="M12 2h3v3h-1v1h-1v1h-1v1h-1v1h-1v1H9v1H8v1H7v2h3v-1h1v-1h1v-1h1v-1h1v-1h1v-1h1V5h1V2h-3z"
        fill="#FFD700"
      />
      <path d="M14 3h1v1h-1z M13 4h1v1h-1z M12 5h1v1h-1z" fill="#FF8C00" />
      <path d="M7 12h2v2H7z" fill="#ffc0cb" />
      <rect x="7" y="14" width="1" height="1" fill="#000" />
    </svg>
    """
  end

  # -- Toolbar: Custom Menus --

  attr :class, :string, default: nil

  @spec icon_btn_custom_menus(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_custom_menus(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="2" y="2" width="10" height="2" fill="#000080" />
      <rect x="2" y="5" width="10" height="2" fill="#000080" />
      <rect x="2" y="8" width="10" height="2" fill="#000080" />
      <path d="M10 11h2v5h-2z M12 12h2v3h-2z M14 13h2v1h-2z" fill="#FFD700" />
    </svg>
    """
  end

  # -- Toolbar: Timers --

  attr :class, :string, default: nil

  @spec icon_btn_timers(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_timers(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="6" y="1" width="4" height="2" fill="#000080" />
      <rect x="7" y="3" width="2" height="1" fill="#000080" />
      <rect x="4" y="4" width="8" height="1" fill="#000" />
      <rect x="3" y="5" width="10" height="1" fill="#000" />
      <rect x="2" y="6" width="12" height="6" fill="#fff" />
      <rect x="3" y="7" width="10" height="4" fill="#fff" />
      <rect x="4" y="12" width="8" height="1" fill="#000" />
      <rect x="5" y="13" width="6" height="1" fill="#000080" />
      <rect x="7" y="6" width="2" height="4" fill="#000080" />
      <rect x="8" y="9" width="4" height="2" fill="#000080" />
      <rect x="8" y="8" width="1" height="1" fill="#FFD700" />
    </svg>
    """
  end

  # -- Toolbar: Highlight Words --

  attr :class, :string, default: nil

  @spec icon_btn_highlight_words(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_highlight_words(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="2" y="10" width="12" height="3" fill="#FFD700" />
      <path d="M9 2h2v6H9z M7 2h2v4H7z M5 2h2v2H5z M6 6h1v2H6z" fill="#000080" />
      <rect x="7" y="8" width="4" height="2" fill="#FFD700" />
    </svg>
    """
  end

  # -- Button: Menu (hamburger, 16×16) --

  attr :class, :string, default: nil

  @spec icon_btn_menu(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_menu(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="2" y="3" width="12" height="2" fill="#000080" />
      <rect x="2" y="7" width="12" height="2" fill="#000080" />
      <rect x="2" y="11" width="12" height="2" fill="#000080" />
    </svg>
    """
  end
end
