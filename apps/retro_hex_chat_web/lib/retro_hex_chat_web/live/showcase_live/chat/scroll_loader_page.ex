defmodule RetroHexChatWeb.ShowcaseLive.Chat.ScrollLoaderPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ScrollLoader
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Scroll Loader", active_page: "scroll-loader")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Scroll Loader</h2>

      <.showcase_card
        title="Loading State"
        description="Animated progress bar shown while older messages are being fetched."
      >
        <.scroll_loader loading={true} />
        <.code_example>
          &lt;.scroll_loader loading={true} /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Idle State"
        description="Nothing rendered when loading is false — the component is invisible."
      >
        <div class="shadow-retro-field bg-white p-3 min-h-[48px] flex items-center justify-center">
          <span class="text-xs text-muted-foreground">(empty — scroll_loader renders nothing)</span>
        </div>
        <.scroll_loader loading={false} />
        <.code_example>
          &lt;.scroll_loader loading={false} /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
