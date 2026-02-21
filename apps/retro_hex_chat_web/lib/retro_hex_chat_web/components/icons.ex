defmodule RetroHexChatWeb.Icons do
  @moduledoc """
  Pixel-art SVG icons in the Windows 98 style for RetroHexChat.
  Each function renders an inline SVG with `aria-hidden="true"`.

  Color palette (matches toolbar.ex):
  - `#000` black outlines, `#fff` white highlights
  - `#000080` navy primary, `#008080` teal accent
  - `#808080` gray secondary, `#C0C0C0` silver fills
  - `#FFD700` gold alerts/accents, `#FF0000` red danger
  - `#008000` green success/active
  """
  use Phoenix.Component

  # ── 32x32 Desktop Icons ────────────────────────────────────

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

  @spec icon_lock(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_lock(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 32 32" aria-hidden="true">
      <path
        d="M10 14V10C10 6.7 12.7 4 16 4C19.3 4 22 6.7 22 10V14"
        fill="none"
        stroke="#555"
        stroke-width="2"
      />
      <rect x="8" y="14" width="16" height="14" rx="2" fill="#FFD700" stroke="#000" stroke-width="1" />
      <circle cx="16" cy="21" r="2" fill="#000" />
      <rect x="15" y="22" width="2" height="3" fill="#000" />
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

  # ── 16x16 Problem Icons ────────────────────────────────────

  attr :class, :string, default: nil

  @spec icon_ban(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_ban(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" fill="none" stroke="#FF0000" stroke-width="1.5" />
      <line x1="4" y1="4" x2="12" y2="12" stroke="#FF0000" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dollar(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dollar(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" fill="#FFD700" stroke="#000" stroke-width="1" />
      <text
        x="8"
        y="12"
        text-anchor="middle"
        font-size="10"
        font-weight="bold"
        font-family="sans-serif"
        fill="#000"
      >
        $
      </text>
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_globe_blocked(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_globe_blocked(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6" fill="none" stroke="#000080" stroke-width="1" />
      <ellipse cx="8" cy="8" rx="3" ry="6" fill="none" stroke="#000080" stroke-width="0.8" />
      <line x1="2" y1="8" x2="14" y2="8" stroke="#000080" stroke-width="0.8" />
      <line x1="3" y1="3" x2="13" y2="13" stroke="#FF0000" stroke-width="2" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_document_alert(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_document_alert(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="3" y="1" width="10" height="14" rx="1" fill="#fff" stroke="#000" stroke-width="1" />
      <line x1="5" y1="4" x2="11" y2="4" stroke="#000080" stroke-width="1" />
      <line x1="5" y1="6" x2="11" y2="6" stroke="#000080" stroke-width="1" />
      <line x1="5" y1="8" x2="9" y2="8" stroke="#000080" stroke-width="1" />
      <circle cx="11" cy="11" r="3" fill="#FFD700" stroke="#000" stroke-width="0.5" />
      <text
        x="11"
        y="13"
        text-anchor="middle"
        font-size="5"
        font-weight="bold"
        font-family="sans-serif"
        fill="#000"
      >
        !
      </text>
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

  # ── 16x16 Solution / How It Works / Feature Icons ──────────

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

  @spec icon_p2p(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_p2p(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="4" cy="8" r="2.5" fill="#000080" />
      <circle cx="12" cy="8" r="2.5" fill="#000080" />
      <line x1="6.5" y1="7" x2="9.5" y2="7" stroke="#008000" stroke-width="1.5" />
      <line x1="6.5" y1="9" x2="9.5" y2="9" stroke="#008000" stroke-width="1.5" />
      <polygon points="10,5.5 12,7 10,8.5" fill="#008000" />
      <polygon points="6,7.5 4,9 6,10.5" fill="#008000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_shield(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_shield(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M8 1L2 4v4c0 3.5 3 6 6 7 3-1 6-3.5 6-7V4z" fill="#000080" />
      <path d="M8 3L4 5.5v3c0 2.5 2 4.5 4 5.2 2-.7 4-2.7 4-5.2v-3z" fill="#fff" />
      <path d="M7 7.5l1.5 2L11 6" fill="none" stroke="#008000" stroke-width="1.5" />
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

  @spec icon_rules(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_rules(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="3" y="1" width="10" height="14" rx="1" fill="#fff" stroke="#000" stroke-width="1" />
      <rect x="5" y="3" width="2" height="2" fill="none" stroke="#000080" stroke-width="1" />
      <line x1="8" y1="4" x2="11" y2="4" stroke="#000080" stroke-width="1" />
      <rect x="5" y="7" width="2" height="2" fill="none" stroke="#000080" stroke-width="1" />
      <line x1="8" y1="8" x2="11" y2="8" stroke="#000080" stroke-width="1" />
      <rect x="5" y="11" width="2" height="2" fill="none" stroke="#000080" stroke-width="1" />
      <line x1="8" y1="12" x2="11" y2="12" stroke="#000080" stroke-width="1" />
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

  @spec icon_security(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_security(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M8 1L2 4v4c0 3.5 3 6 6 7 3-1 6-3.5 6-7V4z" fill="#000080" />
      <path d="M8 3L4 5.5v3c0 2.5 2 4.5 4 5.2 2-.7 4-2.7 4-5.2v-3z" fill="#fff" />
      <rect
        x="6.5"
        y="6"
        width="3"
        height="4"
        rx="0.5"
        fill="#FFD700"
        stroke="#000"
        stroke-width="0.5"
      />
      <path
        d="M7 6.5V5.5C7 4.7 7.4 4 8 4s1 .7 1 1.5V6.5"
        fill="none"
        stroke="#555"
        stroke-width="0.8"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_chat(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_chat(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M2 2h12v9H6l-3 3v-3H2z" fill="#000080" />
      <path d="M3 3h10v7H6l-2 2v-2H3z" fill="#fff" />
      <line x1="5" y1="5.5" x2="11" y2="5.5" stroke="#000080" stroke-width="1" />
      <line x1="5" y1="7.5" x2="9" y2="7.5" stroke="#000080" stroke-width="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_channels(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_channels(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="1" y="2" width="6" height="5" rx="0.5" fill="#000080" />
      <rect x="9" y="2" width="6" height="5" rx="0.5" fill="#008080" />
      <rect x="1" y="9" width="6" height="5" rx="0.5" fill="#008080" />
      <rect x="9" y="9" width="6" height="5" rx="0.5" fill="#000080" />
      <text x="4" y="6" text-anchor="middle" font-size="4" font-family="sans-serif" fill="#fff">
        #
      </text>
      <text x="12" y="6" text-anchor="middle" font-size="4" font-family="sans-serif" fill="#fff">
        #
      </text>
      <text x="4" y="13" text-anchor="middle" font-size="4" font-family="sans-serif" fill="#fff">
        #
      </text>
      <text x="12" y="13" text-anchor="middle" font-size="4" font-family="sans-serif" fill="#fff">
        #
      </text>
    </svg>
    """
  end

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

  @spec icon_checkmark(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_checkmark(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M3 8l3.5 4L13 4"
        fill="none"
        stroke="#008000"
        stroke-width="2.5"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_question(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_question(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="7" fill="#000080" />
      <text
        x="8"
        y="12"
        text-anchor="middle"
        font-size="11"
        font-weight="bold"
        font-family="sans-serif"
        fill="#fff"
      >
        ?
      </text>
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_warning(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_warning(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="8,1 15,14 1,14" fill="#FFD700" stroke="#000" stroke-width="0.8" />
      <text
        x="8"
        y="13"
        text-anchor="middle"
        font-size="9"
        font-weight="bold"
        font-family="sans-serif"
        fill="#000"
      >
        !
      </text>
    </svg>
    """
  end

  # ── 16x16 Open Source / Technology Icons ───────────────────

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

  @spec icon_websocket(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_websocket(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M2 8c2-4 4-4 6 0s4 4 6 0" fill="none" stroke="#008000" stroke-width="2" />
      <circle cx="2" cy="8" r="1.5" fill="#000080" />
      <circle cx="14" cy="8" r="1.5" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_webrtc(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_webrtc(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="2,4 7,4 7,12 2,12" fill="#000080" />
      <polygon points="7,6 11,4 11,12 7,10" fill="#008080" />
      <circle cx="13" cy="5" r="1.5" fill="#FF0000" />
      <circle cx="13" cy="11" r="0.8" fill="#FF0000" />
    </svg>
    """
  end

  # ── 16x16 Footer Icons ────────────────────────────────────

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

  @spec icon_legal(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_legal(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="7" y="2" width="2" height="10" fill="#555" />
      <line x1="3" y1="5" x2="13" y2="5" stroke="#555" stroke-width="1.5" />
      <circle cx="3" cy="7" r="1.5" fill="#FFD700" stroke="#000" stroke-width="0.5" />
      <circle cx="13" cy="7" r="1.5" fill="#FFD700" stroke="#000" stroke-width="0.5" />
      <rect x="5" y="12" width="6" height="2" rx="0.5" fill="#555" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_heart(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_heart(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M8 14s-5-3.5-5-7c0-2 1.5-3.5 3-3.5 1 0 1.7.5 2 1.3.3-.8 1-1.3 2-1.3 1.5 0 3 1.5 3 3.5 0 3.5-5 7-5 7z"
        fill="#FF0000"
      />
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

  # ── 16x16 Misc Icons ──────────────────────────────────────

  attr :class, :string, default: nil

  @spec icon_star(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_star(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon
        points="8,1 10,6 15,6.5 11,10 12.5,15 8,12 3.5,15 5,10 1,6.5 6,6"
        fill="#FFD700"
        stroke="#000"
        stroke-width="0.5"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_megaphone(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_megaphone(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="3,6 3,10 6,10 11,13 11,3 6,6" fill="#000080" />
      <rect x="11" y="6" width="3" height="1" fill="#FFD700" />
      <rect x="11" y="9" width="3" height="1" fill="#FFD700" />
      <rect x="12" y="7" width="2" height="2" fill="#FFD700" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_bug(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_bug(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <ellipse cx="8" cy="9" rx="3.5" ry="4.5" fill="#008000" />
      <circle cx="8" cy="5" r="2" fill="#008000" />
      <line x1="4" y1="7" x2="2" y2="5" stroke="#555" stroke-width="1" />
      <line x1="12" y1="7" x2="14" y2="5" stroke="#555" stroke-width="1" />
      <line x1="4.5" y1="10" x2="2" y2="11" stroke="#555" stroke-width="1" />
      <line x1="11.5" y1="10" x2="14" y2="11" stroke="#555" stroke-width="1" />
      <line x1="5" y1="4" x2="4" y2="2" stroke="#555" stroke-width="1" />
      <line x1="11" y1="4" x2="12" y2="2" stroke="#555" stroke-width="1" />
    </svg>
    """
  end

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

  # ── 16x16 P2P Lobby Icons ─────────────────────────────────

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

  @spec icon_microphone(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_microphone(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="6" y="2" width="4" height="7" rx="2" fill="#000080" />
      <path d="M4 8c0 2.2 1.8 4 4 4s4-1.8 4-4" fill="none" stroke="#555" stroke-width="1.2" />
      <line x1="8" y1="12" x2="8" y2="14" stroke="#555" stroke-width="1.2" />
      <line x1="6" y1="14" x2="10" y2="14" stroke="#555" stroke-width="1.2" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_camera(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_camera(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="1" y="4" width="10" height="8" rx="1" fill="#000080" stroke="#000" stroke-width="0.5" />
      <polygon points="11,6 15,4 15,12 11,10" fill="#008080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_phone_end(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_phone_end(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M1 7c0-1 2-3 7-3s7 2 7 3v2c0 .5-.5 1-1 1h-2c-.5 0-1-.5-1-1V8c-1-.3-2-.5-3-.5S6 7.7 5 8v1c0 .5-.5 1-1 1H2c-.5 0-1-.5-1-1z"
        fill="#FF0000"
        stroke="#000"
        stroke-width="0.5"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_mute(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_mute(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="6" y="2" width="4" height="7" rx="2" fill="#555" />
      <path d="M4 8c0 2.2 1.8 4 4 4s4-1.8 4-4" fill="none" stroke="#555" stroke-width="1.2" />
      <line x1="8" y1="12" x2="8" y2="14" stroke="#555" stroke-width="1.2" />
      <line x1="6" y1="14" x2="10" y2="14" stroke="#555" stroke-width="1.2" />
      <line x1="3" y1="3" x2="13" y2="13" stroke="#FF0000" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_camera_off(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_camera_off(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="1" y="4" width="10" height="8" rx="1" fill="#555" stroke="#000" stroke-width="0.5" />
      <polygon points="11,6 15,4 15,12 11,10" fill="#555" />
      <line x1="2" y1="3" x2="14" y2="13" stroke="#FF0000" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_devices(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_devices(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="2,5 2,13 6,11 6,7" fill="#000080" />
      <path d="M6 6c2-2 4-2 6 0 2 2 2 4 0 6" fill="none" stroke="#555" stroke-width="1" />
      <path d="M6 4c3-3 6-3 9 0 3 3 3 6 0 9" fill="none" stroke="#555" stroke-width="0.8" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_pip(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_pip(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="1" y="2" width="14" height="12" rx="1" fill="none" stroke="#000080" stroke-width="1.2" />
      <rect x="8" y="7" width="6" height="5" rx="0.5" fill="#000080" stroke="#000" stroke-width="0.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_upgrade_video(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_upgrade_video(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="1" y="4" width="9" height="8" rx="1" fill="#000080" stroke="#000" stroke-width="0.5" />
      <polygon points="10,6 14,4 14,12 10,10" fill="#008080" />
      <circle cx="13" cy="4" r="3" fill="#fff" stroke="#008000" stroke-width="0.8" />
      <line x1="13" y1="2.5" x2="13" y2="5.5" stroke="#008000" stroke-width="1.2" />
      <line x1="11.5" y1="4" x2="14.5" y2="4" stroke="#008000" stroke-width="1.2" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_close(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_close(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <line x1="4" y1="4" x2="12" y2="12" stroke="#000" stroke-width="2" stroke-linecap="round" />
      <line x1="12" y1="4" x2="4" y2="12" stroke="#000" stroke-width="2" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_send(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_send(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="2,2 14,8 2,14 4,8" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_accept(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_accept(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path
        d="M3 8l3.5 4L13 4"
        fill="none"
        stroke="#008000"
        stroke-width="2.5"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_reject(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_reject(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <line x1="4" y1="4" x2="12" y2="12" stroke="#FF0000" stroke-width="2.5" stroke-linecap="round" />
      <line x1="12" y1="4" x2="4" y2="12" stroke="#FF0000" stroke-width="2.5" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_clock(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_clock(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" fill="#fff" stroke="#555" stroke-width="1" />
      <line x1="8" y1="4" x2="8" y2="8" stroke="#000" stroke-width="1.2" />
      <line x1="8" y1="8" x2="11" y2="10" stroke="#000" stroke-width="1.2" />
      <circle cx="8" cy="8" r="0.8" fill="#000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_retry(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_retry(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M3 8a5 5 0 0 1 9-3" fill="none" stroke="#000080" stroke-width="1.5" />
      <polygon points="12,3 14,5 10,5" fill="#000080" />
      <path d="M13 8a5 5 0 0 1-9 3" fill="none" stroke="#000080" stroke-width="1.5" />
      <polygon points="4,13 2,11 6,11" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_cancel(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_cancel(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <circle cx="8" cy="8" r="6.5" fill="none" stroke="#FF0000" stroke-width="1.2" />
      <line x1="5" y1="5" x2="11" y2="11" stroke="#FF0000" stroke-width="1.5" />
      <line x1="11" y1="5" x2="5" y2="11" stroke="#FF0000" stroke-width="1.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_quality_high(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_quality_high(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="2" y="10" width="3" height="4" fill="#008000" />
      <rect x="6.5" y="6" width="3" height="8" fill="#008000" />
      <rect x="11" y="2" width="3" height="12" fill="#008000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_quality_medium(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_quality_medium(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="2" y="10" width="3" height="4" fill="#FFD700" />
      <rect x="6.5" y="6" width="3" height="8" fill="#FFD700" />
      <rect x="11" y="2" width="3" height="12" fill="#aaa" stroke="#888" stroke-width="0.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_quality_low(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_quality_low(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <rect x="2" y="10" width="3" height="4" fill="#FF0000" />
      <rect x="6.5" y="6" width="3" height="8" fill="#aaa" stroke="#888" stroke-width="0.5" />
      <rect x="11" y="2" width="3" height="12" fill="#aaa" stroke="#888" stroke-width="0.5" />
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

  @spec icon_privacy(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_privacy(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <path d="M8 1L2 4v4c0 3.5 3 6 6 7 3-1 6-3.5 6-7V4z" fill="#000080" />
      <path d="M8 3L4 5.5v3c0 2.5 2 4.5 4 5.2 2-.7 4-2.7 4-5.2v-3z" fill="#fff" />
      <rect
        x="6.5"
        y="6"
        width="3"
        height="4"
        rx="0.5"
        fill="#FFD700"
        stroke="#000"
        stroke-width="0.5"
      />
      <path
        d="M7 6.5V5.5C7 4.7 7.4 4 8 4s1 .7 1 1.5V6.5"
        fill="none"
        stroke="#555"
        stroke-width="0.8"
      />
    </svg>
    """
  end
end
