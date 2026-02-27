defmodule RetroHexChatWeb.ShowcaseLive.ToastPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Toast
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers

  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Toast", active_page: "toast")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Toast</h2>

      <.showcase_card
        title="Variants"
        description="Toast notifications with colored accent indicators for different message types."
      >
        <div class="space-y-3">
          <.toast id="demo-default" variant="default">
            <.toast_title>Notification</.toast_title>
            <.toast_description>This is a default notification.</.toast_description>
          </.toast>

          <.toast id="demo-success" variant="success">
            <.toast_title>Success</.toast_title>
            <.toast_description>Operation completed successfully.</.toast_description>
          </.toast>

          <.toast id="demo-error" variant="error">
            <.toast_title>Error</.toast_title>
            <.toast_description>Something went wrong. Please try again.</.toast_description>
          </.toast>

          <.toast id="demo-warning" variant="warning">
            <.toast_title>Warning</.toast_title>
            <.toast_description>This action cannot be undone.</.toast_description>
          </.toast>

          <.toast id="demo-info" variant="info">
            <.toast_title>Info</.toast_title>
            <.toast_description>A new version is available.</.toast_description>
          </.toast>
        </div>
        <.code_example>
          &lt;.toast id="my-toast" variant="success"&gt;
            &lt;.toast_title&gt;Success&lt;/.toast_title&gt;
            &lt;.toast_description&gt;Operation completed.&lt;/.toast_description&gt;
          &lt;/.toast&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="With Actions"
        description="Toasts can include an action area with buttons or other interactive elements."
      >
        <div class="space-y-3">
          <.toast id="demo-action" variant="info" dismissible={false}>
            <.toast_title>New tip available</.toast_title>
            <.toast_description>Did you know you can use /help to see all commands?</.toast_description>
            <.toast_action>
              <.button variant="outline" size="sm">
                <:icon><span class="w-4 h-4" /></:icon>
                Got it
              </.button>
            </.toast_action>
          </.toast>

          <.toast id="demo-action-2" variant="warning">
            <.toast_title>Unsaved changes</.toast_title>
            <.toast_description>You have unsaved changes that will be lost.</.toast_description>
            <.toast_action>
              <.button variant="outline" size="sm">
                <:icon><span class="w-4 h-4" /></:icon>
                Save now
              </.button>
            </.toast_action>
          </.toast>
        </div>
        <.code_example>
          &lt;.toast id="my-toast" variant="info"&gt;
            &lt;.toast_title&gt;New tip&lt;/.toast_title&gt;
            &lt;.toast_description&gt;Use /help for commands.&lt;/.toast_description&gt;
            &lt;.toast_action&gt;
              &lt;.button variant="outline" size="sm"&gt;
                &lt;:icon&gt;&lt;span class="w-4 h-4" /&gt;&lt;/:icon&gt;
                Got it
              &lt;/.button&gt;
            &lt;/.toast_action&gt;
          &lt;/.toast&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Non-dismissible"
        description="Toasts without the close button for persistent notifications."
      >
        <.toast id="demo-persistent" variant="error" dismissible={false}>
          <.toast_title>Connection lost</.toast_title>
          <.toast_description>Attempting to reconnect...</.toast_description>
        </.toast>
        <.code_example>
          &lt;.toast id="my-toast" variant="error" dismissible={false}&gt;
            &lt;.toast_title&gt;Connection lost&lt;/.toast_title&gt;
            &lt;.toast_description&gt;Reconnecting...&lt;/.toast_description&gt;
          &lt;/.toast&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Interactive Demo"
        description="Click buttons to show/dismiss toasts in the bottom-right corner."
      >
        <div class="flex flex-wrap gap-retro-4">
          <.button phx-click={JS.show(to: "#live-default", transition: {"transition-opacity duration-200", "opacity-0", "opacity-100"})}>
            <:icon><span class="w-4 h-4" /></:icon>
            Show Default
          </.button>
          <.button phx-click={JS.show(to: "#live-success", transition: {"transition-opacity duration-200", "opacity-0", "opacity-100"})}>
            <:icon><span class="w-4 h-4" /></:icon>
            Show Success
          </.button>
          <.button phx-click={JS.show(to: "#live-error", transition: {"transition-opacity duration-200", "opacity-0", "opacity-100"})}>
            <:icon><span class="w-4 h-4" /></:icon>
            Show Error
          </.button>
        </div>
        <.code_example>
          &lt;.toast_container position="bottom-right"&gt;
            &lt;.toast id="live-toast" variant="success"&gt;
              &lt;.toast_title&gt;Saved!&lt;/.toast_title&gt;
              &lt;.toast_description&gt;Changes saved.&lt;/.toast_description&gt;
            &lt;/.toast&gt;
          &lt;/.toast_container&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Container Positions"
        description="Toast containers can be positioned in any corner of the viewport."
      >
        <div class="text-xs text-muted-foreground space-y-1">
          <p><code class="bg-white px-1">position="top-right"</code> — Top right corner</p>
          <p><code class="bg-white px-1">position="top-left"</code> — Top left corner</p>
          <p><code class="bg-white px-1">position="bottom-right"</code> — Bottom right (default)</p>
          <p><code class="bg-white px-1">position="bottom-left"</code> — Bottom left corner</p>
        </div>
        <.code_example>
          &lt;.toast_container position="bottom-right"&gt;
            &lt;!-- toasts stack here --&gt;
          &lt;/.toast_container&gt;
        </.code_example>
      </.showcase_card>

      <%!-- Live toast container for interactive demo --%>
      <.toast_container position="bottom-right">
        <.toast
          id="live-default"
          variant="default"
          class="hidden"
          on_dismiss={JS.hide(to: "#live-default", transition: {"transition-opacity duration-150", "opacity-100", "opacity-0"})}
        >
          <.toast_title>Notification</.toast_title>
          <.toast_description>This is a default toast notification.</.toast_description>
        </.toast>
        <.toast
          id="live-success"
          variant="success"
          class="hidden"
          on_dismiss={JS.hide(to: "#live-success", transition: {"transition-opacity duration-150", "opacity-100", "opacity-0"})}
        >
          <.toast_title>Success</.toast_title>
          <.toast_description>Changes have been saved successfully.</.toast_description>
        </.toast>
        <.toast
          id="live-error"
          variant="error"
          class="hidden"
          on_dismiss={JS.hide(to: "#live-error", transition: {"transition-opacity duration-150", "opacity-100", "opacity-0"})}
        >
          <.toast_title>Error</.toast_title>
          <.toast_description>Failed to save changes. Try again.</.toast_description>
        </.toast>
      </.toast_container>
    </.showcase_layout>
    """
  end
end
