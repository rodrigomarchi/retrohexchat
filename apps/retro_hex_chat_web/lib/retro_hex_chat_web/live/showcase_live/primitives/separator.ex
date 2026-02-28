defmodule RetroHexChatWeb.ShowcaseLive.Primitives.Separator do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Separator
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Separator", active_page: "separator")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Separator</h2>

      <.showcase_card title="Usage" description="Visually divides content.">
        <div class="space-y-4 max-w-sm">
          <div>
            <h4 class="text-sm font-bold">Section A</h4>
            <p class="text-sm">Content above the separator.</p>
          </div>
          <.separator />
          <div>
            <h4 class="text-sm font-bold">Section B</h4>
            <p class="text-sm">Content below the separator.</p>
          </div>
        </div>
        <.code_example>
          &lt;.separator /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
