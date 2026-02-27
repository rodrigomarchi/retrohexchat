defmodule RetroHexChatWeb.ShowcaseLive.Textarea do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Textarea
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Textarea", active_page: "textarea")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Textarea</h2>

      <.showcase_card title="Usage" description="Multi-line text input.">
        <div class="max-w-sm">
          <.textarea placeholder="Type your message here..." />
        </div>
        <.code_example>
          &lt;.textarea placeholder="Type your message here..." /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
