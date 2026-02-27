defmodule RetroHexChatWeb.ShowcaseLive.EmojiPickerPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.EmojiPicker
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Emoji Picker", active_page: "emoji-picker")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Emoji Picker</h2>

      <.showcase_card
        title="Default"
        description="Emoji picker with category tabs, search, scrollable grid, and preview."
      >
        <.emoji_picker id="emoji-default" />
        <.code_example>
          &lt;.emoji_picker id="emoji-picker" /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Different Category"
        description="Emoji picker opened on the Nature category."
      >
        <.emoji_picker id="emoji-nature" active_category="Nature" />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
