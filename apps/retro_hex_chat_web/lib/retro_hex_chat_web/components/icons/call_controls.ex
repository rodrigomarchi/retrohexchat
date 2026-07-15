defmodule RetroHexChatWeb.Icons.CallControls do
  @moduledoc """
  64x64 SVG icon family for the P2P and conference video windows.

  These icons keep the platform palette and beveled Win95 geometry, but are
  drawn with more room than the legacy toolbar glyphs so they survive 32px
  rendering in dense call controls.
  """
  use Phoenix.Component

  attr :class, :string, default: nil
  slot :inner_block, required: true

  defp call_icon(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 64 64" shape-rendering="crispEdges" aria-hidden="true">
      {render_slot(@inner_block)}
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_microphone(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_microphone(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="24" y="6" width="19" height="34" rx="8" fill="#000" transform="translate(3,3)" />
      <rect x="24" y="6" width="19" height="34" rx="8" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <rect x="28" y="11" width="11" height="3" fill="#FFFFFF" />
      <rect x="27" y="18" width="13" height="3" fill="#808080" />
      <rect x="27" y="25" width="13" height="3" fill="#808080" />
      <rect x="29" y="32" width="9" height="3" fill="#808080" />
      <path d="M13 27 C13 44 54 44 54 27" fill="none" stroke="#000" stroke-width="8" />
      <path d="M13 27 C13 44 54 44 54 27" fill="none" stroke="#000080" stroke-width="5" />
      <rect x="30" y="45" width="7" height="10" fill="#000" transform="translate(3,3)" />
      <rect x="30" y="45" width="7" height="10" fill="#000080" stroke="#000" stroke-width="3" />
      <rect x="20" y="55" width="27" height="6" fill="#000" transform="translate(3,3)" />
      <rect x="20" y="55" width="27" height="6" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <rect x="23" y="56" width="20" height="2" fill="#FFFFFF" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_mute(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_mute(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="24" y="6" width="19" height="34" rx="8" fill="#000" transform="translate(3,3)" />
      <rect x="24" y="6" width="19" height="34" rx="8" fill="#808080" stroke="#000" stroke-width="3" />
      <rect x="28" y="11" width="11" height="3" fill="#DFDFDF" />
      <rect x="27" y="18" width="13" height="3" fill="#555555" />
      <rect x="27" y="25" width="13" height="3" fill="#555555" />
      <path d="M13 27 C13 44 54 44 54 27" fill="none" stroke="#000" stroke-width="8" />
      <path d="M13 27 C13 44 54 44 54 27" fill="none" stroke="#606060" stroke-width="5" />
      <rect x="30" y="45" width="7" height="10" fill="#606060" stroke="#000" stroke-width="3" />
      <rect x="20" y="55" width="27" height="6" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <path d="M9 10 L55 56" stroke="#000" stroke-width="10" />
      <path d="M9 10 L55 56" stroke="#FF0000" stroke-width="7" />
      <path d="M13 10 L55 52" stroke="#FF8080" stroke-width="2" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_camera(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_camera(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="7" y="17" width="35" height="30" rx="3" fill="#000" transform="translate(3,3)" />
      <path d="M43 24 L58 16 L58 49 L43 41 Z" fill="#000" transform="translate(3,3)" />
      <rect x="7" y="17" width="35" height="30" rx="3" fill="#000080" stroke="#000" stroke-width="3" />
      <rect x="12" y="22" width="24" height="20" fill="#101060" stroke="#000" stroke-width="2" />
      <rect x="9" y="19" width="31" height="3" fill="#FFFFFF" />
      <rect x="10" y="20" width="3" height="24" fill="#DFDFDF" />
      <path d="M43 24 L58 16 L58 49 L43 41 Z" fill="#008080" stroke="#000" stroke-width="3" />
      <path d="M45 25 L56 19" stroke="#00FFFF" stroke-width="2" />
      <rect x="15" y="25" width="8" height="8" fill="#FF0000" stroke="#000" stroke-width="2" />
      <rect x="17" y="26" width="2" height="2" fill="#FFFFFF" />
      <rect x="27" y="28" width="7" height="10" fill="#008080" stroke="#000" stroke-width="2" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_camera_off(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_camera_off(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="7" y="17" width="35" height="30" rx="3" fill="#000" transform="translate(3,3)" />
      <path d="M43 24 L58 16 L58 49 L43 41 Z" fill="#000" transform="translate(3,3)" />
      <rect x="7" y="17" width="35" height="30" rx="3" fill="#808080" stroke="#000" stroke-width="3" />
      <rect x="12" y="22" width="24" height="20" fill="#555555" stroke="#000" stroke-width="2" />
      <path d="M43 24 L58 16 L58 49 L43 41 Z" fill="#606060" stroke="#000" stroke-width="3" />
      <rect x="15" y="25" width="8" height="8" fill="#555555" stroke="#000" stroke-width="2" />
      <path d="M7 8 L57 58" stroke="#000" stroke-width="10" />
      <path d="M7 8 L57 58" stroke="#FF0000" stroke-width="7" />
      <path d="M11 8 L57 54" stroke="#FF8080" stroke-width="2" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_screen_share(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_screen_share(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="8" y="9" width="45" height="34" fill="#000" transform="translate(3,3)" />
      <rect x="8" y="9" width="45" height="34" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <rect x="13" y="14" width="35" height="23" fill="#000080" stroke="#000" stroke-width="2" />
      <rect x="15" y="16" width="31" height="5" fill="#008080" />
      <rect x="15" y="22" width="31" height="13" fill="#101060" />
      <rect x="27" y="43" width="8" height="9" fill="#808080" stroke="#000" stroke-width="2" />
      <rect x="18" y="52" width="27" height="6" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <path d="M31 20 L45 34 H37 V47 H25 V34 H17 Z" fill="#FFD700" stroke="#000" stroke-width="3" />
      <rect x="29" y="28" width="5" height="15" fill="#000080" />
      <rect x="23" y="33" width="17" height="5" fill="#000080" />
      <rect x="13" y="14" width="35" height="2" fill="#FFFFFF" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_phone_end(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_phone_end(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <path
        d="M9 35 C9 13 55 13 55 35 L41 47 L34 33 H30 L23 47 Z"
        fill="#000"
        transform="translate(3,3)"
      />
      <path
        d="M9 35 C9 13 55 13 55 35 L41 47 L34 33 H30 L23 47 Z"
        fill="#CC0000"
        stroke="#000"
        stroke-width="4"
      />
      <path d="M14 34 C14 19 50 19 50 34" fill="none" stroke="#FFFFFF" stroke-width="3" />
      <rect x="22" y="34" width="7" height="7" fill="#800000" />
      <rect x="35" y="34" width="7" height="7" fill="#800000" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_pip(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_pip(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="6" y="9" width="52" height="40" fill="#000" transform="translate(3,3)" />
      <rect x="6" y="9" width="52" height="40" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <rect x="11" y="14" width="42" height="29" fill="#000080" stroke="#000" stroke-width="2" />
      <rect x="13" y="16" width="38" height="5" fill="#008080" />
      <rect x="31" y="27" width="18" height="13" fill="#000" transform="translate(2,2)" />
      <rect x="31" y="27" width="18" height="13" fill="#C0C0C0" stroke="#FFFFFF" stroke-width="2" />
      <rect x="34" y="30" width="12" height="7" fill="#008080" stroke="#000" stroke-width="2" />
      <rect x="6" y="9" width="52" height="3" fill="#FFFFFF" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_devices(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_devices(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="8" y="20" width="19" height="34" rx="3" fill="#000" transform="translate(3,3)" />
      <rect x="8" y="20" width="19" height="34" rx="3" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <rect x="12" y="26" width="11" height="20" fill="#000080" />
      <rect x="14" y="28" width="7" height="4" fill="#008080" />
      <rect x="15" y="49" width="5" height="2" fill="#555555" />
      <rect x="33" y="12" width="22" height="16" fill="#000" transform="translate(3,3)" />
      <rect x="33" y="12" width="22" height="16" fill="#000080" stroke="#000" stroke-width="3" />
      <path d="M39 41 C46 35 46 24 39 18" fill="none" stroke="#000" stroke-width="8" />
      <path d="M39 41 C46 35 46 24 39 18" fill="none" stroke="#000080" stroke-width="5" />
      <path d="M48 49 C60 38 60 20 48 9" fill="none" stroke="#000" stroke-width="8" />
      <path d="M48 49 C60 38 60 20 48 9" fill="none" stroke="#008080" stroke-width="5" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_layout_auto(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_layout_auto(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="9" y="9" width="46" height="37" fill="#000" transform="translate(3,3)" />
      <rect x="9" y="9" width="46" height="37" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <rect x="14" y="14" width="36" height="27" fill="#000080" stroke="#000" stroke-width="2" />
      <rect x="17" y="17" width="13" height="9" fill="#008080" stroke="#000" stroke-width="2" />
      <rect x="34" y="17" width="13" height="9" fill="#FFD700" stroke="#000" stroke-width="2" />
      <rect x="17" y="30" width="30" height="8" fill="#101060" stroke="#000" stroke-width="2" />
      <path d="M18 52 H29 V56 H12 V39 H16 V49 H18 Z" fill="#FFFFFF" stroke="#000" stroke-width="2" />
      <path d="M46 12 H35 V8 H52 V25 H48 V15 H46 Z" fill="#FFFFFF" stroke="#000" stroke-width="2" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_layout_focus(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_layout_focus(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="8" y="9" width="48" height="40" fill="#000" transform="translate(3,3)" />
      <rect x="8" y="9" width="48" height="40" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <rect x="13" y="14" width="38" height="30" fill="#000080" stroke="#000" stroke-width="2" />
      <rect x="18" y="19" width="20" height="15" fill="#008080" stroke="#000" stroke-width="2" />
      <rect x="41" y="32" width="10" height="9" fill="#FFD700" stroke="#000" stroke-width="2" />
      <path d="M5 28 H17 V33 H5 Z" fill="#FFFFFF" stroke="#000" stroke-width="2" />
      <path d="M47 28 H59 V33 H47 Z" fill="#FFFFFF" stroke="#000" stroke-width="2" />
      <path d="M30 3 H35 V15 H30 Z" fill="#FFFFFF" stroke="#000" stroke-width="2" />
      <path d="M30 45 H35 V58 H30 Z" fill="#FFFFFF" stroke="#000" stroke-width="2" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_layout_split(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_layout_split(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="7" y="11" width="22" height="40" fill="#000" transform="translate(3,3)" />
      <rect x="35" y="11" width="22" height="40" fill="#000" transform="translate(3,3)" />
      <rect x="7" y="11" width="22" height="40" fill="#000080" stroke="#000" stroke-width="3" />
      <rect x="35" y="11" width="22" height="40" fill="#008080" stroke="#000" stroke-width="3" />
      <rect x="12" y="17" width="12" height="28" fill="#101060" />
      <rect x="40" y="17" width="12" height="28" fill="#005F5F" />
      <rect x="7" y="11" width="22" height="3" fill="#FFFFFF" />
      <rect x="35" y="11" width="22" height="3" fill="#FFFFFF" />
      <rect x="30" y="12" width="4" height="38" fill="#C0C0C0" stroke="#000" stroke-width="1" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_layout_speaker(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_layout_speaker(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="8" y="11" width="36" height="32" fill="#000" transform="translate(3,3)" />
      <rect x="8" y="11" width="36" height="32" fill="#000080" stroke="#000" stroke-width="3" />
      <rect x="13" y="16" width="26" height="22" fill="#101060" />
      <rect x="47" y="13" width="10" height="8" fill="#008080" stroke="#000" stroke-width="2" />
      <rect x="47" y="25" width="10" height="8" fill="#C0C0C0" stroke="#000" stroke-width="2" />
      <rect x="47" y="37" width="10" height="8" fill="#C0C0C0" stroke="#000" stroke-width="2" />
      <rect x="22" y="24" width="10" height="16" rx="4" fill="#C0C0C0" stroke="#000" stroke-width="2" />
      <path d="M16 31 C16 43 38 43 38 31" fill="none" stroke="#FFD700" stroke-width="4" />
      <rect x="25" y="43" width="5" height="8" fill="#FFD700" stroke="#000" stroke-width="2" />
      <rect x="19" y="51" width="17" height="4" fill="#C0C0C0" stroke="#000" stroke-width="2" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_layout_compact(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_layout_compact(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="10" y="12" width="44" height="36" fill="#000" transform="translate(3,3)" />
      <rect x="10" y="12" width="44" height="36" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <rect x="15" y="17" width="34" height="26" fill="#000080" stroke="#000" stroke-width="2" />
      <rect x="20" y="22" width="24" height="16" fill="#101060" />
      <path d="M22 10 H6 V26 H11 V18 H22 Z" fill="#FFFFFF" stroke="#000" stroke-width="2" />
      <path d="M42 54 H58 V38 H53 V46 H42 Z" fill="#FFFFFF" stroke="#000" stroke-width="2" />
      <rect x="16" y="18" width="31" height="3" fill="#008080" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_self_view(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_self_view(assigns), do: icon_call_pip(assigns)

  attr :class, :string, default: nil

  @spec icon_call_stats(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_stats(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="9" y="11" width="46" height="40" fill="#000" transform="translate(3,3)" />
      <rect x="9" y="11" width="46" height="40" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <rect x="14" y="16" width="36" height="30" fill="#000080" stroke="#000" stroke-width="2" />
      <rect x="18" y="35" width="6" height="8" fill="#00FF00" stroke="#000" stroke-width="2" />
      <rect x="28" y="28" width="6" height="15" fill="#FFD700" stroke="#000" stroke-width="2" />
      <rect x="38" y="21" width="6" height="22" fill="#FF0000" stroke="#000" stroke-width="2" />
      <rect x="17" y="19" width="28" height="3" fill="#008080" />
      <rect x="17" y="25" width="18" height="2" fill="#DFDFDF" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_mini(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_mini(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="9" y="12" width="46" height="38" fill="#000" transform="translate(3,3)" />
      <rect x="9" y="12" width="46" height="38" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <rect x="14" y="17" width="36" height="27" fill="#000080" stroke="#000" stroke-width="2" />
      <rect x="18" y="37" width="24" height="5" fill="#FFD700" stroke="#000" stroke-width="2" />
      <rect x="9" y="12" width="46" height="4" fill="#FFFFFF" />
      <rect x="45" y="16" width="7" height="7" fill="#808080" stroke="#000" stroke-width="2" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_expand(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_expand(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="9" y="12" width="46" height="38" fill="#000" transform="translate(3,3)" />
      <rect x="9" y="12" width="46" height="38" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <rect x="14" y="17" width="36" height="27" fill="#000080" stroke="#000" stroke-width="2" />
      <path d="M18 20 H31 V25 H23 V33 H18 Z" fill="#FFFFFF" stroke="#000" stroke-width="2" />
      <path d="M46 41 H33 V36 H41 V28 H46 Z" fill="#FFFFFF" stroke="#000" stroke-width="2" />
      <rect x="9" y="12" width="46" height="4" fill="#FFFFFF" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_webrtc(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_webrtc(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <circle cx="20" cy="25" r="9" fill="#000" transform="translate(3,3)" />
      <circle cx="44" cy="25" r="9" fill="#000" transform="translate(3,3)" />
      <circle cx="32" cy="45" r="9" fill="#000" transform="translate(3,3)" />
      <path d="M20 25 H44 L32 45 Z" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <circle cx="20" cy="25" r="9" fill="#000080" stroke="#000" stroke-width="3" />
      <circle cx="44" cy="25" r="9" fill="#008080" stroke="#000" stroke-width="3" />
      <circle cx="32" cy="45" r="9" fill="#FFD700" stroke="#000" stroke-width="3" />
      <rect x="17" y="22" width="6" height="6" fill="#FFFFFF" />
      <rect x="41" y="22" width="6" height="6" fill="#FFFFFF" />
      <rect x="29" y="42" width="6" height="6" fill="#000080" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_reactions(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_reactions(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="7" y="13" width="40" height="30" fill="#000" transform="translate(3,3)" />
      <rect x="7" y="13" width="40" height="30" fill="#FFFFCC" stroke="#000" stroke-width="3" />
      <path d="M18 43 L15 55 L28 43 Z" fill="#FFFFCC" stroke="#000" stroke-width="3" />
      <path
        d="M44 16 L51 10 L52 21 L61 24 L52 28 L51 39 L44 33 L34 36 L38 27 L34 18 Z"
        fill="#FFD700"
        stroke="#000"
        stroke-width="3"
      />
      <rect x="16" y="23" width="7" height="7" fill="#FF0000" stroke="#000" stroke-width="2" />
      <rect x="29" y="23" width="7" height="7" fill="#000080" stroke="#000" stroke-width="2" />
      <rect x="17" y="34" width="18" height="4" fill="#008000" stroke="#000" stroke-width="2" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_more(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_more(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="9" y="13" width="46" height="38" fill="#000" transform="translate(3,3)" />
      <rect x="9" y="13" width="46" height="38" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <rect x="13" y="17" width="38" height="7" fill="#000080" />
      <rect x="45" y="19" width="4" height="3" fill="#FFFFFF" />
      <rect x="17" y="30" width="8" height="8" fill="#000080" stroke="#000" stroke-width="2" />
      <rect x="28" y="30" width="8" height="8" fill="#008080" stroke="#000" stroke-width="2" />
      <rect x="39" y="30" width="8" height="8" fill="#FFD700" stroke="#000" stroke-width="2" />
      <rect x="17" y="41" width="30" height="4" fill="#808080" stroke="#000" stroke-width="2" />
      <rect x="13" y="17" width="38" height="2" fill="#FFFFFF" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_raise_hand(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_raise_hand(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="19" y="10" width="8" height="27" fill="#000" transform="translate(3,3)" />
      <rect x="27" y="6" width="8" height="32" fill="#000" transform="translate(3,3)" />
      <rect x="35" y="13" width="8" height="27" fill="#000" transform="translate(3,3)" />
      <rect x="43" y="21" width="8" height="20" fill="#000" transform="translate(3,3)" />
      <rect x="12" y="29" width="14" height="13" fill="#000" transform="translate(3,3)" />
      <rect x="16" y="39" width="34" height="16" fill="#000" transform="translate(3,3)" />
      <rect x="19" y="10" width="8" height="27" fill="#FFD700" stroke="#000" stroke-width="2" />
      <rect x="27" y="6" width="8" height="32" fill="#FFD700" stroke="#000" stroke-width="2" />
      <rect x="35" y="13" width="8" height="27" fill="#FFD700" stroke="#000" stroke-width="2" />
      <rect x="43" y="21" width="8" height="20" fill="#FFD700" stroke="#000" stroke-width="2" />
      <rect x="12" y="29" width="14" height="13" fill="#FFD700" stroke="#000" stroke-width="2" />
      <rect x="16" y="39" width="34" height="16" fill="#FFD700" stroke="#000" stroke-width="2" />
      <rect x="21" y="12" width="2" height="21" fill="#FFFFFF" />
      <rect x="29" y="8" width="2" height="24" fill="#FFFFFF" />
      <rect x="18" y="56" width="30" height="5" fill="#C0C0C0" stroke="#000" stroke-width="2" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_participants(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_participants(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <circle cx="24" cy="19" r="8" fill="#000" transform="translate(3,3)" />
      <circle cx="24" cy="19" r="8" fill="#FFD700" stroke="#000" stroke-width="3" />
      <path d="M10 47 C10 33 38 33 38 47 Z" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <circle cx="44" cy="23" r="7" fill="#000" transform="translate(3,3)" />
      <circle cx="44" cy="23" r="7" fill="#008080" stroke="#000" stroke-width="3" />
      <path d="M31 50 C31 39 57 39 57 50 Z" fill="#000080" stroke="#000" stroke-width="3" />
      <rect x="17" y="17" width="4" height="3" fill="#000" />
      <rect x="27" y="17" width="4" height="3" fill="#000" />
      <rect x="40" y="22" width="3" height="3" fill="#FFFFFF" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_lock(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_lock(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <path
        d="M32 5 L53 14 V29 C53 44 44 54 32 59 C20 54 11 44 11 29 V14 Z"
        fill="#000"
        transform="translate(3,3)"
      />
      <path
        d="M32 5 L53 14 V29 C53 44 44 54 32 59 C20 54 11 44 11 29 V14 Z"
        fill="#000080"
        stroke="#000"
        stroke-width="3"
      />
      <path
        d="M18 17 L32 11 L46 17 V29 C46 40 40 48 32 52 C24 48 18 40 18 29 Z"
        fill="#008080"
        stroke="#FFFFFF"
        stroke-width="2"
      />
      <rect x="22" y="31" width="20" height="15" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <path d="M26 31 V25 C26 17 38 17 38 25 V31" fill="none" stroke="#000" stroke-width="5" />
      <rect x="30" y="37" width="4" height="6" fill="#000080" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_close(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_close(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="11" y="11" width="42" height="42" fill="#000" transform="translate(3,3)" />
      <rect x="11" y="11" width="42" height="42" fill="#C0C0C0" stroke="#000" stroke-width="3" />
      <rect x="15" y="15" width="34" height="8" fill="#000080" />
      <rect x="41" y="17" width="6" height="4" fill="#C0C0C0" stroke="#FFFFFF" stroke-width="1" />
      <path
        d="M20 27 L27 20 L32 25 L37 20 L44 27 L39 32 L44 37 L37 44 L32 39 L27 44 L20 37 L25 32 Z"
        fill="#000"
        transform="translate(2,2)"
      />
      <path
        d="M20 27 L27 20 L32 25 L37 20 L44 27 L39 32 L44 37 L37 44 L32 39 L27 44 L20 37 L25 32 Z"
        fill="#FF0000"
        stroke="#000"
        stroke-width="3"
      />
      <rect x="24" y="24" width="5" height="4" fill="#FF8080" />
      <rect x="35" y="35" width="5" height="4" fill="#800000" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_reaction_heart(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_reaction_heart(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <rect x="15" y="16" width="12" height="8" fill="#000" transform="translate(3,3)" />
      <rect x="37" y="16" width="12" height="8" fill="#000" transform="translate(3,3)" />
      <path
        d="M32 54 L10 31 V20 H16 V14 H27 V20 H37 V14 H48 V20 H54 V31 Z"
        fill="#000"
        transform="translate(3,3)"
      />
      <path
        d="M32 54 L10 31 V20 H16 V14 H27 V20 H37 V14 H48 V20 H54 V31 Z"
        fill="#FF0000"
        stroke="#000"
        stroke-width="3"
      />
      <rect x="17" y="18" width="8" height="5" fill="#FF8080" />
      <rect x="39" y="18" width="8" height="5" fill="#FF8080" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_reaction_thumbs_up(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_reaction_thumbs_up(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <path
        d="M25 51 H12 V28 H24 L30 12 H40 V27 H53 V35 L49 51 Z"
        fill="#000"
        transform="translate(3,3)"
      />
      <path
        d="M25 51 H12 V28 H24 L30 12 H40 V27 H53 V35 L49 51 Z"
        fill="#FFD700"
        stroke="#000"
        stroke-width="3"
      />
      <rect x="14" y="31" width="9" height="17" fill="#C0C0C0" stroke="#000" stroke-width="2" />
      <rect x="31" y="16" width="5" height="13" fill="#FFFFFF" />
      <rect x="39" y="31" width="11" height="3" fill="#FFFFFF" />
      <rect x="38" y="39" width="10" height="3" fill="#808080" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_reaction_clap(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_reaction_clap(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <path d="M18 53 L8 26 L18 22 L28 48 Z" fill="#000" transform="translate(3,3)" />
      <path d="M40 53 L28 20 L39 16 L52 49 Z" fill="#000" transform="translate(3,3)" />
      <path d="M18 53 L8 26 L18 22 L28 48 Z" fill="#FFD700" stroke="#000" stroke-width="3" />
      <path d="M40 53 L28 20 L39 16 L52 49 Z" fill="#FFD700" stroke="#000" stroke-width="3" />
      <rect x="13" y="27" width="3" height="19" fill="#FFFFFF" />
      <rect x="34" y="22" width="3" height="24" fill="#FFFFFF" />
      <path d="M13 12 L20 18 M31 6 L32 15 M51 13 L44 20" stroke="#000080" stroke-width="4" />
      <path d="M14 11 L21 17 M32 5 L33 14 M52 12 L45 19" stroke="#FFD700" stroke-width="2" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_reaction_laugh(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_reaction_laugh(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <circle cx="32" cy="32" r="24" fill="#000" transform="translate(3,3)" />
      <circle cx="32" cy="32" r="24" fill="#FFD700" stroke="#000" stroke-width="3" />
      <rect x="21" y="24" width="8" height="5" fill="#000" />
      <rect x="36" y="24" width="8" height="5" fill="#000" />
      <path d="M18 36 H46 V43 C46 51 18 51 18 43 Z" fill="#000" />
      <rect x="21" y="38" width="22" height="5" fill="#FFFFFF" />
      <rect x="23" y="43" width="18" height="5" fill="#FF8080" />
      <rect x="13" y="16" width="5" height="8" fill="#00FFFF" stroke="#000" stroke-width="2" />
      <rect x="47" y="16" width="5" height="8" fill="#00FFFF" stroke="#000" stroke-width="2" />
    </.call_icon>
    """
  end

  attr :class, :string, default: nil

  @spec icon_call_reaction_sparkle(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_call_reaction_sparkle(assigns) do
    ~H"""
    <.call_icon class={@class}>
      <path
        d="M32 5 L39 24 L59 31 L40 39 L32 59 L24 40 L5 32 L24 24 Z"
        fill="#000"
        transform="translate(3,3)"
      />
      <path
        d="M32 5 L39 24 L59 31 L40 39 L32 59 L24 40 L5 32 L24 24 Z"
        fill="#FFD700"
        stroke="#000"
        stroke-width="3"
      />
      <path
        d="M32 15 L36 27 L49 31 L36 35 L32 49 L28 35 L15 32 L28 27 Z"
        fill="#FFFFFF"
        stroke="#000080"
        stroke-width="2"
      />
      <rect x="48" y="8" width="6" height="6" fill="#00FFFF" stroke="#000" stroke-width="2" />
      <rect x="9" y="47" width="7" height="7" fill="#FF0000" stroke="#000" stroke-width="2" />
    </.call_icon>
    """
  end
end
