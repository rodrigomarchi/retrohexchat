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
        <.window>
          <.window_title_bar title="C:\SETUP\install_server.exe" controls={[:close]}>
            <:icon><Icons.icon_terminal class="w-4 h-4" /></:icon>
          </.window_title_bar>
          <.window_body>
            <h2 id="install-heading" class="text-lg font-bold mb-3">
              Want your own server? Three steps.
            </h2>

            <div class="space-y-3 mb-3">
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

            <p class="text-sm">
              <strong>Requirements:</strong>
              Elixir 1.17+, PostgreSQL 16+, Node.js 20+.<br /> A $5/month VPS handles it just fine.
            </p>
          </.window_body>
          <.window_status_bar>
            <.window_status_bar_field grow>Installation complete</.window_status_bar_field>
          </.window_status_bar>
        </.window>
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
    <pre class="bg-canvas-bg text-canvas-fg p-3 text-xs font-mono">{@text}</pre>
    """
  end

  defp step_setup(assigns) do
    assigns = assign(assigns, :text, @setup_text)

    ~H"""
    <pre class="bg-canvas-bg text-canvas-fg p-3 text-xs font-mono">{@text}</pre>
    """
  end

  defp step_run(assigns) do
    assigns = assign(assigns, :text, @run_text)

    ~H"""
    <pre class="bg-canvas-bg text-canvas-fg p-3 text-xs font-mono">{@text}</pre>
    """
  end
end
