defmodule RetroHexChatWeb.LandingLive.Install do
  @moduledoc false
  use Phoenix.LiveView

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Window

  alias RetroHexChatWeb.Icons

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_page: :install,
       page_title: "Install Retro Hex Chat — Three steps to your own server",
       page_description:
         "Clone, setup, and run your own Retro Hex Chat server in three simple steps. System requirements and getting started guide."
     )}
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <.landing_layout active_page={@active_page}>
      <section class="m-4" aria-labelledby="install-heading">
        <h2 id="install-heading" class="sr-only">Installation</h2>

        <div class="grid md:grid-cols-2 gap-4">
          <%!-- ══════════════ STEPS ══════════════ --%>
          <.window>
            <.window_title_bar title="C:\SETUP\install_server.exe" controls={[:close]}>
              <:icon><Icons.icon_terminal class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <h3 class="text-sm font-bold mb-3">
                Want your own server? Three steps.
              </h3>

              <div class="space-y-3">
                <fieldset class="border-2 border-gray-400 p-3">
                  <legend class="text-sm font-bold px-1">
                    <Icons.icon_git class="w-4 h-4 inline" /> Step 1 &mdash; Clone
                  </legend>
                  <.step_clone />
                </fieldset>

                <fieldset class="border-2 border-gray-400 p-3">
                  <legend class="text-sm font-bold px-1">
                    <Icons.icon_wrench class="w-4 h-4 inline" /> Step 2 &mdash; Setup
                  </legend>
                  <.step_setup />
                </fieldset>

                <fieldset class="border-2 border-gray-400 p-3">
                  <legend class="text-sm font-bold px-1">
                    <Icons.icon_terminal class="w-4 h-4 inline" /> Step 3 &mdash; Run
                  </legend>
                  <.step_run />
                </fieldset>
              </div>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>Installation complete</.window_status_bar_field>
            </.window_status_bar>
          </.window>

          <%!-- ══════════════ REQUIREMENTS ══════════════ --%>
          <.window>
            <.window_title_bar title="System Requirements" controls={[:close]}>
              <:icon><Icons.icon_server class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <div class="space-y-2">
                <div class="shadow-retro-field bg-white p-3 text-sm">
                  <strong><Icons.icon_elixir class="w-4 h-4 inline" /> Elixir</strong>
                  &mdash; Version 1.17+
                </div>
                <div class="shadow-retro-field bg-white p-3 text-sm">
                  <strong><Icons.icon_postgres class="w-4 h-4 inline" /> PostgreSQL</strong>
                  &mdash; Version 16+
                </div>
                <div class="shadow-retro-field bg-white p-3 text-sm">
                  <strong><Icons.icon_code class="w-4 h-4 inline" /> Node.js</strong>
                  &mdash; Version 20+
                </div>
              </div>
              <p class="text-sm mt-3">
                A $5/month VPS handles it just fine.
              </p>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                <Icons.icon_checkmark class="w-3 h-3 inline" /> Ready to install
              </.window_status_bar_field>
            </.window_status_bar>
          </.window>
        </div>
      </section>
    </.landing_layout>
    """
  end

  @clone_text "$ git clone https://github.com/rodrigomarchi/retro_hex_chat.git\n$ cd retro_hex_chat"
  @setup_text "$ make setup"
  @run_text "$ make server\n[info] Running RetroHexChatWeb.Endpoint at http://localhost:4000"

  defp step_clone(assigns) do
    assigns = assign(assigns, :text, @clone_text)

    ~H"""
    <pre class="bg-canvas-bg text-canvas-fg p-3 text-xs font-mono overflow-x-auto">{@text}</pre>
    """
  end

  defp step_setup(assigns) do
    assigns = assign(assigns, :text, @setup_text)

    ~H"""
    <pre class="bg-canvas-bg text-canvas-fg p-3 text-xs font-mono overflow-x-auto">{@text}</pre>
    """
  end

  defp step_run(assigns) do
    assigns = assign(assigns, :text, @run_text)

    ~H"""
    <pre class="bg-canvas-bg text-canvas-fg p-3 text-xs font-mono overflow-x-auto">{@text}</pre>
    """
  end
end
