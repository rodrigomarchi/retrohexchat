defmodule RetroHexChatWeb.ShowcaseLive.Primitives.AlertDialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.AlertDialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Alert Dialog"), active_page: "alert-dialog")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Alert Dialog")}</h2>

      <.showcase_card
        title={gettext("Default")}
        description="Alert dialog for confirming important actions."
      >
        <.alert_dialog :let={builder} id="alert-default">
          <.alert_dialog_trigger builder={builder}>
            <.button variant="outline">
              <:icon><Icons.icon_warning class="w-4 h-4" /></:icon>
              {gettext("Show Alert Dialog")}
            </.button>
          </.alert_dialog_trigger>
          <.alert_dialog_content builder={builder}>
            <.alert_dialog_header>
              <:icon><Icons.icon_warning class="w-4 h-4" /></:icon>
              <.alert_dialog_title>{gettext("Are you absolutely sure?")}</.alert_dialog_title>
              <.alert_dialog_description>
                {gettext(
                  "This action cannot be undone. This will permanently delete your account and remove your data from our servers."
                )}
              </.alert_dialog_description>
            </.alert_dialog_header>
            <.alert_dialog_footer>
              <.alert_dialog_cancel builder={builder}>{gettext("Cancel")}</.alert_dialog_cancel>
              <.alert_dialog_action>{gettext("Continue")}</.alert_dialog_action>
            </.alert_dialog_footer>
          </.alert_dialog_content>
        </.alert_dialog>
        <.code_example>
          &lt;.alert_dialog :let=&#123;builder&#125; id="alert"&gt;
          &lt;.alert_dialog_trigger builder=&#123;builder&#125;&gt;
          &lt;.button&gt;Show Alert&lt;/.button&gt;
          &lt;/.alert_dialog_trigger&gt;
          &lt;.alert_dialog_content builder=&#123;builder&#125;&gt;
          &lt;.alert_dialog_header&gt;
          &lt;:icon&gt;&lt;Icons.icon_warning /&gt;&lt;/:icon&gt;
          &lt;.alert_dialog_title&gt;Title&lt;/.alert_dialog_title&gt;
          &lt;.alert_dialog_description&gt;Description&lt;/.alert_dialog_description&gt;
          &lt;/.alert_dialog_header&gt;
          &lt;.alert_dialog_footer&gt;
          &lt;.alert_dialog_cancel builder=&#123;builder&#125;&gt;Cancel&lt;/.alert_dialog_cancel&gt;
          &lt;.alert_dialog_action&gt;Continue&lt;/.alert_dialog_action&gt;
          &lt;/.alert_dialog_footer&gt;
          &lt;/.alert_dialog_content&gt;
          &lt;/.alert_dialog&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("Destructive")}
        description="Alert dialog with destructive action styling."
      >
        <.alert_dialog :let={builder} id="alert-destructive">
          <.alert_dialog_trigger builder={builder}>
            <.button variant="destructive">
              <:icon><Icons.icon_btn_remove class="w-4 h-4" /></:icon>
              {gettext("Delete Account")}
            </.button>
          </.alert_dialog_trigger>
          <.alert_dialog_content builder={builder}>
            <.alert_dialog_header>
              <:icon><Icons.icon_warning class="w-4 h-4 text-destructive" /></:icon>
              <.alert_dialog_title>{gettext("Delete Account")}</.alert_dialog_title>
              <.alert_dialog_description>
                {gettext(
                  "This will permanently delete your account and all associated data. This action cannot be reversed."
                )}
              </.alert_dialog_description>
            </.alert_dialog_header>
            <.alert_dialog_footer>
              <.alert_dialog_cancel builder={builder}>{gettext("Cancel")}</.alert_dialog_cancel>
              <.alert_dialog_action class="bg-destructive text-destructive-foreground hover:bg-destructive/90">
                {gettext("Delete")}
              </.alert_dialog_action>
            </.alert_dialog_footer>
          </.alert_dialog_content>
        </.alert_dialog>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
