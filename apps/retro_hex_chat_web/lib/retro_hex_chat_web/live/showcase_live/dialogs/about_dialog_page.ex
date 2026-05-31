defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.AboutDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AboutDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, page_title: dgettext("showcase", "About Dialog"), active_page: "about-dialog")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "About Dialog")}</h2>

      <.showcase_card
        title={dgettext("showcase", "About Dialog")}
        description="Application info with logo, version, and credits."
      >
        <.button variant="outline" phx-click={show_modal("about-demo")}>
          <:icon><Icons.icon_lightbulb class="w-4 h-4" /></:icon>
          {dgettext("showcase", "About")}
        </.button>
        <.about_dialog id="about-demo" version="2.1.0" />
        <.code_example>
          &lt;.about_dialog id="about" version="2.1.0" /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
