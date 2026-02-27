defmodule RetroHexChatWeb.ShowcaseLive.ConfigFormPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.ConfigForm
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Config Form",
       active_page: "config-form",
       aliases: [
         %{name: "/hi", value: "/msg $1 hello!"},
         %{name: "/bye", value: "/msg $1 goodbye!"},
         %{name: "/away", value: "/away $1-"}
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Config Form</h2>

      <.showcase_card
        title="Alias Configuration"
        description="Generic config pattern: list + edit form. Used for Alias, Perform, Flood Protection, etc."
      >
        <.button variant="outline" phx-click={show_modal("config-form-demo")}>
          <:icon><Icons.icon_btn_settings class="w-4 h-4" /></:icon>
          Aliases
        </.button>
        <.config_form id="config-form-demo" title="Aliases" items={@aliases}>
          <:form>
            <div class="space-y-retro-4">
              <div>
                <label class="text-xs font-bold block mb-retro-2">Name</label>
                <.input type="text" placeholder="/alias" class="w-full" />
              </div>
              <div>
                <label class="text-xs font-bold block mb-retro-2">Value</label>
                <.input type="text" placeholder="/command $1" class="w-full" />
              </div>
            </div>
          </:form>
        </.config_form>
        <.code_example>
          &lt;.config_form id="aliases" title="Aliases" items=&#123;@aliases&#125;&gt;
            &lt;:form&gt;
              &lt;!-- Edit form fields --&gt;
            &lt;/:form&gt;
          &lt;/.config_form&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
