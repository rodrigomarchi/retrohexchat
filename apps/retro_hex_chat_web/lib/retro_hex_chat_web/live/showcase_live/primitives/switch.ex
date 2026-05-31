defmodule RetroHexChatWeb.ShowcaseLive.Primitives.Switch do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Switch
  import RetroHexChatWeb.Components.UI.Label
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: dgettext("showcase", "Switch"), active_page: "switch")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Switch")}</h2>

      <.showcase_card
        title={dgettext("showcase", "Usage")}
        description="A control that allows the user to toggle between on and off."
      >
        <div class="space-y-3">
          <div class="flex items-center gap-2">
            <.switch id="switch-1" />
            <.label for="switch-1">{dgettext("showcase", "Airplane mode")}</.label>
          </div>
          <div class="flex items-center gap-2">
            <.switch id="switch-2" default-value={true} />
            <.label for="switch-2">{dgettext("showcase", "Dark mode")}</.label>
          </div>
        </div>
        <.code_example>
          &lt;.switch id="airplane" /&gt;
          &lt;.label for="airplane"&gt;Airplane mode&lt;/.label&gt;

          &lt;.switch id="dark" default-value=&#123;true&#125; /&gt;
          &lt;.label for="dark"&gt;Dark mode&lt;/.label&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
