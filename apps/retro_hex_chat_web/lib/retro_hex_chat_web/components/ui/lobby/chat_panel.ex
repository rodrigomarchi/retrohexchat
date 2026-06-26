defmodule RetroHexChatWeb.Components.UI.Lobby.ChatPanel do
  @moduledoc """
  Ephemeral lobby chat panel — the body of the "Chat" window.

  A scrollable message history plus the message form (bound to `P2PChatFormHook`).
  Composed from the scroll-area, input and button primitives.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ScrollArea
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  attr :messages, :list, required: true

  @spec chat_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_panel(assigns) do
    ~H"""
    <div class="flex h-full flex-col" data-testid="lobby-chat">
      <.scroll_area class="shadow-retro-field flex-1 space-y-1 bg-white p-2" id="lobby-messages">
        <p :for={msg <- @messages} class="text-xs">
          <span :if={msg.type == "system"} class="text-muted-foreground italic">{msg.content}</span>
          <span :if={msg.type != "system"}>
            <span class="font-bold">{msg.sender_nick}:</span>
            {msg.content}
          </span>
        </p>
      </.scroll_area>
      <form
        phx-submit="send_message"
        phx-hook="P2PChatFormHook"
        id="lobby-chat-form"
        class="mt-2 flex gap-1"
      >
        <.input
          type="text"
          name="content"
          autocomplete="off"
          maxlength="500"
          placeholder={dgettext("lobby", "Type a message")}
          class="flex-1 text-xs"
        />
        <.button type="submit" size="sm">
          <:icon><Icons.icon_send class="h-4 w-4" /></:icon>
          {dgettext("lobby", "Send")}
        </.button>
      </form>
    </div>
    """
  end
end
