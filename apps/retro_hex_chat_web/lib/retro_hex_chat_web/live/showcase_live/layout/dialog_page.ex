defmodule RetroHexChatWeb.ShowcaseLive.Layout.DialogPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Label
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Dialog"), active_page: "dialog")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Dialog")}</h2>

      <.showcase_card
        title={gettext("Basic Dialog")}
        description="Click the button to open a modal dialog."
      >
        <.button phx-click={show_modal("basic-dialog")}>
          <:icon><Icons.icon_btn_open /></:icon>
          {gettext("Open Dialog")}
        </.button>
        <.dialog id="basic-dialog">
          <.dialog_header id="basic-dialog" title={gettext("Edit Profile")}>
            <:icon><Icons.icon_btn_edit /></:icon>
          </.dialog_header>
          <.dialog_body>
            <.dialog_description class="mb-retro-8">
              {gettext("Make changes to your profile here. Click save when you're done.")}
            </.dialog_description>
            <div class="flex items-center gap-retro-8 mb-retro-4">
              <.label class="text-xs w-16 text-right">{gettext("Name:")}</.label>
              <.input type="text" value="Troll" class="flex-1" />
            </div>
            <div class="flex items-center gap-retro-8">
              <.label class="text-xs w-16 text-right">{gettext("Username:")}</.label>
              <.input type="text" value="@troll" class="flex-1" />
            </div>
          </.dialog_body>
          <.dialog_footer>
            <.button variant="outline" phx-click={hide_modal("basic-dialog")}>
              <:icon><Icons.icon_btn_cancel /></:icon>
              {gettext("Cancel")}
            </.button>
            <.button phx-click={hide_modal("basic-dialog")}>
              <:icon><Icons.icon_btn_save /></:icon>
              {gettext("Save")}
            </.button>
          </.dialog_footer>
        </.dialog>
        <.code_example>
          &lt;.button phx-click=&#123;show_modal("basic-dialog")&#125;&gt;
          &lt;:icon&gt;&lt;Icons.icon_btn_open /&gt;&lt;/:icon&gt;
          Open
          &lt;/.button&gt;
          &lt;.dialog id="basic-dialog"&gt;
          &lt;.dialog_header&gt;
          &lt;.dialog_icon&gt;&lt;Icons.icon_btn_edit /&gt;&lt;/.dialog_icon&gt;
          &lt;.dialog_title&gt;Edit Profile&lt;/.dialog_title&gt;
          &lt;.dialog_close id="basic-dialog" /&gt;
          &lt;/.dialog_header&gt;
          &lt;.dialog_body&gt;...&lt;/.dialog_body&gt;
          &lt;.dialog_footer&gt;
          &lt;.button&gt;&lt;:icon&gt;...&lt;/:icon&gt;Save&lt;/.button&gt;
          &lt;/.dialog_footer&gt;
          &lt;/.dialog&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title={gettext("Confirmation Dialog")}
        description="A simple confirmation dialog."
      >
        <.button variant="destructive" phx-click={show_modal("confirm-dialog")}>
          <:icon><Icons.icon_btn_trash /></:icon>
          {gettext("Delete Account")}
        </.button>
        <.dialog id="confirm-dialog">
          <.dialog_header id="confirm-dialog" title={gettext("Are you sure?")}>
            <:icon><Icons.icon_dialog_delete /></:icon>
          </.dialog_header>
          <.dialog_body>
            <.dialog_description>
              {gettext("This action cannot be undone. This will permanently delete your account.")}
            </.dialog_description>
          </.dialog_body>
          <.dialog_footer>
            <.button variant="outline" phx-click={hide_modal("confirm-dialog")}>
              <:icon><Icons.icon_btn_cancel /></:icon>
              {gettext("Cancel")}
            </.button>
            <.button variant="destructive" phx-click={hide_modal("confirm-dialog")}>
              <:icon><Icons.icon_btn_trash /></:icon>
              {gettext("Delete")}
            </.button>
          </.dialog_footer>
        </.dialog>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
