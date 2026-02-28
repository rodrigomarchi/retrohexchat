defmodule RetroHexChatWeb.Components.UI.TopicBar do
  @moduledoc """
  Topic bar component for the showcase design system.

  Composed from badge + simple layout.
  Displays channel topic, mode badges, and supports
  variants for channel, PM, and status windows.

  ## Usage

      <.topic_bar
        topic="Welcome to #lobby!"
        modes={["+nt", "+l 50"]}
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Badge

  alias RetroHexChatWeb.Icons

  @doc "Renders the topic bar."
  attr :topic, :string, default: ""
  attr :modes, :list, default: []
  attr :variant, :string, default: "channel", values: ~w(channel pm status)
  attr :channel_name, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global

  @spec topic_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def topic_bar(assigns) do
    ~H"""
    <div
      class={
        classes([
          "flex items-center gap-retro-4 px-retro-4 py-retro-2 text-xs",
          "shadow-retro-sunken bg-white",
          @class
        ])
      }
      data-testid="topic-bar"
      {@rest}
    >
      <.topic_icon variant={@variant} />

      <span :if={@channel_name} class="font-bold shrink-0">{@channel_name}</span>

      <span class="flex-1 truncate text-muted-foreground">
        {if @topic == "", do: "No topic set", else: @topic}
      </span>

      <.badge :for={mode <- @modes} variant="outline" class="text-[10px] px-1 py-0 shrink-0">
        {mode}
      </.badge>
    </div>
    """
  end

  # ── Private helpers ───────────────────────────────────

  attr :variant, :string, required: true

  defp topic_icon(%{variant: "channel"} = assigns) do
    ~H"""
    <Icons.icon_tab_channel class="w-3 h-3 shrink-0" />
    """
  end

  defp topic_icon(%{variant: "pm"} = assigns) do
    ~H"""
    <Icons.icon_tab_pm class="w-3 h-3 shrink-0" />
    """
  end

  defp topic_icon(%{variant: "status"} = assigns) do
    ~H"""
    <Icons.icon_status_signal class="w-3 h-3 shrink-0" />
    """
  end
end
