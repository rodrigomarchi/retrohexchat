defmodule RetroHexChatWeb.Components.UI.System.MemoryBar do
  @moduledoc """
  The emulator's memory as one bar cut into its consumers, with a legend.

  A stack of six numbers makes the reader do the proportions in their head; one
  bar does it for them, and the bucket that has grown is the one that got wide.
  This only works because the buckets are guaranteed to sum to the total — see
  `RetroHexChat.SystemInfo.Memory`, which maintains that invariant so the
  segments can be trusted as proportions.

  Each bucket keeps one colour across the bar and the legend, drawn from the
  palette's secondary set: navy, teal, maroon, olive, purple, grey. They are
  the six that stay distinguishable at a two-pixel width.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChat.SystemInfo.Memory
  alias RetroHexChatWeb.Components.UI.Format
  alias RetroHexChatWeb.Icons

  @tones %{
    processes: "bg-primary",
    atom: "bg-teal",
    binary: "bg-maroon",
    code: "bg-warning",
    ets: "bg-action",
    other: "bg-gray-500"
  }

  attr :memory, :any, required: true, doc: "%SystemInfo.Memory{}"
  attr :class, :any, default: nil
  attr :testid, :string, default: "system-memory-bar"

  @spec memory_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def memory_bar(%{memory: %Memory{}} = assigns) do
    assigns = assign(assigns, :segments, segments(assigns.memory))

    ~H"""
    <div
      class={classes(["min-w-0 border border-border bg-surface p-2 shadow-retro-sunken", @class])}
      data-testid={@testid}
    >
      <div class="mb-2 flex min-w-0 items-center gap-1 text-xs font-bold">
        <Icons.icon_memory class="h-3.5 w-3.5 shrink-0" />
        <span class="truncate">{dgettext("dialogs", "Memory")}</span>
      </div>

      <div class="flex h-4 w-full overflow-hidden shadow-retro-sunken" role="img">
        <div
          :for={segment <- @segments}
          class={["memory-bar__segment", segment.tone]}
          style={"--memory-bar-share: #{segment.width}%;"}
          title={"#{segment.label}: #{Format.bytes(segment.bytes)}"}
        >
        </div>
      </div>

      <dl class="mt-2 grid grid-cols-2 gap-x-3 gap-y-1">
        <div :for={segment <- @segments} class="flex min-w-0 items-center gap-1">
          <span class={["h-2.5 w-2.5 shrink-0 border border-border", segment.tone]}></span>
          <dt class="min-w-0 flex-1 truncate text-[10px]">{segment.label}</dt>
          <dd class="shrink-0 text-[10px] font-bold tabular-nums">
            {Format.bytes(segment.bytes)}
          </dd>
        </div>
      </dl>

      <p class="mt-2 border-t border-border pt-1 text-center text-xs font-bold">
        {dgettext("dialogs", "Total usage: %{total}", total: Format.bytes(@memory.total))}
      </p>
    </div>
    """
  end

  defp segments(memory) do
    for {bucket, bytes} <- Memory.buckets(memory) do
      %{
        bucket: bucket,
        bytes: bytes,
        label: label(bucket),
        tone: Map.fetch!(@tones, bucket),
        width: Float.round(Memory.share(memory, bucket), 3)
      }
    end
  end

  # Resolved per render rather than in a module attribute: a label baked in at
  # compile time would be frozen in whichever locale compiled the release.
  defp label(:processes), do: dgettext("dialogs", "Processes")
  defp label(:atom), do: dgettext("dialogs", "Atoms")
  defp label(:binary), do: dgettext("dialogs", "Binary")
  defp label(:code), do: dgettext("dialogs", "Code")
  defp label(:ets), do: dgettext("dialogs", "ETS")
  defp label(:other), do: dgettext("dialogs", "Other")
end
