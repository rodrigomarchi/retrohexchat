defmodule RetroHexChatWeb.Icons.Media do
  @moduledoc """
  Icons depicting audio, video, and media device concepts.
  """
  use Phoenix.Component

  attr :class, :string, default: nil

  @spec icon_microphone(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_microphone(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" aria-hidden="true">
      <rect x="9" y="2" width="6" height="11" rx="3" fill="#000080" />
      <path
        d="M5 11a7 7 0 0 0 14 0"
        fill="none"
        stroke="#000080"
        stroke-width="1.8"
        stroke-linecap="round"
      />
      <line
        x1="12"
        y1="18"
        x2="12"
        y2="22"
        stroke="#000080"
        stroke-width="1.8"
        stroke-linecap="round"
      />
      <line x1="9" y1="22" x2="15" y2="22" stroke="#000080" stroke-width="1.8" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_camera(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_camera(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" aria-hidden="true">
      <rect x="2" y="5" width="14" height="13" rx="2" fill="#000080" />
      <path
        d="M16 9.5l5-3v11l-5-3z"
        fill="#008080"
        stroke="#000080"
        stroke-width="0.5"
        stroke-linejoin="round"
      />
      <circle cx="9" cy="11.5" r="2.5" fill="none" stroke="#fff" stroke-width="1.2" opacity="0.6" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_camera_off(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_camera_off(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" aria-hidden="true">
      <rect x="2" y="5" width="14" height="13" rx="2" fill="#808080" />
      <path d="M16 9.5l5-3v11l-5-3z" fill="#808080" stroke-linejoin="round" />
      <line x1="3" y1="3" x2="21" y2="21" stroke="#CC0000" stroke-width="2.5" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_mute(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_mute(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" aria-hidden="true">
      <rect x="9" y="2" width="6" height="11" rx="3" fill="#808080" />
      <path
        d="M5 11a7 7 0 0 0 14 0"
        fill="none"
        stroke="#808080"
        stroke-width="1.8"
        stroke-linecap="round"
      />
      <line
        x1="12"
        y1="18"
        x2="12"
        y2="22"
        stroke="#808080"
        stroke-width="1.8"
        stroke-linecap="round"
      />
      <line x1="9" y1="22" x2="15" y2="22" stroke="#808080" stroke-width="1.8" stroke-linecap="round" />
      <line x1="3" y1="3" x2="21" y2="21" stroke="#CC0000" stroke-width="2.5" stroke-linecap="round" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_phone_end(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_phone_end(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" aria-hidden="true">
      <path
        d="M12 9c-1.6 0-3.15.25-4.6.72v3.1c0 .39-.23.74-.56.9-.98.49-1.87 1.12-2.66 1.85-.18.18-.43.28-.7.28-.28 0-.53-.11-.71-.29L.29 13.08a.956.956 0 0 1 0-1.36C3.31 8.7 7.42 7 12 7s8.69 1.7 11.71 4.72c.18.18.29.44.29.71 0 .28-.11.53-.29.71l-2.48 2.48c-.18.18-.43.29-.71.29-.27 0-.52-.1-.7-.28a11.3 11.3 0 0 0-2.67-1.85.996.996 0 0 1-.56-.9v-3.1C15.15 9.25 13.6 9 12 9z"
        fill="#CC0000"
        stroke="#800000"
        stroke-width="0.5"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_pip(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_pip(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" aria-hidden="true">
      <rect x="2" y="4" width="20" height="16" rx="2" fill="none" stroke="#000080" stroke-width="1.8" />
      <rect x="12" y="11" width="9" height="7" rx="1" fill="#000080" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_upgrade_video(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_upgrade_video(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" aria-hidden="true">
      <rect x="2" y="5" width="14" height="13" rx="2" fill="#000080" />
      <path d="M16 9.5l5-3v11l-5-3z" fill="#008080" stroke-linejoin="round" />
      <circle cx="19" cy="6" r="4.5" fill="#fff" stroke="#008000" stroke-width="1.5" />
      <line
        x1="19"
        y1="3.5"
        x2="19"
        y2="8.5"
        stroke="#008000"
        stroke-width="1.5"
        stroke-linecap="round"
      />
      <line
        x1="16.5"
        y1="6"
        x2="21.5"
        y2="6"
        stroke="#008000"
        stroke-width="1.5"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_devices(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_devices(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" aria-hidden="true">
      <path d="M3 9v6h4l5 5V4L7 9H3z" fill="#000080" />
      <path
        d="M14 8.8c1.5 1.3 1.5 5.1 0 6.4"
        fill="none"
        stroke="#555"
        stroke-width="1.8"
        stroke-linecap="round"
      />
      <path
        d="M16.5 6c3 2.7 3 9.3 0 12"
        fill="none"
        stroke="#555"
        stroke-width="1.5"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_quality_high(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_quality_high(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" aria-hidden="true">
      <rect x="3" y="15" width="4" height="6" rx="1" fill="#008000" />
      <rect x="10" y="9" width="4" height="12" rx="1" fill="#008000" />
      <rect x="17" y="3" width="4" height="18" rx="1" fill="#008000" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_quality_medium(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_quality_medium(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" aria-hidden="true">
      <rect x="3" y="15" width="4" height="6" rx="1" fill="#B8860B" />
      <rect x="10" y="9" width="4" height="12" rx="1" fill="#B8860B" />
      <rect
        x="17"
        y="3"
        width="4"
        height="18"
        rx="1"
        fill="#C0C0C0"
        stroke="#808080"
        stroke-width="0.5"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_quality_low(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_quality_low(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" aria-hidden="true">
      <rect x="3" y="15" width="4" height="6" rx="1" fill="#CC0000" />
      <rect
        x="10"
        y="9"
        width="4"
        height="12"
        rx="1"
        fill="#C0C0C0"
        stroke="#808080"
        stroke-width="0.5"
      />
      <rect
        x="17"
        y="3"
        width="4"
        height="18"
        rx="1"
        fill="#C0C0C0"
        stroke="#808080"
        stroke-width="0.5"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_dialog_sound(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_sound(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" aria-hidden="true">
      <path d="M3 9v6h4l5 5V4L7 9H3z" fill="#555" stroke="#333" stroke-width="0.5" />
      <path
        d="M14 8.8c1.5 1.3 1.5 5.1 0 6.4"
        fill="none"
        stroke="#B8860B"
        stroke-width="1.8"
        stroke-linecap="round"
      />
      <path
        d="M16.5 6c3 2.7 3 9.3 0 12"
        fill="none"
        stroke="#B8860B"
        stroke-width="1.5"
        stroke-linecap="round"
      />
    </svg>
    """
  end
end
