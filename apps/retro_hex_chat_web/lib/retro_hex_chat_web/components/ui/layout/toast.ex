defmodule RetroHexChatWeb.Components.UI.Toast do
  @moduledoc """
  Win98-style toast notification component for the showcase design system.

  Provides a floating notification container and individual toast items
  with variant styling (default, success, error, warning, info).

  ## Usage

      <.toast_container position="bottom-right">
        <.toast variant="success" id="toast-1">
          <.toast_title>Success</.toast_title>
          <.toast_description>Operation completed.</.toast_description>
        </.toast>
      </.toast_container>
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  # ── Container ──────────────────────────────────────────

  @doc """
  Renders a fixed-position toast container.

  Toasts are stacked inside this container. Position determines
  which corner of the viewport they appear in.
  """
  attr :position, :string,
    default: "bottom-right",
    values: ~w(top-right top-left bottom-right bottom-left)

  attr :class, :string, default: nil
  slot :inner_block, required: true

  @spec toast_container(map()) :: Phoenix.LiveView.Rendered.t()
  def toast_container(assigns) do
    ~H"""
    <div
      class={
        classes([
          "fixed z-toast pointer-events-none flex flex-col gap-retro-8",
          position_classes(@position),
          @class
        ])
      }
      aria-live="polite"
      aria-label="Notifications"
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ── Toast ──────────────────────────────────────────────

  @doc """
  Renders a single toast notification with Win98 retro styling.

  Uses shadow-retro-window for the 3D frame, with a colored accent
  border on the left side to indicate variant.
  """
  attr :id, :string, required: true
  attr :variant, :string, default: "default", values: ~w(default success error warning info)
  attr :dismissible, :boolean, default: true
  attr :class, :string, default: nil
  attr :on_dismiss, JS, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec toast(map()) :: Phoenix.LiveView.Rendered.t()
  def toast(assigns) do
    ~H"""
    <div
      id={@id}
      role="status"
      class={
        classes([
          "pointer-events-auto w-[calc(100vw-2rem)] md:w-[280px] shadow-retro-window bg-surface p-[3px]",
          @class
        ])
      }
      {@rest}
    >
      <div class="flex gap-retro-8 p-retro-8">
        <div class={["w-[3px] shrink-0 self-stretch", accent_class(@variant)]} />
        <span class="shrink-0 w-[16px] h-[16px] inline-flex items-center justify-center self-start mt-px">
          {variant_icon(assigns)}
        </span>
        <div class="flex-1 min-w-0">
          {render_slot(@inner_block)}
        </div>
        <button
          :if={@dismissible}
          type="button"
          class={[
            "shrink-0 self-start bg-surface shadow-retro-raised active:shadow-retro-sunken",
            "flex items-center justify-center w-[16px] h-[14px]"
          ]}
          phx-click={
            @on_dismiss ||
              JS.hide(
                to: "##{@id}",
                transition: {"transition-opacity duration-150", "opacity-100", "opacity-0"}
              )
          }
          aria-label="Dismiss"
        >
          <Icons.icon_close_pixel class="w-[8px] h-[7px]" />
        </button>
      </div>
    </div>
    """
  end

  # ── Toast Title ────────────────────────────────────────

  @doc "Renders the toast title text."
  attr :class, :string, default: nil
  slot :inner_block, required: true

  @spec toast_title(map()) :: Phoenix.LiveView.Rendered.t()
  def toast_title(assigns) do
    ~H"""
    <p class={classes(["text-xs font-bold text-foreground", @class])}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  # ── Toast Description ─────────────────────────────────

  @doc "Renders the toast description/body text."
  attr :class, :string, default: nil
  slot :inner_block, required: true

  @spec toast_description(map()) :: Phoenix.LiveView.Rendered.t()
  def toast_description(assigns) do
    ~H"""
    <p class={classes(["text-xs text-foreground mt-retro-2", @class])}>
      {render_slot(@inner_block)}
    </p>
    """
  end

  # ── Toast Action ───────────────────────────────────────

  @doc "Renders a toast action area (e.g. buttons, checkboxes)."
  attr :class, :string, default: nil
  slot :inner_block, required: true

  @spec toast_action(map()) :: Phoenix.LiveView.Rendered.t()
  def toast_action(assigns) do
    ~H"""
    <div class={classes(["flex items-center gap-retro-8 mt-retro-6", @class])}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ── Private ────────────────────────────────────────────

  defp position_classes("top-right"), do: "top-retro-8 right-retro-8 items-end"
  defp position_classes("top-left"), do: "top-retro-8 left-retro-8 items-start"
  defp position_classes("bottom-right"), do: "bottom-[28px] right-retro-8 items-end"
  defp position_classes("bottom-left"), do: "bottom-[28px] left-retro-8 items-start"

  defp variant_icon(%{variant: "success"} = assigns),
    do: ~H|<Icons.icon_btn_ok class="w-4 h-4" />|

  defp variant_icon(%{variant: "error"} = assigns),
    do: ~H|<Icons.icon_btn_cancel class="w-4 h-4" />|

  defp variant_icon(%{variant: "warning"} = assigns),
    do: ~H|<Icons.icon_warning class="w-4 h-4" />|

  defp variant_icon(%{variant: "info"} = assigns),
    do: ~H|<Icons.icon_btn_info class="w-4 h-4" />|

  defp variant_icon(assigns),
    do: ~H|<Icons.icon_tab_status class="w-4 h-4" />|

  defp accent_class("success"), do: "bg-success"
  defp accent_class("error"), do: "bg-error"
  defp accent_class("warning"), do: "bg-warning-alt"
  defp accent_class("info"), do: "bg-primary"
  defp accent_class(_default), do: "bg-border"
end
