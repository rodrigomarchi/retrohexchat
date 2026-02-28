defmodule RetroHexChatWeb.Components.UI.EmptyState do
  @moduledoc """
  Win98-style empty state placeholder for the showcase design system.

  Displayed when a content area has no items (empty channel list,
  no search results, no contacts, etc.).

  ## Usage

      <.empty_state>
        <:icon><Icons.icon_chat class="w-8 h-8" /></:icon>
        <:title>No messages yet</:title>
        <:description>Start a conversation to see messages here.</:description>
      </.empty_state>
  """
  use RetroHexChatWeb.Component

  @doc """
  Renders a centered empty state with icon, title, description, and optional action.
  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :icon
  slot :title
  slot :description
  slot :action

  @spec empty_state(map()) :: Phoenix.LiveView.Rendered.t()
  def empty_state(assigns) do
    ~H"""
    <div
      class={
        classes([
          "flex flex-col items-center justify-center gap-retro-8 p-retro-24 text-center",
          @class
        ])
      }
      {@rest}
    >
      <div :if={@icon != []} class="text-muted-foreground opacity-50">
        {render_slot(@icon)}
      </div>
      <div :if={@title != []} class="text-sm font-bold text-foreground">
        {render_slot(@title)}
      </div>
      <div :if={@description != []} class="text-xs text-muted-foreground max-w-[280px]">
        {render_slot(@description)}
      </div>
      <div :if={@action != []}>
        {render_slot(@action)}
      </div>
    </div>
    """
  end
end
