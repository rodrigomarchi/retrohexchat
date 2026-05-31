defmodule RetroHexChatWeb.ShowcaseLive.Dialogs.KickDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.KickDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog, only: [show_modal: 1]
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, page_title: dgettext("showcase", "Kick Dialog"), active_page: "kick-dialog")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{dgettext("showcase", "Kick Dialog")}</h2>

      <.showcase_card
        title={dgettext("showcase", "With Kick Info")}
        description="Notification shown when the user is kicked from a channel."
      >
        <.button variant="outline" phx-click={show_modal("kick-with-info")}>
          <:icon><Icons.icon_dialog_kick class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Show Kick Dialog")}
        </.button>
        <.kick_dialog
          id="kick-with-info"
          kick_info={%{channel: "#lobby", kicker: "Admin", reason: "Flooding"}}
        />
        <.code_example>
          &lt;.kick_dialog
          id="kick-notify"
          kick_info=&#123;%&#123;channel: "#lobby", kicker: "Admin", reason: "Flooding"&#125;&#125;
          /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={dgettext("showcase", "Without Kick Info")}
        description="Fallback message when no kick details are available."
      >
        <.button variant="outline" phx-click={show_modal("kick-no-info")}>
          <:icon><Icons.icon_dialog_kick class="w-4 h-4" /></:icon>
          {dgettext("showcase", "Show (no details)")}
        </.button>
        <.kick_dialog id="kick-no-info" />
        <.code_example>
          &lt;.kick_dialog id="kick-no-info" /&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
