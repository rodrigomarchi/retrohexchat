defmodule RetroHexChatWeb.ShowcaseLive.Shell.StatusBar do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Status Bar", active_page: "status-bar")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Status Bar</h2>

      <.showcase_card title="Basic Status Bar" description="A simple status bar with text fields.">
        <.window>
          <.window_title_bar title="Application" />
          <.window_body>
            <div class="shadow-retro-field bg-white p-2 min-h-[40px]">
              <p class="text-sm font-mono">Content area</p>
            </div>
          </.window_body>
          <.window_status_bar>
            <.window_status_bar_field grow>Ready</.window_status_bar_field>
          </.window_status_bar>
        </.window>
        <.code_example>
          &lt;.window_status_bar&gt;
          &lt;.window_status_bar_field grow&gt;Ready&lt;/.window_status_bar_field&gt;
          &lt;/.window_status_bar&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card title="Multi-Field Status Bar" description="Status bar with multiple segments.">
        <.window_status_bar>
          <.window_status_bar_field grow>Ln 42, Col 8</.window_status_bar_field>
          <.window_status_bar_field>Spaces: 2</.window_status_bar_field>
          <.window_status_bar_field>UTF-8</.window_status_bar_field>
          <.window_status_bar_field>LF</.window_status_bar_field>
          <.window_status_bar_field>Elixir</.window_status_bar_field>
        </.window_status_bar>
        <.code_example>
          &lt;.window_status_bar&gt;
          &lt;.window_status_bar_field grow&gt;Ln 42, Col 8&lt;/.window_status_bar_field&gt;
          &lt;.window_status_bar_field&gt;Spaces: 2&lt;/.window_status_bar_field&gt;
          &lt;.window_status_bar_field&gt;UTF-8&lt;/.window_status_bar_field&gt;
          &lt;.window_status_bar_field&gt;LF&lt;/.window_status_bar_field&gt;
          &lt;.window_status_bar_field&gt;Elixir&lt;/.window_status_bar_field&gt;
          &lt;/.window_status_bar&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="With Status Indicators"
        description="Status fields with colored dots and icons."
      >
        <.window_status_bar>
          <.window_status_bar_field>
            <span class="inline-flex items-center gap-1">
              <span class="w-2 h-2 rounded-full bg-online inline-block" /> Troll
            </span>
          </.window_status_bar_field>
          <.window_status_bar_field>
            <span class="inline-flex items-center gap-1">#lobby</span>
          </.window_status_bar_field>
          <.window_status_bar_field>
            <span class="inline-flex items-center gap-1">
              <span class="w-2 h-2 rounded-full bg-online inline-block" /> On
            </span>
          </.window_status_bar_field>
          <.window_status_bar_field>Lag: 8ms</.window_status_bar_field>
          <.window_status_bar_field>13:24 UTC-3</.window_status_bar_field>
          <.window_status_bar_field>Vol</.window_status_bar_field>
        </.window_status_bar>
        <.code_example>
          &lt;.window_status_bar_field&gt;
          &lt;span class="inline-flex items-center gap-1"&gt;
          &lt;span class="w-2 h-2 rounded-full bg-online" /&gt; Troll
          &lt;/span&gt;
          &lt;/.window_status_bar_field&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Platform IRC Status Bar"
        description="Full replication of the platform's bottom status bar."
      >
        <.window>
          <.window_title_bar title="RetroHexChat" controls={[:minimize, :maximize, :close]} />
          <.window_body>
            <div class="shadow-retro-field bg-white p-2 min-h-[60px]">
              <p class="text-sm font-mono text-gray-500 italic">Chat content area...</p>
            </div>
          </.window_body>
          <.window_status_bar>
            <.window_status_bar_field>
              <span class="inline-flex items-center gap-1">
                <span class="w-2 h-2 rounded-full bg-online inline-block" /> Troll
              </span>
            </.window_status_bar_field>
            <.window_status_bar_field grow>
              <span class="inline-flex items-center gap-1">#lobby (4)</span>
            </.window_status_bar_field>
            <.window_status_bar_field>
              <span class="inline-flex items-center gap-1">
                <span class="w-2 h-2 rounded-full bg-online inline-block" /> On
              </span>
            </.window_status_bar_field>
            <.window_status_bar_field>Lag: --</.window_status_bar_field>
            <.window_status_bar_field>13:23 UTC-3</.window_status_bar_field>
          </.window_status_bar>
        </.window>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
