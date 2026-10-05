defmodule RetroHexChatWeb.Components.UI.MediaSession.IconButton do
  @moduledoc """
  Shared icon-only action button for media-session surfaces.

  This component owns only visual button chrome and ARIA plumbing. Callers keep
  all events, state transitions, permissions, and feature-specific labels.

  Three looks share one contract:

    * `raised` — the classic bevelled button, for menus and panels.
    * `flat` — an IE-style toolbar button: no chrome at rest, the bevel rises
      under the pointer and sinks while pressed or active.
    * `dock` — the flat button drawn for the dark dock over the video; its
      chrome lives in `media-session-dock.css`.

  `caption` puts a short visible word beside the icon; the accessible name is
  still `label`.
  """
  use RetroHexChatWeb.Component

  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :pressed, :any, default: nil
  attr :tone, :string, values: ~w(default danger), default: "default"
  attr :variant, :string, values: ~w(raised flat dock), default: "raised"
  attr :caption, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled)

  slot :inner_block, required: true

  @spec media_session_icon_button(map()) :: Phoenix.LiveView.Rendered.t()
  def media_session_icon_button(assigns) do
    ~H"""
    <button
      type="button"
      title={@label}
      aria-label={@label}
      aria-pressed={media_session_aria_pressed(@pressed)}
      class={media_session_icon_button_class(@active, @tone, @class, @variant, @caption != nil)}
      {@rest}
    >
      {render_slot(@inner_block)}
      <span :if={@caption} class="media-session-icon-button__caption">{@caption}</span>
    </button>
    """
  end

  @spec media_session_icon_button_class(
          boolean(),
          String.t(),
          any(),
          String.t(),
          boolean()
        ) :: String.t()
  def media_session_icon_button_class(
        active?,
        tone,
        extra \\ nil,
        variant \\ "raised",
        captioned? \\ false
      )

  def media_session_icon_button_class(active?, tone, extra, "dock", captioned?),
    do: dock_button_class(active?, tone, extra, captioned?)

  def media_session_icon_button_class(active?, tone, extra, variant, captioned?) do
    classes([
      "inline-flex h-9 min-w-9 cursor-pointer items-center justify-center gap-1 border border-transparent p-0",
      !captioned? && "w-9",
      captioned? && "px-2 font-bold",
      "[&>svg]:h-6 [&>svg]:w-6 [&>svg]:shrink-0",
      variant == "raised" && "bg-surface shadow-retro-raised",
      variant == "flat" &&
        "bg-transparent shadow-none hover:shadow-retro-raised active:shadow-retro-sunken",
      active? && "bg-muted shadow-retro-sunken hover:shadow-retro-sunken",
      tone == "danger" && "bg-destructive text-destructive-foreground",
      tone == "danger" && variant == "flat" && "shadow-retro-raised",
      extra
    ])
  end

  defp dock_button_class(active?, tone, extra, captioned?) do
    classes([
      "media-dock-button",
      captioned? && "media-dock-button--captioned",
      active? && "media-dock-button--active",
      tone == "danger" && "media-dock-button--danger",
      extra
    ])
  end

  defp media_session_aria_pressed(nil), do: nil
  defp media_session_aria_pressed(value) when is_binary(value), do: value
  defp media_session_aria_pressed(value), do: to_string(value)
end
