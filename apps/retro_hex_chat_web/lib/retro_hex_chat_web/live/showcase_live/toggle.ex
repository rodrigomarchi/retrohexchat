defmodule RetroHexChatWeb.ShowcaseLive.Toggle do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Toggle
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Toggle", active_page: "toggle")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Toggle</h2>

      <.showcase_card title="Variants" description="A two-state button that can be toggled on or off.">
        <div class="flex gap-2">
          <.toggle>Toggle</.toggle>
          <.toggle variant="outline">Outline</.toggle>
        </div>
        <.code_example>
          &lt;.toggle&gt;Toggle&lt;/.toggle&gt;
          &lt;.toggle variant="outline"&gt;Outline&lt;/.toggle&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
