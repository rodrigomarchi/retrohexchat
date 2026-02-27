defmodule RetroHexChatWeb.Components.UI.EmojiPicker do
  @moduledoc """
  Emoji picker component for the showcase design system.

  Composed from window + tabs + input + scroll_area primitives.
  Retro window with category tabs, search field, scrollable emoji grid, and preview.

  ## Usage

      <.emoji_picker id="emoji-picker" />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Input

  alias RetroHexChatWeb.Icons

  @emoji_categories [
    {"Smileys", ~w(😀 😃 😄 😁 😆 😅 🤣 😂 🙂 🙃 😉 😊 😇 🥰 😍 🤩 😘 😗 😚 😙 🥲 😋 😛 😜 🤪 😝)},
    {"People", ~w(👋 🤚 🖐 ✋ 🖖 👌 🤌 🤏 ✌ 🤞 🤟 🤘 🤙 👈 👉 👆 🖕 👇 ☝ 👍 👎 ✊ 👊 🤛 🤜)},
    {"Nature", ~w(🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🐔 🐧 🐦 🐤 🦆 🦅 🦉 🦇 🐺)},
    {"Food", ~w(🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🫐 🍈 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🥑 🍆 🥒 🌶 🫑 🌽 🥕)},
    {"Objects", ~w(⌚ 📱 💻 ⌨ 🖥 🖨 🖱 🖲 🕹 🗜 💾 💿 📼 📷 📹 🎥 📞 ☎ 📟 📠 📺 📻 🎙 🎚)},
    {"Symbols", ~w(❤ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣ 💕 💞 💓 💗 💖 💘 💝 💟 ☮ ✝ ☪ 🕉 ☸)}
  ]

  @doc "Renders the emoji picker window."
  attr :id, :string, required: true
  attr :search, :string, default: ""
  attr :active_category, :string, default: "Smileys"
  attr :class, :string, default: nil
  attr :rest, :global

  @spec emoji_picker(map()) :: Phoenix.LiveView.Rendered.t()
  def emoji_picker(assigns) do
    assigns = assign(assigns, :categories, @emoji_categories)

    ~H"""
    <.window class={classes(["w-[320px]", @class])} {@rest}>
      <.window_title_bar title="Emoji" controls={[:close]}>
        <:icon><Icons.icon_fmt_emoji class="w-4 h-4" /></:icon>
      </.window_title_bar>

      <.window_body class="p-0">
        <%!-- Category tabs --%>
        <div class="flex border-b border-border bg-surface px-retro-2">
          <button
            :for={{name, _emojis} <- @categories}
            type="button"
            class={[
              "px-retro-4 py-retro-2 text-[10px] border-b-2",
              if(name == @active_category,
                do: "border-primary font-bold",
                else: "border-transparent text-muted-foreground hover:text-foreground"
              )
            ]}
          >
            {name}
          </button>
        </div>

        <%!-- Search --%>
        <div class="p-retro-4">
          <.input type="text" value={@search} placeholder="Search emoji..." class="w-full text-xs" />
        </div>

        <%!-- Emoji grid --%>
        <div class="h-[180px] overflow-y-auto retro-scrollbar px-retro-4 pb-retro-4">
          <div
            :for={{name, emojis} <- @categories}
            class={if(name != @active_category, do: "hidden")}
          >
            <div class="grid grid-cols-8 gap-retro-2">
              <button
                :for={emoji <- emojis}
                type="button"
                class="w-7 h-7 flex items-center justify-center text-base hover:bg-selection-bg hover:text-selection-fg rounded-sm cursor-pointer"
              >
                {emoji}
              </button>
            </div>
          </div>
        </div>

        <%!-- Preview bar --%>
        <div class="flex items-center gap-retro-4 px-retro-4 py-retro-2 border-t border-border bg-surface text-xs">
          <span class="text-lg">😀</span>
          <span class="text-muted-foreground">grinning face</span>
        </div>
      </.window_body>
    </.window>
    """
  end
end
