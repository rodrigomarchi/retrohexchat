defmodule RetroHexChatWeb.Components.UI.ActivityIndicator do
  @moduledoc """
  Compact loading/activity indicators for app shells and window islands.

  This intentionally avoids progress bars: most app waits here are indeterminate
  and short-lived, so the UI uses the project's icons plus a small pulsing status
  light.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  @doc "Small icon + pulsing-dot activity row."
  attr :text, :string, default: nil
  attr :label, :string, default: nil
  attr :icon, :atom, default: :hex
  attr :size, :string, default: "default", values: ~w(sm default lg)
  attr :variant, :string, default: "inline", values: ~w(inline panel)
  attr :class, :string, default: nil
  attr :text_attrs, :map, default: %{}
  attr :rest, :global

  @spec activity_indicator(map()) :: Phoenix.LiveView.Rendered.t()
  def activity_indicator(assigns) do
    assigns =
      assigns
      |> assign(:aria_label, assigns.label || assigns.text || dgettext("ui", "Loading"))
      |> assign(:show_text, is_binary(assigns.text) and assigns.text != "")

    ~H"""
    <div
      class={classes([indicator_class(@variant), size_gap(@size), @class])}
      role="status"
      aria-live="polite"
      aria-label={@aria_label}
      {@rest}
    >
      <span class={classes(["activity-indicator__icon", icon_box(@size)])} aria-hidden="true">
        <.activity_icon icon={@icon} class={icon_size(@size)} />
      </span>
      <span
        :if={@show_text}
        class={text_size(@size)}
        {@text_attrs}
      >
        {@text}
      </span>
      <span class="activity-indicator__dot" aria-hidden="true"></span>
    </div>
    """
  end

  @doc "Win98-style boot panel for app startup overlays."
  attr :title, :string, required: true
  attr :text, :string, required: true
  attr :icon, :atom, default: :hex
  attr :logo_src, :string, default: "/images/header-hex.svg"
  attr :class, :string, default: nil
  attr :text_attrs, :map, default: %{}
  attr :rest, :global

  @spec boot_activity_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def boot_activity_panel(assigns) do
    ~H"""
    <div
      class={classes(["shadow-retro-window bg-surface p-[3px]", @class])}
      role="status"
      aria-live="polite"
      aria-label={"#{@title}: #{@text}"}
      {@rest}
    >
      <div class="bg-title-bar flex items-center gap-1 px-[3px] py-[3px] text-xs font-bold text-white">
        <img src={@logo_src} alt="" class="h-4 w-4 shrink-0" />
        <span class="min-w-0 truncate">{@title}</span>
      </div>

      <div class="flex flex-col items-center gap-retro-10 p-retro-24 text-center">
        <img src={@logo_src} alt="" class="activity-indicator__brand h-12 w-12" />
        <div class="space-y-retro-4">
          <p class="text-sm font-bold leading-tight">{@title}</p>
          <.activity_indicator
            icon={@icon}
            text={@text}
            size="sm"
            class="justify-center"
            text_attrs={@text_attrs}
          />
        </div>
      </div>
    </div>
    """
  end

  attr :icon, :atom, required: true
  attr :class, :string, default: nil

  defp activity_icon(%{icon: :chat} = assigns), do: ~H"<Icons.icon_chat class={@class} />"
  defp activity_icon(%{icon: :channels} = assigns), do: ~H"<Icons.icon_channels class={@class} />"
  defp activity_icon(%{icon: :clock} = assigns), do: ~H"<Icons.icon_clock class={@class} />"
  defp activity_icon(%{icon: :file} = assigns), do: ~H"<Icons.icon_file_send class={@class} />"
  defp activity_icon(%{icon: :game} = assigns), do: ~H"<Icons.icon_joystick class={@class} />"
  defp activity_icon(%{icon: :media} = assigns), do: ~H"<Icons.icon_camera class={@class} />"

  defp activity_icon(%{icon: :p2p} = assigns),
    do: ~H"<Icons.icon_protocol_p2p_compact class={@class} />"

  defp activity_icon(%{icon: :status_signal} = assigns),
    do: ~H"<Icons.icon_status_signal class={@class} />"

  defp activity_icon(%{icon: :status_user} = assigns),
    do: ~H"<Icons.icon_status_user class={@class} />"

  defp activity_icon(assigns), do: ~H"<Icons.icon_hex_stone class={@class} />"

  defp indicator_class("panel"),
    do: "shadow-retro-field bg-white inline-flex items-center px-retro-8 py-retro-6"

  defp indicator_class(_), do: "inline-flex items-center"

  defp size_gap("sm"), do: "gap-retro-4"
  defp size_gap("lg"), do: "gap-retro-8"
  defp size_gap(_), do: "gap-retro-6"

  defp icon_box("sm"), do: "h-4 w-4"
  defp icon_box("lg"), do: "h-8 w-8"
  defp icon_box(_), do: "h-5 w-5"

  defp icon_size("sm"), do: "h-4 w-4"
  defp icon_size("lg"), do: "h-8 w-8"
  defp icon_size(_), do: "h-5 w-5"

  defp text_size("lg"), do: "text-sm"
  defp text_size(_), do: "text-xs"
end
