defmodule RetroHexChatWeb.ShowcaseLive.Chat.ChatInputPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ChatInput
  import RetroHexChatWeb.Components.UI.Toolbar
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Chat Input", active_page: "chat-input")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Chat Input</h2>

      <.showcase_card
        title="Basic Input"
        description="Simple chat input with send button and counter."
      >
        <.chat_input placeholder="Message to #lobby — / for commands" show_toolbar={false} />
        <.code_example>
          &lt;.chat_input placeholder="Message to #lobby" show_toolbar=&#123;false&#125; /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="With Formatting Toolbar"
        description="Input with bold, italic, underline, and color buttons."
      >
        <.chat_input placeholder="Message to #lobby — / for commands">
          <:toolbar_buttons>
            <.toolbar_button variant="compact" label="Bold">
              <span class="text-xs font-bold">B</span>
            </.toolbar_button>
            <.toolbar_button variant="compact" label="Italic">
              <span class="text-xs italic">I</span>
            </.toolbar_button>
            <.toolbar_button variant="compact" label="Underline">
              <span class="text-xs underline">U</span>
            </.toolbar_button>
            <.toolbar_separator variant="compact" />
            <.toolbar_button variant="compact" label="Text Color">
              <span class="text-xs font-bold text-error">A</span>
            </.toolbar_button>
            <.toolbar_button variant="compact" label="Background Color">
              <span class="text-xs font-bold bg-highlight-bg px-0.5">A</span>
            </.toolbar_button>
          </:toolbar_buttons>
        </.chat_input>
        <.code_example>
          &lt;.chat_input placeholder="Message to #lobby"&gt;
          &lt;:toolbar_buttons&gt;
          &lt;.toolbar_button variant="compact" label="Bold"&gt;
          &lt;span class="font-bold"&gt;B&lt;/span&gt;
          &lt;/.toolbar_button&gt;
          &lt;/:toolbar_buttons&gt;
          &lt;/.chat_input&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="Custom Max Length" description="Input with custom character limit.">
        <.chat_input placeholder="Short message..." max_length={140} show_toolbar={false} />
        <.code_example>
          &lt;.chat_input max_length=&#123;140&#125; show_toolbar=&#123;false&#125; /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
