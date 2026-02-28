defmodule RetroHexChatWeb.Components.UI.ChatInput do
  @moduledoc """
  Chat input component for the showcase design system.

  Provides a text input with optional formatting toolbar slot,
  Send button, and character counter. Fully wired with callbacks.

  ## Usage

      <.chat_input
        value={@draft}
        on_submit="send_message"
        on_change="update_draft"
        on_keydown="input_keydown"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @doc "Renders a combined chat input area with optional formatting toolbar, send button, and counter."
  attr :value, :string, default: "", doc: "Current input value"
  attr :placeholder, :string, default: "Type a message..."
  attr :max_length, :integer, default: 1000
  attr :name, :string, default: "message", doc: "Input field name"
  attr :disabled, :boolean, default: false
  attr :show_toolbar, :boolean, default: true
  attr :on_submit, :any, default: nil, doc: "Form submit / Send button callback"
  attr :on_change, :any, default: nil, doc: "Input change callback"
  attr :on_keydown, :any, default: nil, doc: "Keydown callback (for autocomplete, history, etc.)"
  attr :class, :any, default: nil
  attr :rest, :global
  slot :toolbar_buttons

  @spec chat_input(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_input(assigns) do
    assigns = assign(assigns, :char_count, String.length(assigns.value || ""))

    ~H"""
    <div class={classes(["flex flex-col", @class])} data-testid="chat-input" {@rest}>
      <div
        :if={@show_toolbar && @toolbar_buttons != []}
        class="flex items-center bg-surface py-[2px] px-[2px] gap-0"
      >
        {render_slot(@toolbar_buttons)}
      </div>
      <form phx-submit={@on_submit} class="flex items-center gap-1 p-[2px] bg-surface">
        <.input
          type="text"
          name={@name}
          value={@value}
          placeholder={@placeholder}
          maxlength={@max_length}
          disabled={@disabled}
          autocomplete="off"
          phx-change={@on_change}
          phx-keydown={@on_keydown}
          data-testid="chat-input-field"
          class="flex-1 py-[3px] font-mono"
        />
        <.button
          type="submit"
          disabled={@disabled || @char_count == 0}
          data-testid="chat-input-send"
          size="sm"
          class="min-w-[60px]"
        >
          <:icon><Icons.icon_btn_send class="w-4 h-4" /></:icon>
          Send
        </.button>
      </form>
      <div class="text-right text-xs text-gray-500 px-1" data-testid="chat-input-counter">
        {@char_count}/{@max_length}
      </div>
    </div>
    """
  end
end
