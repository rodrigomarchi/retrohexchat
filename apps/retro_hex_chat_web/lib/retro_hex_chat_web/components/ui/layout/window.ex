defmodule RetroHexChatWeb.Components.UI.Window do
  @moduledoc false
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ToolButton

  import RetroHexChatWeb.Components.UI.Space.PixelIcon

  alias RetroHexChatWeb.Icons

  # `retro` is the Win98 chrome every window wears. `pixel` is the Virtual
  # Space's wood-and-gold frame, drawn by `features/space-ui.css` inside a
  # `.space-ui` page only. `device` is a program that is its own appliance —
  # Hex Radio — with no Win98 frame, only a thin dark title strip
  # (`features/hex-radio.css`).
  @skins ~w(retro pixel device)

  @doc """
  Renders a window frame: Win98's, the space's pixel-art one (`skin="pixel"`)
  or an appliance's (`skin="device"`).
  """
  attr :skin, :string, values: @skins, default: "retro"
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec window(map()) :: Phoenix.LiveView.Rendered.t()
  def window(assigns) do
    ~H"""
    <div
      class={
        classes([
          frame_class(@skin),
          "flex flex-col",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders a title bar with its control buttons, in the window's skin."
  attr :skin, :string, values: @skins, default: "retro"
  attr :title, :string, required: true
  attr :inactive, :boolean, default: false

  attr :controls, :list,
    default: [:minimize, :maximize, :close],
    doc:
      "control buttons, in order. A :restore control renders hidden — pair it with " <>
        ":maximize under the WindowManagerHook, which shows exactly one of the two"

  attr :on_close, :any, default: nil, doc: "Close button callback (wired to :close control)"
  attr :close_target, :string, default: nil, doc: "CSS selector for static close behavior"

  attr :force_close, :boolean,
    default: true,
    doc: "When true, always append a :close control. Set false for pinned/non-closable windows."

  attr :class, :any, default: nil
  attr :rest, :global

  slot :icon, required: true, doc: "16×16 title bar icon — mandatory for Win98 consistency"

  slot :meta,
    doc:
      "Live status shown after the title, for windows whose subject has a connection state. " <>
        "Hidden below sm: a narrow title bar has no room for it, and the status bar repeats it."

  @spec window_title_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def window_title_bar(assigns) do
    assigns = assign(assigns, :controls, ensure_close(assigns.controls, assigns.force_close))

    ~H"""
    <div
      class={
        classes([
          "flex justify-between items-center",
          title_bar_class(@skin, @inactive),
          @class
        ])
      }
      {@rest}
    >
      <div class="flex items-center gap-1 min-w-0">
        <span class="flex-shrink-0 w-[16px] h-[16px] inline-flex items-center justify-center">
          {render_slot(@icon)}
        </span>
        <span class={[
          title_class(@skin),
          "truncate",
          @meta == [] && "mr-6"
        ]}>
          {@title}
        </span>
        <span
          :if={@meta != []}
          class="window-title-meta hidden sm:flex min-w-0 items-center gap-2 mr-6 text-[10px] leading-3 text-white"
        >
          {render_slot(@meta)}
        </span>
      </div>
      <div class="flex flex-shrink-0">
        <.tool_button
          :for={control <- @controls}
          label={control_label(control)}
          variant={control_variant(@skin)}
          size="title"
          disabled={@inactive && is_nil(@on_close)}
          data-window-control={control}
          class={[control == :close && "ml-[2px]", control == :restore && "u-hidden"]}
          phx-click={control == :close && @on_close}
          data-hide-target={control == :close && @close_target}
        >
          <.control_icon control={control} skin={@skin} />
        </.tool_button>
      </div>
    </div>
    """
  end

  @doc "Renders a window body content area."
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec window_body(map()) :: Phoenix.LiveView.Rendered.t()
  def window_body(assigns) do
    ~H"""
    <div class={classes(["p-2 flex-1", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders a Win98-style status bar."
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec window_status_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def window_status_bar(assigns) do
    ~H"""
    <div class={classes(["flex gap-[1px] mx-[1px]", @class])} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Renders a single field within a status bar."
  attr :skin, :string, values: @skins, default: "retro"
  attr :class, :any, default: nil
  attr :grow, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  @spec window_status_bar_field(map()) :: Phoenix.LiveView.Rendered.t()
  def window_status_bar_field(assigns) do
    ~H"""
    <div
      class={
        classes([
          if(@skin == "pixel",
            do: "window-status-field--pixel",
            else: "border border-border px-[3px] py-[2px] text-sm"
          ),
          "truncate",
          @grow && "flex-grow",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp control_label(:minimize), do: dgettext("ui", "Minimize")
  defp control_label(:maximize), do: dgettext("ui", "Maximize")
  defp control_label(:restore), do: dgettext("ui", "Restore")
  defp control_label(:close), do: dgettext("ui", "Close")
  defp control_label(:help), do: dgettext("ui", "Help")
  defp control_label(other), do: to_string(other)

  defp frame_class("pixel"), do: "window--pixel"
  defp frame_class("device"), do: "window--device"
  defp frame_class(_retro), do: "shadow-retro-window bg-surface p-[3px]"

  defp title_class("pixel"), do: "window-title-bar__title--pixel"
  defp title_class("device"), do: "window-title-bar__title--device"
  defp title_class(_retro), do: "font-bold text-white text-xs"

  defp control_variant("pixel"), do: "pixel"
  defp control_variant("device"), do: "flat"
  defp control_variant(_retro), do: "raised"

  defp title_bar_class("pixel", _inactive), do: "window-title-bar--pixel"
  defp title_bar_class("device", _inactive), do: "window-title-bar--device"

  defp title_bar_class(_retro, true),
    do: "px-[3px] py-[3px] bg-gradient-to-r from-gray-500 to-gray-350"

  defp title_bar_class(_retro, false),
    do: "px-[3px] py-[3px] bg-gradient-to-r from-primary to-highlight-light"

  attr :control, :atom, required: true
  attr :skin, :string, default: "retro"

  defp control_icon(%{skin: "pixel", control: :minimize} = assigns),
    do: ~H"<.pixel_icon name={:win_minimize} />"

  defp control_icon(%{skin: "pixel", control: :maximize} = assigns),
    do: ~H"<.pixel_icon name={:win_maximize} />"

  defp control_icon(%{skin: "pixel", control: :restore} = assigns),
    do: ~H"<.pixel_icon name={:win_restore} />"

  defp control_icon(%{skin: "pixel", control: :close} = assigns),
    do: ~H"<.pixel_icon name={:win_close} />"

  defp control_icon(%{control: :minimize} = assigns) do
    ~H"""
    <Icons.icon_win_minimize class="w-[6px] h-[2px]" />
    """
  end

  defp control_icon(%{control: :maximize} = assigns) do
    ~H"""
    <Icons.icon_win_maximize class="w-[9px] h-[9px]" />
    """
  end

  defp control_icon(%{control: :restore} = assigns) do
    ~H"""
    <Icons.icon_win_restore class="w-[8px] h-[9px]" />
    """
  end

  defp control_icon(%{control: :close} = assigns) do
    ~H"""
    <Icons.icon_close_pixel class="w-[8px] h-[7px]" />
    """
  end

  defp control_icon(%{control: :help} = assigns) do
    ~H"""
    <Icons.icon_win_help class="w-[6px] h-[9px]" />
    """
  end

  defp control_icon(assigns) do
    ~H"""
    """
  end

  defp ensure_close(controls, false), do: controls

  defp ensure_close(controls, true) do
    if :close in controls, do: controls, else: controls ++ [:close]
  end
end
