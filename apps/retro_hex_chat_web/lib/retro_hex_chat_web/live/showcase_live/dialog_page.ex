defmodule RetroHexChatWeb.ShowcaseLive.DialogPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Dialog", active_page: "dialog")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Dialog</h2>

      <.showcase_card title="Basic Dialog" description="Click the button to open a modal dialog.">
        <.button phx-click={show_modal("basic-dialog")}>
          <:icon><Icons.icon_btn_open /></:icon>
          Open Dialog
        </.button>
        <.dialog id="basic-dialog">
          <.dialog_header>
            <.dialog_icon>
              <Icons.icon_btn_edit />
            </.dialog_icon>
            <.dialog_title>Edit Profile</.dialog_title>
            <.dialog_close id="basic-dialog" />
          </.dialog_header>
          <.dialog_body>
            <.dialog_description class="mb-retro-8">
              Make changes to your profile here. Click save when you're done.
            </.dialog_description>
            <div class="flex items-center gap-retro-8 mb-retro-4">
              <label class="text-xs w-16 text-right">Name:</label>
              <input
                type="text"
                class="shadow-retro-field bg-white px-retro-4 py-retro-2 text-xs flex-1"
                value="Troll"
              />
            </div>
            <div class="flex items-center gap-retro-8">
              <label class="text-xs w-16 text-right">Username:</label>
              <input
                type="text"
                class="shadow-retro-field bg-white px-retro-4 py-retro-2 text-xs flex-1"
                value="@troll"
              />
            </div>
          </.dialog_body>
          <.dialog_footer>
            <.button variant="outline" phx-click={hide_modal("basic-dialog")}>
              <:icon><Icons.icon_btn_cancel /></:icon>
              Cancel
            </.button>
            <.button phx-click={hide_modal("basic-dialog")}>
              <:icon><Icons.icon_btn_save /></:icon>
              Save
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

      <.showcase_card title="Confirmation Dialog" description="A simple confirmation dialog.">
        <.button variant="destructive" phx-click={show_modal("confirm-dialog")}>
          <:icon><Icons.icon_btn_trash /></:icon>
          Delete Account
        </.button>
        <.dialog id="confirm-dialog">
          <.dialog_header>
            <.dialog_icon>
              <Icons.icon_dialog_delete />
            </.dialog_icon>
            <.dialog_title>Are you sure?</.dialog_title>
            <.dialog_close id="confirm-dialog" />
          </.dialog_header>
          <.dialog_body>
            <.dialog_description>
              This action cannot be undone. This will permanently delete your account.
            </.dialog_description>
          </.dialog_body>
          <.dialog_footer>
            <.button variant="outline" phx-click={hide_modal("confirm-dialog")}>
              <:icon><Icons.icon_btn_cancel /></:icon>
              Cancel
            </.button>
            <.button variant="destructive" phx-click={hide_modal("confirm-dialog")}>
              <:icon><Icons.icon_btn_trash /></:icon>
              Delete
            </.button>
          </.dialog_footer>
        </.dialog>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
