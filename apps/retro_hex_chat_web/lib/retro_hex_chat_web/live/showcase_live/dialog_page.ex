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
        <.button phx-click={show_modal("basic-dialog")}>Open Dialog</.button>
        <.dialog id="basic-dialog">
          <.dialog_header>
            <.dialog_title>Edit Profile</.dialog_title>
            <.dialog_description>
              Make changes to your profile here. Click save when you're done.
            </.dialog_description>
          </.dialog_header>
          <div class="py-4">
            <div class="flex items-center gap-2 mb-2">
              <label class="text-sm w-20 text-right">Name:</label>
              <input
                type="text"
                class="shadow-retro-field bg-white px-2 py-1 text-sm flex-1"
                value="Troll"
              />
            </div>
            <div class="flex items-center gap-2">
              <label class="text-sm w-20 text-right">Username:</label>
              <input
                type="text"
                class="shadow-retro-field bg-white px-2 py-1 text-sm flex-1"
                value="@troll"
              />
            </div>
          </div>
          <.dialog_footer>
            <.button variant="outline" phx-click={hide_modal("basic-dialog")}>Cancel</.button>
            <.button phx-click={hide_modal("basic-dialog")}>Save</.button>
          </.dialog_footer>
        </.dialog>
        <.code_example>
          &lt;.button phx-click=&#123;show_modal("basic-dialog")&#125;&gt;Open&lt;/.button&gt;
          &lt;.dialog id="basic-dialog"&gt;
          &lt;.dialog_header&gt;
          &lt;.dialog_title&gt;Edit Profile&lt;/.dialog_title&gt;
          &lt;/.dialog_header&gt;
          &lt;.dialog_footer&gt;
          &lt;.button phx-click=&#123;hide_modal("basic-dialog")&#125;&gt;Save&lt;/.button&gt;
          &lt;/.dialog_footer&gt;
          &lt;/.dialog&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="Confirmation Dialog" description="A simple confirmation dialog.">
        <.button variant="destructive" phx-click={show_modal("confirm-dialog")}>
          Delete Account
        </.button>
        <.dialog id="confirm-dialog">
          <.dialog_header>
            <.dialog_title>Are you sure?</.dialog_title>
            <.dialog_description>
              This action cannot be undone. This will permanently delete your account.
            </.dialog_description>
          </.dialog_header>
          <.dialog_footer>
            <.button variant="outline" phx-click={hide_modal("confirm-dialog")}>Cancel</.button>
            <.button variant="destructive" phx-click={hide_modal("confirm-dialog")}>Delete</.button>
          </.dialog_footer>
        </.dialog>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
