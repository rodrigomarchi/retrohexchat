defmodule RetroHexChatWeb.Components.UI.EntryPopover do
  @moduledoc """
  The summary that opens from an entry on the conversation toolbar — a
  conference running in the channel, a P2P session with the person in a
  private message.

  Both entries say the same three things before anything else: what it is,
  whose it is, and whether it is running. One panel and one header, so the two
  summaries cannot drift into two looks for the same idea.
  """
  use RetroHexChatWeb.Component

  @doc "The popover panel's frame, for `Popover.popover/1`'s `panel_class`."
  @spec panel_class() :: String.t()
  def panel_class, do: "w-72 border border-border bg-surface p-2 text-xs shadow-retro-raised"

  attr :title, :string, required: true
  attr :state_label, :string, required: true
  attr :state_class, :any, required: true, doc: "the state's text colour"
  slot :icon, required: true
  slot :meta, doc: "one muted line under the title"

  @doc "The header row: icon and title, an optional meta line, the state on the right."
  @spec entry_popover_header(map()) :: Phoenix.LiveView.Rendered.t()
  def entry_popover_header(assigns) do
    ~H"""
    <div class="flex items-start justify-between gap-2 border-b border-border pb-1">
      <div class="min-w-0">
        <div class="flex items-center gap-1 font-bold">
          {render_slot(@icon)}
          <span class="truncate">{@title}</span>
        </div>
        <div
          :if={@meta != []}
          class="mt-0.5 flex items-center gap-1 text-[10px] text-muted-foreground"
        >
          {render_slot(@meta)}
        </div>
      </div>
      <span class={["shadow-retro-sunken bg-white px-1 py-px text-[10px] font-bold", @state_class]}>
        {@state_label}
      </span>
    </div>
    """
  end
end
