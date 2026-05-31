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
    {"smileys", ~w(😀 😃 😄 😁 😆 😅 🤣 😂 🙂 🙃 😉 😊 😇 🥰 😍 🤩 😘 😗 😚 😙 🥲 😋 😛 😜 🤪 😝)},
    {"people", ~w(👋 🤚 🖐 ✋ 🖖 👌 🤌 🤏 ✌ 🤞 🤟 🤘 🤙 👈 👉 👆 🖕 👇 ☝ 👍 👎 ✊ 👊 🤛 🤜)},
    {"nature", ~w(🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🐔 🐧 🐦 🐤 🦆 🦅 🦉 🦇 🐺)},
    {"food", ~w(🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🫐 🍈 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🥑 🍆 🥒 🌶 🫑 🌽 🥕)},
    {"objects", ~w(⌚ 📱 💻 ⌨ 🖥 🖨 🖱 🖲 🕹 🗜 💾 💿 📼 📷 📹 🎥 📞 ☎ 📟 📠 📺 📻 🎙 🎚)},
    {"symbols", ~w(❤ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣ 💕 💞 💓 💗 💖 💘 💝 💟 ☮ ✝ ☪ 🕉 ☸)}
  ]

  @doc "Renders the emoji picker window."
  attr :id, :string, required: true
  attr :visible, :boolean, default: true, doc: "Show/hide the picker"
  attr :search, :string, default: ""
  attr :active_category, :string, default: "smileys"
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
      id={@id}
      phx-hook="EmojiPickerHook"
      class={classes(["w-full md:w-[320px]", @class])}
      data-testid="emoji-picker"
      {@rest}
    >
      <.window_title_bar title={gettext("Emoji")} controls={[:close]} on_close={@on_close}>
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
              if(category_active?(name, @active_category),
                do: "border-primary font-bold",
                else: "border-transparent text-muted-foreground hover:text-foreground"
              )
            ]}
            phx-click={@on_category}
            phx-value-category={name}
          >
            {translate_category(name)}
          </button>
        </div>

        <%!-- Search --%>
        <div class="p-retro-4">
          <form phx-change={@on_search}>
            <.input
              type="text"
              value={@search}
              placeholder={gettext("Search emoji...")}
              class="w-full text-xs"
              name="emoji_search"
              phx-debounce="200"
              data-testid="emoji-picker-search"
            />
          </form>
        </div>

        <%!-- Emoji grid --%>
        <div class="h-[180px] overflow-y-auto retro-scrollbar px-retro-4 pb-retro-4">
          <div
            :for={{name, emojis} <- @resolved_categories}
            class={unless(category_active?(name, @active_category), do: "hidden")}
          >
            <div class="grid grid-cols-8 gap-retro-2">
              <button
                :for={emoji <- emojis}
                type="button"
                class="w-7 h-7 flex items-center justify-center text-base hover:bg-selection-bg hover:text-selection-fg rounded-sm cursor-pointer"
                phx-click={@on_select}
                phx-value-emoji={emoji_char(emoji)}
              >
                {emoji_char(emoji)}
              </button>
            </div>
          </div>
        </div>

        <%!-- Preview bar --%>
        <div class="flex items-center gap-retro-4 px-retro-4 py-retro-2 border-t border-border bg-surface text-xs">
          <span class="text-lg">{@selected_emoji || "😀"}</span>
          <span class="text-muted-foreground">
            {if @selected_emoji, do: gettext("click to insert"), else: gettext("hover to preview")}
          </span>
        </div>
      </.window_body>
    </.window>
    """
  end

  @spec emoji_char(map() | String.t()) :: String.t()
  defp emoji_char(%{char: char}), do: char
  defp emoji_char(str) when is_binary(str), do: str

  defp category_active?(name, active_category) do
    normalize_category(name) == normalize_category(active_category)
  end

  defp normalize_category(category) when is_binary(category) do
    category
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "_")
    |> String.trim("_")
  end

  defp normalize_category(category), do: category |> to_string() |> normalize_category()

  defp translate_category("smileys"), do: gettext("Smileys")
  defp translate_category("people"), do: gettext("People")
  defp translate_category("nature"), do: gettext("Nature")
  defp translate_category("food"), do: gettext("Food")
  defp translate_category("Smileys & Emotion"), do: gettext("Smileys & Emotion")
  defp translate_category("People & Body"), do: gettext("People & Body")
  defp translate_category("Animals & Nature"), do: gettext("Animals & Nature")
  defp translate_category("Food & Drink"), do: gettext("Food & Drink")
  defp translate_category("Travel & Places"), do: gettext("Travel & Places")
  defp translate_category("Activities"), do: gettext("Activities")
  defp translate_category("Objects"), do: gettext("Objects")
  defp translate_category("Symbols"), do: gettext("Symbols")
  defp translate_category("search_results"), do: gettext("Search Results")
  defp translate_category(category), do: category
end
