defmodule RetroHexChatWeb.Components.UI.ChatInput do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc "Renders a combined chat input area with optional formatting toolbar, send button, and counter."
  attr :placeholder, :string, default: "Type a message..."
  attr :max_length, :integer, default: 1000
  attr :show_toolbar, :boolean, default: true
  attr :class, :any, default: nil
  attr :rest, :global
  slot :toolbar_buttons

  @spec chat_input(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_input(assigns) do
    ~H"""
    <div class={classes(["flex flex-col", @class])} {@rest}>
      <div :if={@show_toolbar} class="flex items-center bg-surface py-[2px] px-[2px] gap-0">
        {render_slot(@toolbar_buttons)}
      </div>
      <div class="flex items-center gap-1 p-[2px] bg-surface">
        <input
          type="text"
          placeholder={@placeholder}
          maxlength={@max_length}
          class="flex-1 shadow-retro-field bg-white px-2 py-[3px] text-sm font-mono focus:outline focus:outline-2 focus:outline-black"
        />
        <button
          type="button"
          class="shadow-retro-raised bg-surface px-3 py-[2px] text-sm min-w-[60px] active:shadow-retro-sunken"
        >
          Send
        </button>
      </div>
      <div class="text-right text-xs text-gray-500 px-1">0/{@max_length}</div>
    </div>
    """
  end
end
