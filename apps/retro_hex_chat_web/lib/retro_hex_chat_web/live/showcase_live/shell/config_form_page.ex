defmodule RetroHexChatWeb.ShowcaseLive.Shell.ConfigFormPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.ConfigForm
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Label
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: gettext("Config Form"),
       active_page: "config-form",
       aliases: [
         %{name: "/hi", value: "/msg $1 hello!"},
         %{name: "/bye", value: "/msg $1 goodbye!"},
         %{name: "/away", value: "/away $1-"}
       ],
       perform_items: [
         %{name: "connect", value: "/join #lobby"},
         %{name: "connect", value: "/join #help"},
         %{name: "#lobby", value: "/msg ChanBot !seen admin"}
       ]
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Config Form")}</h2>

      <.showcase_card
        title={gettext("Alias Configuration")}
        description="Generic config pattern: list + edit form. Used for Alias, Perform, Flood Protection, etc."
      >
        <.button variant="outline" phx-click={show_modal("config-form-demo")}>
          <:icon><Icons.icon_btn_settings class="w-4 h-4" /></:icon>
          {gettext("Aliases")}
        </.button>
        <.config_form id="config-form-demo" title={gettext("Aliases")} items={@aliases}>
          <:form>
            <div class="space-y-retro-4">
              <div>
                <.label class="text-xs font-bold block mb-retro-2">{gettext("Name")}</.label>
                <.input type="text" placeholder={gettext("/alias")} class="w-full" />
              </div>
              <div>
                <.label class="text-xs font-bold block mb-retro-2">{gettext("Value")}</.label>
                <.input type="text" placeholder={gettext("/command $1")} class="w-full" />
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

      <.showcase_card
        title={gettext("Editing State")}
        description="Config form with a row selected and editing=true. The form header shows 'Edit' instead of 'Add'."
      >
        <.button variant="outline" phx-click={show_modal("config-form-editing")}>
          <:icon><Icons.icon_btn_settings class="w-4 h-4" /></:icon>
          {gettext("Aliases (Editing)")}
        </.button>
        <.config_form
          id="config-form-editing"
          title={gettext("Aliases")}
          items={@aliases}
          selected_index={1}
          editing={true}
        >
          <:form>
            <div class="space-y-retro-4">
              <div>
                <.label class="text-xs font-bold block mb-retro-2">{gettext("Name")}</.label>
                <.input type="text" value="/bye" class="w-full" />
              </div>
              <div>
                <.label class="text-xs font-bold block mb-retro-2">{gettext("Value")}</.label>
                <.input type="text" value="/msg $1 goodbye!" class="w-full" />
              </div>
            </div>
          </:form>
        </.config_form>
      </.showcase_card>

      <.showcase_card
        title={gettext("Custom Columns")}
        description="Config form with custom column headers (Event / Command) for a Perform config."
      >
        <.button variant="outline" phx-click={show_modal("config-form-perform")}>
          <:icon><Icons.icon_btn_settings class="w-4 h-4" /></:icon>
          {gettext("Perform")}
        </.button>
        <.config_form
          id="config-form-perform"
          title={gettext("Perform")}
          items={@perform_items}
          columns={["Event", "Command"]}
        >
          <:form>
            <div class="space-y-retro-4">
              <div>
                <.label class="text-xs font-bold block mb-retro-2">{gettext("Event")}</.label>
                <.input type="text" placeholder={gettext("connect / #channel")} class="w-full" />
              </div>
              <div>
                <.label class="text-xs font-bold block mb-retro-2">{gettext("Command")}</.label>
                <.input type="text" placeholder={gettext("/command args")} class="w-full" />
              </div>
            </div>
          </:form>
        </.config_form>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
