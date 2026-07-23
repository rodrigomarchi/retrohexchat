defmodule RetroHexChatWeb.Components.UI.ChatMobileActions do
  @moduledoc """
  Compact chat controls for the stacked (mobile) layout.

  Three touch-sized buttons — toggle conversations, toggle nicklist and find —
  rendered inside the chat window at the head of the tab strip, so they are
  only visible while the chat window itself is on screen: other windows on the
  stacked desktop carry no chat controls. Hidden at `md:` and up, where both
  sidebars are permanently visible and Edit → Find covers search.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :class, :any, default: nil

  @spec chat_mobile_actions(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_mobile_actions(assigns) do
    ~H"""
    <div
      class={
        classes([
          "flex items-center gap-1 px-1 shrink-0 bg-surface border-b border-border md:hidden",
          @class
        ])
      }
      data-testid="chat-mobile-actions"
    >
      <.action_button
        event="toggle_conversations"
        label={dgettext("chat", "Show conversations")}
        testid="chat-mobile-conversations"
      >
        <Icons.icon_btn_toggle_conversations class="h-4 w-4" />
      </.action_button>
      <.action_button
        event="toggle_nicklist"
        label={dgettext("chat", "Show nicklist")}
        testid="chat-mobile-nicklist"
      >
        <Icons.icon_btn_toggle_nicklist class="h-4 w-4" />
      </.action_button>
      <.action_button
        event="toggle_search"
        label={dgettext("chat", "Find in chat")}
        testid="chat-mobile-search"
      >
        <Icons.icon_btn_find class="h-4 w-4" />
      </.action_button>
    </div>
    """
  end

  attr :event, :string, required: true
  attr :label, :string, required: true
  attr :testid, :string, required: true
  slot :inner_block, required: true

  defp action_button(assigns) do
    ~H"""
    <button
      type="button"
      class="chat-mobile-action shadow-retro-raised bg-surface inline-flex h-6 w-6 shrink-0 items-center justify-center p-0 active:shadow-retro-sunken focus:outline-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-black"
      phx-click={@event}
      title={@label}
      aria-label={@label}
      data-testid={@testid}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end
end
