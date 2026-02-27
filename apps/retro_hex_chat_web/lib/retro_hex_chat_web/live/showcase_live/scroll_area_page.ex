defmodule RetroHexChatWeb.ShowcaseLive.ScrollAreaPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Scroll Area", active_page: "scroll-area")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Scroll Area &amp; Scrollbar</h2>

      <.showcase_card
        title="Retro Scrollbar"
        description="Win98-style scrollbar with arrow buttons and dithered track. Apply the retro-scrollbar class to any scrollable container."
      >
        <div class="shadow-retro-field bg-white h-[200px] overflow-y-auto retro-scrollbar p-2">
          <div class="text-xs space-y-1">
            <p :for={i <- 1..30} class="text-foreground">
              Line {i}: Lorem ipsum dolor sit amet, consectetur adipiscing elit.
            </p>
          </div>
        </div>
        <.code_example>
          &lt;div class="overflow-y-auto retro-scrollbar h-[200px]"&gt;
            &lt;!-- scrollable content --&gt;
          &lt;/div&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Horizontal Scrollbar"
        description="Horizontal scrollbar with left/right arrow buttons."
      >
        <div class="shadow-retro-field bg-white h-[100px] overflow-x-auto retro-scrollbar p-2">
          <div class="text-xs whitespace-nowrap" style="width: 1200px;">
            <p>This is a very long line that extends beyond the container width to demonstrate horizontal scrollbar behavior. It keeps going and going and going until you have to scroll right to read it all.</p>
            <p class="mt-2">Another long line: ABCDEFGHIJKLMNOPQRSTUVWXYZ ABCDEFGHIJKLMNOPQRSTUVWXYZ ABCDEFGHIJKLMNOPQRSTUVWXYZ ABCDEFGHIJKLMNOPQRSTUVWXYZ ABCDEFGHIJKLMNOPQRSTUVWXYZ</p>
          </div>
        </div>
        <.code_example>
          &lt;div class="overflow-x-auto retro-scrollbar"&gt;
            &lt;!-- wide content --&gt;
          &lt;/div&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Both Directions"
        description="Container with both vertical and horizontal scrollbars."
      >
        <div class="shadow-retro-field bg-white h-[200px] overflow-auto retro-scrollbar p-2">
          <div class="text-xs" style="width: 800px;">
            <p :for={i <- 1..25} class="text-foreground whitespace-nowrap">
              Line {i}: This is a wide line with lots of text to force both vertical and horizontal scrolling in the container.
            </p>
          </div>
        </div>
        <.code_example>
          &lt;div class="overflow-auto retro-scrollbar h-[200px]"&gt;
            &lt;!-- content exceeds both axes --&gt;
          &lt;/div&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
