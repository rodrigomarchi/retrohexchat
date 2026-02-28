defmodule RetroHexChatWeb.Components.UI.LoadingSpinner do
  @moduledoc """
  Win98-style loading spinner for the showcase design system.

  Provides an animated progress bar with retro styling, text label,
  and optional retry button.

  ## Usage

      <.loading_spinner />
      <.loading_spinner text="Loading messages..." size="lg" />
  """
  use RetroHexChatWeb.Component

  @doc """
  Renders a retro-styled loading spinner with animated progress bar.
  """
  attr :text, :string, default: "Loading..."
  attr :size, :string, default: "default", values: ~w(sm default lg)
  attr :show_retry, :boolean, default: false, doc: "Show retry button below spinner"
  attr :on_retry, :any, default: nil, doc: "JS command or event name for retry"
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block

  @spec loading_spinner(map()) :: Phoenix.LiveView.Rendered.t()
  def loading_spinner(assigns) do
    ~H"""
    <div
      class={
        classes([
          "flex flex-col items-center justify-center gap-retro-8 text-muted-foreground",
          if(!@show_retry, do: "pointer-events-none"),
          size_padding(@size),
          @class
        ])
      }
      role="status"
      aria-label={@text}
      {@rest}
    >
      <div class={[
        "h-[14px] shadow-retro-field",
        size_width(@size),
        "bg-[length:20px_14px] animate-[progress-scroll_1s_linear_infinite]",
        "bg-[repeating-linear-gradient(90deg,theme(colors.link)_0,theme(colors.link)_8px,transparent_8px,transparent_12px)]"
      ]} />
      <span class="text-xs text-muted-foreground">{@text}</span>
      <button
        :if={@show_retry}
        phx-click={@on_retry}
        class="shadow-retro-raised bg-surface px-retro-16 py-retro-2 text-xs text-foreground active:shadow-retro-sunken pointer-events-auto"
      >
        Retry
      </button>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp size_width("sm"), do: "w-[120px]"
  defp size_width("default"), do: "w-[200px]"
  defp size_width("lg"), do: "w-[280px]"

  defp size_padding("sm"), do: "p-retro-12"
  defp size_padding("default"), do: "p-retro-24"
  defp size_padding("lg"), do: "p-retro-32"
end
