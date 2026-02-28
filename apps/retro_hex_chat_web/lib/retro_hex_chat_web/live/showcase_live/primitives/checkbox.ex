defmodule RetroHexChatWeb.ShowcaseLive.Primitives.Checkbox do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Checkbox
  import RetroHexChatWeb.Components.UI.Label
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Checkbox", active_page: "checkbox")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Checkbox</h2>

      <.showcase_card
        title="Usage"
        description="A control that allows the user to toggle between checked and not checked."
      >
        <div class="space-y-2">
          <div class="flex items-center gap-2">
            <.checkbox id="check-1" />
            <.label for="check-1">Accept terms and conditions</.label>
          </div>
          <div class="flex items-center gap-2">
            <.checkbox id="check-2" default-value={true} />
            <.label for="check-2">Send notifications</.label>
          </div>
        </div>
        <.code_example>
          &lt;.checkbox id="terms" /&gt;
          &lt;.label for="terms"&gt;Accept terms&lt;/.label&gt;

          &lt;.checkbox id="notify" default-value=&#123;true&#125; /&gt;
          &lt;.label for="notify"&gt;Send notifications&lt;/.label&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
