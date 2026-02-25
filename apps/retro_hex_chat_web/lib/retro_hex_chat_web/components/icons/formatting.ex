defmodule RetroHexChatWeb.Icons.Formatting do
  @moduledoc """
  Icons for text formatting toolbar controls (bold, italic, underline, etc.).
  All icons use a 14×14 viewBox and `fill="currentColor"` for theme inheritance.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_fmt_bold(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_fmt_bold(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 14 14"
      shape-rendering="crispEdges"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M2 2h7v1h2v3h-2v1h3v4h-2v1H2z m3 2v2h3V4z m0 4v2h4V8z" fill-rule="evenodd" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_fmt_italic(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_fmt_italic(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 14 14"
      shape-rendering="crispEdges"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M5 1 h6 v2 h-1 v2 h-1 v2 h-1 v2 h-1 v2 h2 v2 h-6 v-2 h2 v-2 h1 v-2 h1 v-2 h1 v-2 h1 v-2 h-4 z" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_fmt_underline(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_fmt_underline(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 14 14"
      shape-rendering="crispEdges"
      fill="currentColor"
      aria-hidden="true"
    >
      <path d="M3 1h2v7h4V1h2v8H3z M2 11h10v2H2z" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_fmt_color(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_fmt_color(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="2" y="1" width="3" height="4" fill="#FF5555" />
      <rect x="5" y="1" width="4" height="4" fill="#55FF55" />
      <rect x="9" y="1" width="3" height="4" fill="#5555FF" />
      <rect x="2" y="5" width="3" height="4" fill="#FFFF55" />
      <rect x="5" y="5" width="4" height="4" fill="#FF55FF" />
      <rect x="9" y="5" width="3" height="4" fill="#55FFFF" />
      <rect x="2" y="10" width="10" height="3" fill="currentColor" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_fmt_reverse(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_fmt_reverse(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="1" y="1" width="6" height="12" fill="currentColor" />
      <rect x="7" y="1" width="6" height="12" fill="none" stroke="currentColor" stroke-width="1" />
      <path
        d="M3 4 h2 v1 h1 v2 h-1 v1 h1 v2 H5 V8 H4 v2 H3 V4 z M4 5 v2 h1 V5 H4 z"
        fill="var(--app-bg, #fff)"
      />
      <path
        d="M3 4 h2 v1 h1 v2 h-1 v1 h1 v2 H5 V8 H4 v2 H3 V4 z M4 5 v2 h1 V5 H4 z"
        fill="currentColor"
        transform="translate(6, 0)"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_fmt_reset(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_fmt_reset(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 14 14"
      shape-rendering="crispEdges"
      fill="currentColor"
      aria-hidden="true"
    >
      <!-- A -->
      <rect x="3" y="2" width="2" height="1" />
      <rect x="2" y="3" width="1" height="5" />
      <rect x="5" y="3" width="1" height="5" />
      <rect x="3" y="5" width="2" height="1" />
      <!-- a -->
      <rect x="8" y="4" width="2" height="1" />
      <rect x="10" y="5" width="1" height="4" />
      <rect x="8" y="6" width="2" height="1" />
      <rect x="7" y="7" width="1" height="1" />
      <rect x="8" y="8" width="3" height="1" />

      <path d="M 2 12 L 12 2" stroke="#FF5555" stroke-width="1.5" shape-rendering="auto" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_fmt_strip(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_fmt_strip(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 14 14"
      shape-rendering="crispEdges"
      fill="currentColor"
      aria-hidden="true"
    >
      <!-- Pixel Circle Outline -->
      <path
        d="M5 1h4v1h2v1h1v2h1v4h-1v2h-1v1h-2v1H5v-1H3v-1H2v-2H1V5h1V3h1V2h2V1zm0 2H4v1H3v2H2v2h1v2h1v1h4v-1h1V8h1V6h-1V4h-1V3H5z"
        fill-rule="evenodd"
      />
      <!-- Diagonal Slash -->
      <rect x="9" y="4" width="1" height="1" />
      <rect x="8" y="5" width="1" height="1" />
      <rect x="7" y="6" width="1" height="1" />
      <rect x="6" y="7" width="1" height="1" />
      <rect x="5" y="8" width="1" height="1" />
      <rect x="4" y="9" width="1" height="1" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_fmt_emoji(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_fmt_emoji(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 14 14"
      shape-rendering="crispEdges"
      fill="currentColor"
      aria-hidden="true"
    >
      <path
        d="M5 1h4v1h2v1h1v2h1v4h-1v2h-1v1h-2v1H5v-1H3v-1H2v-2H1V5h1V3h1V2h2V1zm0 1H4v1H3v2H2v4h1v2h1v1h4v-1h1v-2h1V5h-1V3h-1V2H5z"
        fill-rule="evenodd"
      />
      <!-- Eyes -->
      <rect x="4" y="4" width="2" height="2" />
      <rect x="8" y="4" width="2" height="2" />
      <!-- Mouth -->
      <rect x="4" y="8" width="1" height="1" />
      <rect x="9" y="8" width="1" height="1" />
      <rect x="5" y="9" width="4" height="1" />
    </svg>
    """
  end
end
