defmodule RetroHexChatWeb.Components.UI.ScrollLoader do
  @moduledoc """
  Win98-style scroll loader for the showcase design system.

  Shows an animated progress bar with "Loading messages..." text when active.
  Used as a simple loading indicator at the top or bottom of a scrollable message list.

  ## Usage

      <.scroll_loader loading={true} />
      <.scroll_loader loading={false} />
  """
  use RetroHexChatWeb.Component

  @doc "Renders a retro-styled scroll loading indicator."
  attr :loading, :boolean, default: false
  attr :class, :string, default: nil

  @spec scroll_loader(map()) :: Phoenix.LiveView.Rendered.t()
  def scroll_loader(assigns) do
    ~H"""
    <div
      class={
        classes([
          "flex flex-col items-center justify-center gap-retro-8 py-retro-12",
          @class
        ])
      }
      data-testid="scroll-loader"
      role="status"
      aria-live="polite"
      aria-label={if @loading, do: "Loading messages", else: ""}
    >
      <div :if={@loading} class="flex flex-col items-center gap-retro-8">
        <div class={[
          "w-[160px] h-[14px] shadow-retro-field",
          "bg-[length:20px_14px] animate-[progress-scroll_1s_linear_infinite]",
          "bg-[repeating-linear-gradient(90deg,theme(colors.link)_0,theme(colors.link)_8px,transparent_8px,transparent_12px)]"
        ]} />
        <span class="text-xs text-muted-foreground">Loading messages...</span>
      </div>
    </div>
    """
  end
end
