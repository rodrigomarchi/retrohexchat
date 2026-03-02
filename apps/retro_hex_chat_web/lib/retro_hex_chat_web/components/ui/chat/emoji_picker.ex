defmodule RetroHexChatWeb.Components.UI.EmojiPicker do
  @moduledoc """
  Emoji picker component for the showcase design system.

  Composed from window + tabs + input + scroll_area primitives.
  Retro window with category tabs, search field, scrollable emoji grid, and preview.

  ## Usage

      <.emoji_picker
        id="emoji-picker"
        visible={true}
        on_select="emoji-selected"
        on_category="emoji-category"
        on_search="emoji-search"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @default_categories [
    {"Smileys", ~w(😀 😃 😄 😁 😆 😅 🤣 😂 🙂 🙃 😉 😊 😇 🥰 😍 🤩 😘 😗 😚 😙 🥲 😋 😛 😜 🤪 😝)},
    {"People", ~w(👋 🤚 🖐 ✋ 🖖 👌 🤌 🤏 ✌ 🤞 🤟 🤘 🤙 👈 👉 👆 🖕 👇 ☝ 👍 👎 ✊ 👊 🤛 🤜)},
    {"Nature", ~w(🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🐔 🐧 🐦 🐤 🦆 🦅 🦉 🦇 🐺)},
    {"Food", ~w(🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🫐 🍈 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🥑 🍆 🥒 🌶 🫑 🌽 🥕)},
    {"Objects", ~w(⌚ 📱 💻 ⌨ 🖥 🖨 🖱 🖲 🕹 🗜 💾 💿 📼 📷 📹 🎥 📞 ☎ 📟 📠 📺 📻 🎙 🎚)},
    {"Symbols", ~w(❤ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣ 💕 💞 💓 💗 💖 💘 💝 💟 ☮ ✝ ☪ 🕉 ☸)}
  ]

  @doc "Renders the emoji picker window."
  attr :id, :string, required: true
  attr :visible, :boolean, default: true, doc: "Show/hide the picker"
  attr :search, :string, default: ""
  attr :active_category, :string, default: "Smileys"
  attr :selected_emoji, :string, default: nil, doc: "Currently previewed emoji"

  attr :categories, :list,
    default: nil,
    doc: "List of {name, emoji_list} tuples (defaults to built-in set)"

  attr :on_select, :any, default: nil, doc: "Emoji select callback (receives phx-value-emoji)"

  attr :on_category, :any,
    default: nil,
    doc: "Category tab click callback (receives phx-value-category)"

  attr :on_search, :any, default: nil, doc: "Search input callback"
  attr :on_close, :any, default: nil, doc: "Close button callback"
  attr :class, :string, default: nil
  attr :rest, :global

  @spec emoji_picker(map()) :: Phoenix.LiveView.Rendered.t()
  def emoji_picker(assigns) do
    assigns =
      assign_new(assigns, :resolved_categories, fn ->
        assigns.categories || @default_categories
      end)

    ~H"""
    <.window
      :if={@visible}
      class={classes(["w-full md:w-[320px]", @class])}
      data-testid="emoji-picker"
      {@rest}
    >
      <.window_title_bar title="Emoji" controls={[:close]} on_close={@on_close}>
        <:icon><Icons.icon_fmt_emoji class="w-4 h-4" /></:icon>
      </.window_title_bar>

      <.window_body class="p-0">
        <%!-- Category tabs --%>
        <div class="flex border-b border-border bg-surface px-retro-2">
          <button
            :for={{name, _emojis} <- @resolved_categories}
            type="button"
            class={[
              "px-retro-4 py-retro-2 text-[10px] border-b-2 cursor-pointer",
              if(name == @active_category,
                do: "border-primary font-bold",
                else: "border-transparent text-muted-foreground hover:text-foreground"
              )
            ]}
            phx-click={@on_category}
            phx-value-category={name}
          >
            {name}
          </button>
        </div>

        <%!-- Search --%>
        <div class="p-retro-4">
          <.input
            type="text"
            value={@search}
            placeholder="Search emoji..."
            class="w-full text-xs"
            name="emoji_search"
            phx-change={@on_search}
            phx-debounce="200"
            data-testid="emoji-picker-search"
          />
        </div>

        <%!-- Emoji grid --%>
        <div class="h-[180px] overflow-y-auto retro-scrollbar px-retro-4 pb-retro-4">
          <div
            :for={{name, emojis} <- @resolved_categories}
            class={if(name != @active_category, do: "hidden")}
          >
            <div class="grid grid-cols-8 gap-retro-2">
              <button
                :for={emoji <- emojis}
                type="button"
                class="w-7 h-7 flex items-center justify-center text-base hover:bg-selection-bg hover:text-selection-fg rounded-sm cursor-pointer"
                phx-click={@on_select}
                phx-value-emoji={emoji}
              >
                {emoji}
              </button>
            </div>
          </div>
        </div>

        <%!-- Preview bar --%>
        <div class="flex items-center gap-retro-4 px-retro-4 py-retro-2 border-t border-border bg-surface text-xs">
          <span class="text-lg">{@selected_emoji || "😀"}</span>
          <span class="text-muted-foreground">
            {if @selected_emoji, do: "click to insert", else: "hover to preview"}
          </span>
        </div>
      </.window_body>
    </.window>
    """
  end
end
