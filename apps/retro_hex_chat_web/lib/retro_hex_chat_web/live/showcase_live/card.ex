defmodule RetroHexChatWeb.ShowcaseLive.Card do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Card
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Card", active_page: "card")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Card</h2>

      <.showcase_card
        title="Usage"
        description="Container for grouping related content with header, content, and footer."
      >
        <div class="max-w-sm">
          <.card>
            <.card_header>
              <.card_title>Card Title</.card_title>
              <.card_description>Card description goes here.</.card_description>
            </.card_header>
            <.card_content>
              <p>This is the card content area. You can put any content here.</p>
            </.card_content>
            <.card_footer>
              <.button variant="outline" size="sm">Cancel</.button>
              <.button size="sm">Save</.button>
            </.card_footer>
          </.card>
        </div>
        <.code_example>
          &lt;.card&gt;
          &lt;.card_header&gt;
          &lt;.card_title&gt;Card Title&lt;/.card_title&gt;
          &lt;.card_description&gt;Description&lt;/.card_description&gt;
          &lt;/.card_header&gt;
          &lt;.card_content&gt;
          &lt;p&gt;Content here.&lt;/p&gt;
          &lt;/.card_content&gt;
          &lt;.card_footer&gt;
          &lt;.button variant="outline" size="sm"&gt;Cancel&lt;/.button&gt;
          &lt;.button size="sm"&gt;Save&lt;/.button&gt;
          &lt;/.card_footer&gt;
          &lt;/.card&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
