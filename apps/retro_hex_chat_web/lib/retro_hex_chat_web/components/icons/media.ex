defmodule RetroHexChatWeb.Icons.Media do
  @moduledoc """
  Icons depicting audio, video, and media device concepts.
  """
  use Phoenix.Component

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

  @spec icon_dialog_sound(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_dialog_sound(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
      <polygon points="2,5 5,5 9,2 9,14 5,11 2,11" fill="#fff" />
      <path
        d="M11 5.5c1 1 1 4 0 5"
        fill="none"
        stroke="#FFD700"
        stroke-width="1.2"
        stroke-linecap="round"
      />
      <path
        d="M13 3.5c1.8 2 1.8 7 0 9"
        fill="none"
        stroke="#FFD700"
        stroke-width="1.2"
        stroke-linecap="round"
      />
    </svg>
    """
  end
end
