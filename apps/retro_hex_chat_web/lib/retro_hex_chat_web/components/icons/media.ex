defmodule RetroHexChatWeb.Icons.Media do
  @moduledoc """
  Icons depicting audio, video, and media device concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_microphone(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_microphone(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Mic Head Shadow -->
      <rect x="12" y="3" width="10" height="15" rx="5" fill="#000" transform="translate(1,1)" />
      <!-- Mic Head -->
      <rect
        x="12"
        y="3"
        width="10"
        height="15"
        rx="5"
        fill="#C0C0C0"
        stroke="#000"
        stroke-width="1.5"
      />
      <!-- Head Mesh Lines -->
      <line x1="14" y1="5" x2="20" y2="5" stroke="#A0A0A0" stroke-width="1" />
      <line x1="13" y1="8" x2="21" y2="8" stroke="#A0A0A0" stroke-width="1" />
      <line x1="13" y1="11" x2="21" y2="11" stroke="#A0A0A0" stroke-width="1" />
      <line x1="14" y1="14" x2="20" y2="14" stroke="#A0A0A0" stroke-width="1" />
      
    <!-- Mic Head Highlight -->
      <path d="M 14 5 A 3 3 0 0 0 14 16" fill="none" stroke="#fff" stroke-width="1.5" opacity="0.8" />
      
    <!-- Armature Shadow -->
      <path
        d="M7 14 a 9 9 0 0 0 18 0"
        fill="none"
        stroke="#000"
        stroke-width="3"
        stroke-linecap="round"
        transform="translate(1,1)"
      />
      <line
        x1="16"
        y1="23"
        x2="16"
        y2="28"
        stroke="#000"
        stroke-width="3"
        stroke-linecap="round"
        transform="translate(1,1)"
      />
      <line
        x1="12"
        y1="28"
        x2="20"
        y2="28"
        stroke="#000"
        stroke-width="3"
        stroke-linecap="round"
        transform="translate(1,1)"
      />
      
    <!-- Armature -->
      <path
        d="M7 14 a 9 9 0 0 0 18 0"
        fill="none"
        stroke="#000080"
        stroke-width="3"
        stroke-linecap="round"
      />
      <line x1="16" y1="23" x2="16" y2="28" stroke="#000080" stroke-width="3" stroke-linecap="round" />
      <line x1="12" y1="28" x2="20" y2="28" stroke="#000080" stroke-width="3" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_camera(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_camera(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Body Shadow -->
      <rect x="4" y="8" width="18" height="16" rx="2" fill="#000" transform="translate(1,1)" />
      <!-- Lens Shadow -->
      <path
        d="M22 13 L 28 9 L 28 23 L 22 19 z"
        fill="#000"
        stroke-linejoin="round"
        transform="translate(1,1)"
      />
      
    <!-- Body -->
      <rect x="4" y="8" width="18" height="16" rx="2" fill="#000080" stroke="#000" stroke-width="1.5" />
      <path d="M4 10 L 22 10" stroke="#fff" stroke-width="1" opacity="0.6" />
      <path d="M6 8 L 6 24" stroke="#fff" stroke-width="1" opacity="0.5" />
      
    <!-- Lens -->
      <path
        d="M22 13 L 28 9 L 28 23 L 22 19 z"
        fill="#008080"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      <path d="M22 13 L 27 9.5" stroke="#fff" stroke-width="1" opacity="0.6" />
      
    <!-- Record Light -->
      <circle cx="9" cy="12" r="2" fill="#FF0000" stroke="#000" stroke-width="1" />
      <circle cx="8.5" cy="11.5" r="0.5" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_camera_off(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_camera_off(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Body Shadow -->
      <rect x="4" y="8" width="18" height="16" rx="2" fill="#000" transform="translate(1,1)" />
      <path
        d="M22 13 L 28 9 L 28 23 L 22 19 z"
        fill="#000"
        stroke-linejoin="round"
        transform="translate(1,1)"
      />
      
    <!-- Body (Gray out) -->
      <rect x="4" y="8" width="18" height="16" rx="2" fill="#808080" stroke="#000" stroke-width="1.5" />
      
    <!-- Lens (Gray out) -->
      <path
        d="M22 13 L 28 9 L 28 23 L 22 19 z"
        fill="#606060"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />

      <circle cx="9" cy="12" r="2" fill="#555" stroke="#000" stroke-width="1" />
      
    <!-- Red Slash Shadow -->
      <line
        x1="3"
        y1="3"
        x2="29"
        y2="29"
        stroke="#000"
        stroke-width="4"
        stroke-linecap="round"
        transform="translate(1,1)"
      />
      <!-- Red Slash -->
      <line x1="3" y1="3" x2="29" y2="29" stroke="#FF0000" stroke-width="4" stroke-linecap="round" />
      <line x1="5" y1="4" x2="28" y2="27" stroke="#FF8080" stroke-width="1" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_mute(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_mute(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <rect x="12" y="3" width="10" height="15" rx="5" fill="#000" transform="translate(1,1)" />
      <rect
        x="12"
        y="3"
        width="10"
        height="15"
        rx="5"
        fill="#808080"
        stroke="#000"
        stroke-width="1.5"
      />

      <path
        d="M7 14 a 9 9 0 0 0 18 0"
        fill="none"
        stroke="#000"
        stroke-width="3"
        stroke-linecap="round"
        transform="translate(1,1)"
      />
      <line
        x1="16"
        y1="23"
        x2="16"
        y2="28"
        stroke="#000"
        stroke-width="3"
        stroke-linecap="round"
        transform="translate(1,1)"
      />
      <line
        x1="12"
        y1="28"
        x2="20"
        y2="28"
        stroke="#000"
        stroke-width="3"
        stroke-linecap="round"
        transform="translate(1,1)"
      />

      <path
        d="M7 14 a 9 9 0 0 0 18 0"
        fill="none"
        stroke="#606060"
        stroke-width="3"
        stroke-linecap="round"
      />
      <line x1="16" y1="23" x2="16" y2="28" stroke="#606060" stroke-width="3" stroke-linecap="round" />
      <line x1="12" y1="28" x2="20" y2="28" stroke="#606060" stroke-width="3" stroke-linecap="round" />
      
    <!-- Red Slash Shadow -->
      <line
        x1="5"
        y1="5"
        x2="27"
        y2="27"
        stroke="#000"
        stroke-width="4"
        stroke-linecap="round"
        transform="translate(1,1)"
      />
      <!-- Red Slash -->
      <line x1="5" y1="5" x2="27" y2="27" stroke="#FF0000" stroke-width="4" stroke-linecap="round" />
      <line x1="7" y1="6" x2="26" y2="25" stroke="#FF8080" stroke-width="1" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_phone_end(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_phone_end(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Shadow -->
      <path
        d="M6 18 C 6 8 26 8 26 18 L 19 23 L 15 16 C 15 16 17 16 17 16 L 21 16 C 21 12 11 12 11 16 C 11 16 13 16 13 16 L 17 23 L 6 18 z"
        fill="#000"
        transform="translate(1,1)"
        stroke-linejoin="round"
        stroke-linecap="round"
      />
      
    <!-- Base Phone (Red) -->
      <path
        d="M6 18 C 6 8 26 8 26 18 L 19 23 L 15 16 C 15 16 17 16 17 16 L 21 16 C 21 12 11 12 11 16 C 11 16 13 16 13 16 L 17 23 L 6 18 z"
        fill="#CC0000"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
        stroke-linecap="round"
      />
      
    <!-- Highlights -->
      <path
        d="M8 17 C 8 10 24 10 24 17"
        fill="none"
        stroke="#fff"
        stroke-width="1.5"
        opacity="0.6"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_pip(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_pip(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Main Monitor Shadow -->
      <rect x="2" y="4" width="28" height="22" rx="2" fill="#000" transform="translate(1,1)" />
      <!-- Main Monitor Base -->
      <rect x="2" y="4" width="28" height="22" rx="2" fill="#C0C0C0" stroke="#000" stroke-width="1.5" />
      <rect x="4" y="6" width="24" height="18" fill="#000080" stroke="#808080" stroke-width="1" />
      <rect
        x="2"
        y="4"
        width="28"
        height="22"
        rx="2"
        fill="none"
        stroke="#fff"
        stroke-width="1.5"
        stroke-dasharray="29 200"
        opacity="0.6"
      />
      
    <!-- Inner Square Shadow -->
      <rect x="16" y="14" width="10" height="8" rx="1" fill="#000" />
      <!-- Inner Square -->
      <rect x="15" y="13" width="10" height="8" rx="1" fill="#C0C0C0" stroke="#fff" stroke-width="1" />
      <rect x="16" y="14" width="8" height="6" fill="#008080" stroke="#808080" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_upgrade_video(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_upgrade_video(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Camera Base -->
      <rect x="4" y="8" width="18" height="16" rx="2" fill="#000080" stroke="#000" stroke-width="1.5" />
      <path
        d="M22 13 L 28 9 L 28 23 L 22 19 z"
        fill="#008080"
        stroke="#000"
        stroke-width="1.5"
        stroke-linejoin="round"
      />
      
    <!-- Arrow Badge Background Circle -->
      <circle cx="24" cy="8" r="7" fill="#000" transform="translate(1,1)" />
      <circle cx="24" cy="8" r="7" fill="#fff" stroke="#000" stroke-width="1.5" />
      
    <!-- Green Up Arrow -->
      <path
        d="M24 3 L 28 7 L 25 7 L 25 11 L 23 11 L 23 7 L 20 7 z"
        fill="#00FF00"
        stroke="#008000"
        stroke-width="1"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_devices(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_devices(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <!-- Phone Shadow -->
      <rect x="6" y="10" width="10" height="18" rx="2" fill="#000" transform="translate(1,1)" />
      <!-- Phone Base -->
      <rect
        x="6"
        y="10"
        width="10"
        height="18"
        rx="2"
        fill="#C0C0C0"
        stroke="#000"
        stroke-width="1.5"
      />
      <rect x="7" y="12" width="8" height="12" fill="#000080" />
      <circle cx="11" cy="26" r="1" fill="#555" />
      <path d="M6 12 L 16 12" stroke="#fff" stroke-width="1" />
      
    <!-- Signal Waves -->
      <path
        d="M19 12 C 21 14 21 18 19 20"
        fill="none"
        stroke="#000080"
        stroke-width="2"
        stroke-linecap="round"
      />
      <path
        d="M22 8 C 26 12 26 20 22 24"
        fill="none"
        stroke="#000080"
        stroke-width="2"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_quality_high(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_quality_high(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Minimalist shadow for 16x16 grid -->
      <rect x="3" y="12" width="3" height="4" fill="#555" />
      <rect x="7" y="8" width="3" height="8" fill="#555" />
      <rect x="11" y="4" width="3" height="12" fill="#555" />
      
    <!-- Crisp colored bars -->
      <rect x="2" y="11" width="3" height="4" fill="#00FF00" />
      <rect x="6" y="7" width="3" height="8" fill="#00FF00" />
      <rect x="10" y="3" width="3" height="12" fill="#00FF00" />
      
    <!-- Micro-highlight to give volume without clutter -->
      <line x1="2" y1="11" x2="4" y2="11" stroke="#fff" stroke-width="1" />
      <line x1="6" y1="7" x2="8" y2="7" stroke="#fff" stroke-width="1" />
      <line x1="10" y1="3" x2="12" y2="3" stroke="#fff" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_quality_medium(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_quality_medium(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="3" y="12" width="3" height="4" fill="#555" />
      <rect x="7" y="8" width="3" height="8" fill="#555" />
      <rect x="11" y="4" width="3" height="12" fill="#555" />

      <rect x="2" y="11" width="3" height="4" fill="#FFD700" />
      <rect x="6" y="7" width="3" height="8" fill="#FFD700" />
      <rect x="10" y="3" width="3" height="12" fill="#C0C0C0" stroke="#808080" stroke-width="1" />

      <line x1="2" y1="11" x2="4" y2="11" stroke="#fff" stroke-width="1" />
      <line x1="6" y1="7" x2="8" y2="7" stroke="#fff" stroke-width="1" />
      <line x1="11" y1="4" x2="12" y2="4" stroke="#fff" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_quality_low(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_quality_low(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="3" y="12" width="3" height="4" fill="#555" />
      <rect x="7" y="8" width="3" height="8" fill="#555" />
      <rect x="11" y="4" width="3" height="12" fill="#555" />

      <rect x="2" y="11" width="3" height="4" fill="#FF0000" />
      <rect x="6" y="7" width="3" height="8" fill="#C0C0C0" stroke="#808080" stroke-width="1" />
      <rect x="10" y="3" width="3" height="12" fill="#C0C0C0" stroke="#808080" stroke-width="1" />

      <line x1="2" y1="11" x2="4" y2="11" stroke="#fff" stroke-width="1" />
      <line x1="7" y1="8" x2="8" y2="8" stroke="#fff" stroke-width="1" />
      <line x1="11" y1="4" x2="12" y2="4" stroke="#fff" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_sound(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_sound(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <polygon points="3,7 5,7 8,4 8,14 5,11 3,11" fill="#000" />
      
    <!-- Speaker Body (White for dark bg) -->
      <polygon points="2,6 4,6 7,3 7,13 4,10 2,10" fill="#fff" stroke="#000" stroke-width="1" />
      
    <!-- Sound Waves (Gold) -->
      <path d="M10 5 V11 M12 3 V13 M14 1 V15" fill="none" stroke="#FFD700" stroke-width="1" />
      <!-- Shadow for waves -->
      <path d="M11 6 V12 M13 4 V14 M15 2 V16" fill="none" stroke="#000" stroke-width="1" />
    </svg>
    """
  end

  # -- Toolbar: Sounds --

  attr :class, :string, default: nil

  @spec icon_btn_sounds(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_sounds(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <path d="M2 6h2v-1h1v-1h1v-1h1v10H6v-1H5v-1H4v-1H2V6z" fill="#000080" />
      <path d="M11 5h1v6h-1V5z M13 3h1v10h-1V3z" fill="#FFD700" />
    </svg>
    """
  end

  # -- Button: Play (play triangle, 16×16) --

  attr :class, :string, default: nil

  @spec icon_btn_play(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_btn_play(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
      <!-- Shadow -->
      <polygon points="5,3 13,8 5,13" fill="#555" transform="translate(0.5,0.5)" />
      <!-- Play arrow -->
      <polygon points="5,3 13,8 5,13" fill="#009300" stroke="#000" stroke-width="1" stroke-linejoin="round" />
    </svg>
    """
  end
end
