defmodule RetroHexChatWeb.ShowcaseLive.Label do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Label
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Label", active_page: "label")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Label</h2>

      <.showcase_card
        title="Usage"
        description="Caption for form fields. Associates with inputs via for attribute."
      >
        <div class="space-y-2 max-w-sm">
          <.label for="demo-input">Username</.label>
          <.input id="demo-input" type="text" placeholder="Enter username..." />
        </div>
        <.code_example>
          &lt;.label for="username"&gt;Username&lt;/.label&gt;
          &lt;.input id="username" type="text" placeholder="Enter username..." /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
