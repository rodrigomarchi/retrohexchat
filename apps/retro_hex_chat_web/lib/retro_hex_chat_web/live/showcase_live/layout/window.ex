defmodule RetroHexChatWeb.ShowcaseLive.Layout.Window do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Window", active_page: "window")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Window</h2>

      <.showcase_card
        title="Basic Window"
        description="A standard Win98 window with title bar and body."
      >
        <.window>
          <.window_title_bar title="My Computer" />
          <.window_body>
            <p class="text-sm">Window content goes here.</p>
          </.window_body>
        </.window>
        <.code_example>
          &lt;.window&gt;
          &lt;.window_title_bar title="My Computer" /&gt;
          &lt;.window_body&gt;
          &lt;p&gt;Window content goes here.&lt;/p&gt;
          &lt;/.window_body&gt;
          &lt;/.window&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Control Buttons"
        description="Title bar with minimize, maximize, and close controls."
      >
        <div class="space-y-3">
          <.window>
            <.window_title_bar title="All Controls" controls={[:minimize, :maximize, :close]} />
            <.window_body class="py-4">
              <p class="text-sm">Has minimize, maximize, and close buttons.</p>
            </.window_body>
          </.window>

          <.window>
            <.window_title_bar title="Close Only" controls={[:close]} />
            <.window_body class="py-4">
              <p class="text-sm">Dialog-style with close button only.</p>
            </.window_body>
          </.window>

          <.window>
            <.window_title_bar title="Help & Close" controls={[:help, :close]} />
            <.window_body class="py-4">
              <p class="text-sm">With help and close buttons.</p>
            </.window_body>
          </.window>
        </div>
        <.code_example>
          &lt;.window_title_bar title="All Controls" controls=&#123;[:minimize, :maximize, :close]&#125; /&gt;
          &lt;.window_title_bar title="Close Only" controls=&#123;[:close]&#125; /&gt;
          &lt;.window_title_bar title="Help &amp; Close" controls=&#123;[:help, :close]&#125; /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="Active vs Inactive" description="Windows change gradient when unfocused.">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <.window>
            <.window_title_bar title="Active Window" />
            <.window_body>
              <p class="text-sm">This window is focused.</p>
            </.window_body>
          </.window>

          <.window>
            <.window_title_bar title="Inactive Window" inactive />
            <.window_body>
              <p class="text-sm">This window is not focused.</p>
            </.window_body>
          </.window>
        </div>
        <.code_example>
          &lt;.window_title_bar title="Active Window" /&gt;
          &lt;.window_title_bar title="Inactive Window" inactive /&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="With Status Bar"
        description="Window with a segmented status bar at the bottom."
      >
        <.window>
          <.window_title_bar title="Notepad" controls={[:minimize, :maximize, :close]} />
          <.window_body>
            <div class="shadow-retro-field bg-white p-2 min-h-[80px]">
              <p class="text-sm font-mono">Hello, World!</p>
            </div>
          </.window_body>
          <.window_status_bar>
            <.window_status_bar_field grow>Ln 1, Col 14</.window_status_bar_field>
            <.window_status_bar_field>UTF-8</.window_status_bar_field>
            <.window_status_bar_field>Windows (CRLF)</.window_status_bar_field>
          </.window_status_bar>
        </.window>
        <.code_example>
          &lt;.window_status_bar&gt;
          &lt;.window_status_bar_field grow&gt;Ln 1, Col 14&lt;/.window_status_bar_field&gt;
          &lt;.window_status_bar_field&gt;UTF-8&lt;/.window_status_bar_field&gt;
          &lt;.window_status_bar_field&gt;Windows (CRLF)&lt;/.window_status_bar_field&gt;
          &lt;/.window_status_bar&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Dialog Style"
        description="A dialog window with icon in title bar and action buttons."
      >
        <div class="max-w-md mx-auto">
          <.window>
            <.window_title_bar title="Sounds" controls={[:close]} />
            <.window_body>
              <p class="text-sm mb-4">Configure event sounds for the application.</p>
              <div class="flex justify-end gap-2">
                <.button size="sm">OK</.button>
                <.button variant="outline" size="sm">Cancel</.button>
                <.button variant="outline" size="sm">Apply</.button>
              </div>
            </.window_body>
          </.window>
        </div>
        <.code_example>
          &lt;.window&gt;
          &lt;.window_title_bar title="Sounds" controls=&#123;[:close]&#125; /&gt;
          &lt;.window_body&gt;
          &lt;p&gt;Configure event sounds.&lt;/p&gt;
          &lt;div class="flex justify-end gap-2"&gt;
          &lt;.button size="sm"&gt;OK&lt;/.button&gt;
          &lt;.button variant="outline" size="sm"&gt;Cancel&lt;/.button&gt;
          &lt;/div&gt;
          &lt;/.window_body&gt;
          &lt;/.window&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
