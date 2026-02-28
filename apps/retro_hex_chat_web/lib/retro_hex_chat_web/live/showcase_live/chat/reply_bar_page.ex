defmodule RetroHexChatWeb.ShowcaseLive.Chat.ReplyBarPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ReplyBar
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Reply Bar", active_page: "reply-bar")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Reply Bar</h2>

      <.showcase_card
        title="With Message Preview"
        description="Reply bar showing author and original message."
      >
        <.reply_bar author="alice" message="Hello everyone! How's it going today?" />
        <.code_example>
          &lt;.reply_bar author="alice" message="Hello everyone!" /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Without Message"
        description="Reply bar with just the author name."
      >
        <.reply_bar author="bob" />
      </.showcase_card>

      <.showcase_card
        title="Long Message"
        description="Reply bar with a very long message that gets truncated."
      >
        <.reply_bar
          author="carol"
          message="This is a very long message that should be truncated because it exceeds the available space in the reply bar component and we want to show how truncation works"
        />
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
