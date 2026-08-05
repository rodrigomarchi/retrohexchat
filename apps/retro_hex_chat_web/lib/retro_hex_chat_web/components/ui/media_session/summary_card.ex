defmodule RetroHexChatWeb.Components.UI.MediaSession.SummaryCard do
  @moduledoc """
  One measured figure, labelled and captioned.

  These cards are the summary-first layer above detailed diagnostics. They do
  not compute anything; callers pass measured labels and values.

  Two sizes, because the same card serves two jobs. `:compact` packs many
  readings into a stats panel beside the thing being measured. `:prominent`
  gives one reading the whole tile, for the headline figures a monitor opens
  on — an uptime or a version is read at a glance, not scanned.

  Named for the role rather than the caller: it began beside media sessions and
  is now equally the vocabulary of the runtime windows, which is why `detail`
  became optional rather than being faked with an empty string.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :icon, :atom, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :detail, :string, default: nil
  attr :tone_class, :any, default: nil
  attr :class, :any, default: nil
  attr :testid, :string, required: true

  attr :variant, :atom,
    default: :compact,
    values: [:compact, :prominent],
    doc: "`:prominent` enlarges the value for a headline figure"

  @spec summary_card(map()) :: Phoenix.LiveView.Rendered.t()
  def summary_card(assigns) do
    ~H"""
    <div
      class={
        classes([
          "min-w-0 border border-border px-2 py-1 shadow-retro-sunken",
          @class
        ])
      }
      data-testid={@testid}
    >
      <div class="flex min-w-0 items-center gap-1 text-[10px] font-bold uppercase text-muted-foreground">
        {apply(Icons, @icon, [%{class: "h-3.5 w-3.5 shrink-0"}])}
        <span class="truncate">{@label}</span>
      </div>
      <div class={classes([value_class(@variant), @tone_class])}>
        {@value}
      </div>
      <div :if={@detail} class="truncate text-[10px] leading-3 text-muted-foreground">
        {@detail}
      </div>
    </div>
    """
  end

  defp value_class(:prominent), do: "truncate text-lg font-bold leading-6"
  defp value_class(_compact), do: "truncate text-sm font-bold leading-5"
end
