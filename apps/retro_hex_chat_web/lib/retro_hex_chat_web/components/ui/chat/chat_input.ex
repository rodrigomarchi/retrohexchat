defmodule RetroHexChatWeb.Components.UI.ChatInput do
  @moduledoc """
  Chat input component for the showcase design system.

  Provides a textarea input with optional formatting toolbar slot,
  Send button, and character counter. Supports hooks for autocomplete,
  character counting, and other interactive behaviors.

  ## Usage

      <%!-- Basic (showcase) --%>
      <.chat_input
        value={@draft}
        on_submit="send_message"
      />

      <%!-- Full (real chat) --%>
      <.chat_input
        id="chat-input-area"
        input_id="chat-input"
        value={@input}
        name="input"
        placeholder="Type a message..."
        on_submit="send_input"
        hook="AutocompleteHook"
        wrapper_hook="CharCounterHook"
        autofocus
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders a combined chat input area with textarea, send button, and counter."
  attr :id, :string, default: nil, doc: "Wrapper element ID (for hooks)"
  attr :input_id, :string, default: nil, doc: "Textarea element ID (for hooks and JS focus)"
  attr :value, :string, default: "", doc: "Current input value"
  attr :placeholder, :string, default: "Type a message..."
  attr :max_length, :integer, default: 1000
  attr :name, :string, default: "message", doc: "Textarea field name"
  attr :disabled, :boolean, default: false
  attr :autofocus, :boolean, default: false
  attr :show_toolbar, :boolean, default: true
  attr :on_submit, :any, default: nil, doc: "Form submit / Send button callback"
  attr :on_change, :any, default: nil, doc: "Input change callback"
  attr :on_keydown, :any, default: nil, doc: "Keydown callback (for autocomplete, history, etc.)"
  attr :hook, :string, default: nil, doc: "Phoenix hook for the textarea (e.g. AutocompleteHook)"

  attr :wrapper_hook, :string,
    default: nil,
    doc: "Phoenix hook for the wrapper div (e.g. CharCounterHook)"

  attr :class, :any, default: nil
  attr :rest, :global
  slot :toolbar_buttons

  @spec chat_input(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_input(assigns) do
    assigns = assign(assigns, :char_count, String.length(assigns.value || ""))

    ~H"""
    <div
      id={@id}
      class={classes(["flex flex-col", @class])}
      data-testid="chat-input"
      phx-hook={@wrapper_hook}
      {@rest}
    >
      <div
        :if={@show_toolbar && @toolbar_buttons != []}
        class="flex items-center bg-surface py-[2px] px-[2px] gap-0"
      >
        {render_slot(@toolbar_buttons)}
      </div>
      <form phx-submit={@on_submit} class="flex items-center gap-1 p-[2px] bg-surface">
        <textarea
          id={@input_id}
          name={@name}
          rows="1"
          placeholder={@placeholder}
          maxlength={@max_length}
          disabled={@disabled}
          autocomplete="off"
          autofocus={@autofocus}
          phx-change={@on_change}
          phx-keydown={@on_keydown}
          phx-hook={@hook}
          data-testid="chat-input-field"
          class="flex-1 py-[3px] px-1 font-mono text-sm bg-white border border-border shadow-retro-field resize-none outline-none"
        >{@value}</textarea>
        <div class="flex flex-col items-center gap-0">
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
          <span class="text-[10px] text-muted-foreground" data-testid="char-counter">
            {@char_count}/{@max_length}
          </span>
        </div>
      </form>
    </div>
    """
  end
end
