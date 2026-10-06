defmodule RetroHexChatWeb.Components.UI.ToolButton do
  @moduledoc """
  The one icon-and-tool button of the interface: toolbars, rails, call docks,
  popover toggles and the small square controls inside panels.

  It owns the chrome only — bevel, pressed state, size, focus and disabled
  look — and leaves events, state and labels to the caller. Three looks share
  one contract:

    * `raised` — the classic bevelled button, for panels and menus.
    * `flat` — an IE-style toolbar button: no chrome at rest, the bevel rises
      under the pointer and sinks while pressed or active.
    * `dock` — the flat button drawn for the dark dock laid over a video or a
      canvas; its chrome lives in `media-session-dock.css`.

  `active` is the visual state (sunken) and `pressed` is what assistive tech
  hears (`aria-pressed`). They are separate on purpose: a microphone toggle is
  drawn sunken while it is *off* and announced as pressed while it is *on*.

  `label` is the tooltip and, unless the button names itself with visible
  text (`named_by_content`), the accessible name. `caption` adds a short
  visible word beside the icon.

  `tool_button_class/1` returns the same classes for elements that cannot be a
  `<button>` — a `<summary>` toggling a popover, a `<.link>` in a toolbar.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Components.UI.Chrome

  @variants ~w(raised flat dock)
  @tones ~w(default danger)
  @sizes ~w(title xs sm md lg)

  attr :label, :string, required: true, doc: "tooltip; also the accessible name"
  attr :active, :boolean, default: false, doc: "drawn sunken"
  attr :pressed, :any, default: nil, doc: "aria-pressed; nil leaves it off"
  attr :tone, :string, values: @tones, default: "default"
  attr :variant, :string, values: @variants, default: "raised"

  attr :size, :string,
    values: @sizes,
    default: "lg",
    doc: "title 16×14 (title-bar control) · xs 22px · sm 24px · md 34px · lg 36px"

  attr :caption, :string, default: nil, doc: "short visible word beside the icon"

  attr :named_by_content, :boolean,
    default: false,
    doc: "the visible content is the accessible name; label stays the tooltip"

  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(disabled form name value)

  slot :inner_block, required: true

  @spec tool_button(map()) :: Phoenix.LiveView.Rendered.t()
  def tool_button(assigns) do
    ~H"""
    <button
      type="button"
      title={@label}
      aria-label={!@named_by_content && @label}
      aria-pressed={aria_pressed(@pressed)}
      class={
        tool_button_class(
          variant: @variant,
          tone: @tone,
          size: @size,
          active: @active,
          captioned: @caption != nil,
          class: @class
        )
      }
      {@rest}
    >
      {render_slot(@inner_block)}
      <span :if={@caption} class="tool-button__caption">{@caption}</span>
    </button>
    """
  end

  @doc "A thin vertical divider between groups of tool buttons."
  attr :size, :string, values: ~w(sm md), default: "sm"
  attr :class, :any, default: nil

  @spec tool_separator(map()) :: Phoenix.LiveView.Rendered.t()
  def tool_separator(assigns) do
    ~H"""
    <span
      class={classes(["mx-[2px] w-[1px] shrink-0 bg-gray-500", separator_height(@size), @class])}
      aria-hidden="true"
    >
    </span>
    """
  end

  @doc """
  The classes of a tool button, for an element that is not a `<button>`.

  Options: `:variant`, `:tone`, `:size`, `:active` and `:captioned` as on the
  component, and `:class` for the caller's own additions.
  """
  @spec tool_button_class(keyword()) :: String.t()
  def tool_button_class(opts \\ []) do
    variant = Keyword.get(opts, :variant, "raised")
    tone = Keyword.get(opts, :tone, "default")
    size = Keyword.get(opts, :size, "lg")
    active? = Keyword.get(opts, :active, false)
    captioned? = Keyword.get(opts, :captioned, false)
    extra = Keyword.get(opts, :class)

    if variant == "dock" do
      dock_button_class(active?, tone, captioned?, extra)
    else
      chrome_button_class(variant, tone, size, active?, captioned?, extra)
    end
  end

  defp chrome_button_class(variant, tone, size, active?, captioned?, extra) do
    classes([
      "tool-button inline-flex shrink-0 cursor-pointer items-center justify-center border border-transparent p-0",
      "disabled:cursor-not-allowed disabled:hover:shadow-none",
      size_class(size, captioned?),
      variant == "raised" && Chrome.raised(),
      variant == "flat" && Chrome.flat(),
      active? && Chrome.active(),
      tone == "danger" && "bg-destructive text-destructive-foreground",
      tone == "danger" && variant == "flat" && !active? && "shadow-retro-raised",
      extra
    ])
  end

  defp dock_button_class(active?, tone, captioned?, extra) do
    classes([
      "media-dock-button",
      captioned? && "media-dock-button--captioned",
      active? && "media-dock-button--active",
      tone == "danger" && "media-dock-button--danger",
      extra
    ])
  end

  defp size_class("title", _captioned?),
    do: "h-[14px] min-h-[14px] w-[16px] min-w-[16px]"

  defp size_class("xs", captioned?),
    do: [
      "h-[22px] min-h-[22px] min-w-[22px] gap-[3px]",
      captioned? && "px-1",
      !captioned? && "w-[22px]"
    ]

  defp size_class("sm", captioned?),
    do: [
      "h-[24px] min-h-[24px] min-w-[24px] gap-1",
      captioned? && "px-1",
      !captioned? && "w-[24px]"
    ]

  defp size_class("md", captioned?),
    do: [
      "h-[34px] min-h-[34px] min-w-[34px] gap-1",
      captioned? && "px-2",
      !captioned? && "w-[34px]"
    ]

  defp size_class("lg", captioned?),
    do: [
      "h-9 min-w-9 gap-1 [&>svg]:h-6 [&>svg]:w-6 [&>svg]:shrink-0",
      captioned? && "px-2 font-bold",
      !captioned? && "w-9"
    ]

  defp separator_height("md"), do: "h-[24px]"
  defp separator_height(_sm), do: "h-[18px]"

  defp aria_pressed(nil), do: nil
  defp aria_pressed(value) when is_binary(value), do: value
  defp aria_pressed(value), do: to_string(value)
end
