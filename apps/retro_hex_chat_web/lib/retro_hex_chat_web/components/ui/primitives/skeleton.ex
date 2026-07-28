defmodule RetroHexChatWeb.Components.UI.Skeleton do
  @moduledoc """
  A pulsing placeholder block, sized by the caller.

  Used to reserve the space content will occupy while it loads, so a panel does
  not jump when the content lands — something a spinner in an empty box cannot
  do. `UI.ListStates.list_skeleton/1` composes this for first-load list rows.
  """
  use RetroHexChatWeb.Component

  @doc """
  Renders a placeholder block. Give it its dimensions through `class`.
  """
  attr :class, :string, default: nil
  attr :rest, :global

  @spec skeleton(map()) :: Phoenix.LiveView.Rendered.t()
  def skeleton(assigns) do
    ~H"""
    <div
      class={
        classes([
          "animate-pulse rounded-md bg-muted",
          @class
        ])
      }
      {@rest}
    >
    </div>
    """
  end
end
