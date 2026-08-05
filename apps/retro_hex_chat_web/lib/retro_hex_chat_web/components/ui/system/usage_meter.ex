defmodule RetroHexChatWeb.Components.UI.System.UsageMeter do
  @moduledoc """
  A bounded resource drawn against the ceiling it will die at.

  Atoms, ports and processes each have a hard limit compiled into the VM, and
  hitting one ends the node. The count alone cannot say whether that is close,
  so the meter always shows all three facts together: consumed, available, and
  the fraction between them.

  Composes the `progress` primitive rather than drawing its own bar, so a meter
  here and a progress bar anywhere else in the product are the same object.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Progress

  alias RetroHexChat.SystemInfo.Usage
  alias RetroHexChatWeb.Components.UI.Format
  alias RetroHexChatWeb.Icons

  attr :icon, :atom, required: true
  attr :label, :string, required: true
  attr :usage, :any, required: true, doc: "%SystemInfo.Usage{}"
  attr :hint, :string, default: nil, doc: "What exhausting this resource costs"
  attr :class, :any, default: nil
  attr :testid, :string, required: true

  @spec usage_meter(map()) :: Phoenix.LiveView.Rendered.t()
  def usage_meter(%{usage: %Usage{}} = assigns) do
    assigns = assign(assigns, :percent, Usage.percent_rounded(assigns.usage))

    ~H"""
    <div
      class={classes(["min-w-0 border border-border bg-surface p-2 shadow-retro-sunken", @class])}
      data-testid={@testid}
    >
      <div class="mb-1 flex min-w-0 items-center gap-1">
        {apply(Icons, @icon, [%{class: "h-3.5 w-3.5 shrink-0"}])}
        <span class="min-w-0 flex-1 truncate text-xs font-bold">{@label}</span>
        <span class="shrink-0 text-[10px] text-muted-foreground">
          {Format.number(@usage.used)} / {Format.number(@usage.limit)}
        </span>
        <span class="shrink-0 text-xs font-bold tabular-nums">{Format.percent(@percent)}</span>
      </div>

      <.progress value={ceil_to_visible(@percent)} class="h-3" />

      <p :if={@hint} class="mt-1 truncate text-[10px] leading-3 text-muted-foreground">
        {@hint}
      </p>
    </div>
    """
  end

  # A resource at 0.04% would draw nothing at all, which reads as "no data"
  # rather than "barely touched". One percent is the smallest honest sliver.
  defp ceil_to_visible(percent) when percent > 0 and percent < 1, do: 1
  defp ceil_to_visible(percent), do: round(percent)
end
