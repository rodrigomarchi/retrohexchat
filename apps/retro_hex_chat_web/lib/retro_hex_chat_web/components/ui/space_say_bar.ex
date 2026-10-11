defmodule RetroHexChatWeb.Components.UI.SpaceSayBar do
  @moduledoc """
  The line along the bottom of a space where you type what your character says.

  What is sent goes to the conversation the space belongs to, and comes back as
  a bubble over the speaker — the same bubble a line typed in the chat makes.

  The keyboard is shared with the map: while the field has focus the arrow keys
  and WASD type instead of walking (`space/input.js` stands aside for a focused
  field). Enter anywhere on the page puts the cursor in the field, and Esc hands
  the keyboard back to the map by focusing the canvas. Both are client-side
  `JS.focus` commands, so neither costs a round trip.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias Phoenix.LiveView.JS
  alias RetroHexChatWeb.Icons

  attr :id, :string, required: true, doc: "id of the text field"
  attr :canvas_id, :string, required: true, doc: "the element Esc gives the keyboard back to"
  attr :value, :string, default: ""
  attr :placeholder, :string, required: true
  attr :error, :string, default: nil
  attr :max_length, :integer, default: 1000

  @spec space_say_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def space_say_bar(assigns) do
    ~H"""
    <div
      class="shrink-0 bg-surface"
      data-testid="space-say-bar"
      phx-window-keydown={JS.focus(to: "##{@id}")}
      phx-key="Enter"
    >
      <form
        phx-submit="space_say"
        phx-change="space_say_change"
        class="flex items-center gap-1 p-[2px]"
        data-testid="space-say-form"
      >
        <input
          id={@id}
          type="text"
          name="text"
          value={@value}
          placeholder={@placeholder}
          maxlength={@max_length}
          autocomplete="off"
          enterkeyhint="send"
          aria-label={dgettext("chat", "Say something")}
          phx-keydown={JS.focus(to: "##{@canvas_id}")}
          phx-key="Escape"
          data-testid="space-say-input"
          class="h-8 min-w-0 flex-1 px-1 font-mono text-sm bg-white border border-border shadow-retro-field outline-none placeholder:text-ellipsis"
        />
        <.button
          type="submit"
          size="sm"
          disabled={String.trim(@value) == ""}
          aria-label={dgettext("chat", "Say")}
          title={dgettext("chat", "Say")}
          data-testid="space-say-send"
          class="h-8 px-2"
        >
          <:icon><Icons.icon_btn_send class="w-4 h-4" /></:icon>
          <span>{dgettext("chat", "Say")}</span>
        </.button>
      </form>
      <p :if={@error} class="px-1 pb-[2px] text-xs text-destructive" data-testid="space-say-error">
        {@error}
      </p>
    </div>
    """
  end
end
