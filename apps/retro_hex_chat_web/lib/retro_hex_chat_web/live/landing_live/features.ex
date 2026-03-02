defmodule RetroHexChatWeb.LandingLive.Features do
  @moduledoc false
  use Phoenix.LiveView

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.Diagrams

  alias RetroHexChatWeb.Icons

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_page: :features,
       page_title: "Features — Retro Hex Chat",
       page_description:
         "Real-time chat, public and private channels, P2P voice and video calls, server administration, and IRC-style commands."
     )}
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <.landing_layout active_page={@active_page}>
      <section class="m-4" aria-labelledby="features-heading">
        <h2 id="features-heading" class="sr-only">Features</h2>

        <div class="grid md:grid-cols-2 gap-4 mb-4">
          <%!-- ══════════════ CHAT ══════════════ --%>
          <.window>
            <.window_title_bar title="Real-time Chat" controls={[:close]}>
              <:icon><Icons.icon_chat class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <h3 class="text-sm font-bold mb-2">
                Real-time chat. Zero refresh. Zero loading.
              </h3>
              <div class="shadow-retro-field bg-canvas-bg text-canvas-fg p-3 mb-2">
                <.chat_mockup />
              </div>
              <ul class="text-sm space-y-1">
                <li>Real-time messages via WebSocket</li>
                <li>Emoji reactions</li>
                <li>Threads (nested replies)</li>
                <li>Markdown and IRC formatting</li>
                <li>Link previews with metadata</li>
              </ul>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                <Icons.icon_checkmark class="w-3 h-3 inline" /> Live
              </.window_status_bar_field>
            </.window_status_bar>
          </.window>

          <%!-- ══════════════ CHANNELS ══════════════ --%>
          <.window>
            <.window_title_bar title="Channels" controls={[:close]}>
              <:icon><Icons.icon_channels class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <h3 class="text-sm font-bold mb-2">Channels are chat rooms.</h3>
              <ul class="text-sm space-y-1">
                <li>Create as many channels as you want</li>
                <li><strong>Public:</strong> anyone can join</li>
                <li><strong>Private:</strong> invite-only</li>
                <li><strong>Protected:</strong> password for restricted channels</li>
                <li>Topic, modes, slow mode &mdash; you control it</li>
              </ul>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                <Icons.icon_checkmark class="w-3 h-3 inline" /> Flexible
              </.window_status_bar_field>
            </.window_status_bar>
          </.window>

          <%!-- ══════════════ P2P ══════════════ --%>
          <.window>
            <.window_title_bar title="P2P Calls & Files" controls={[:close]}>
              <:icon><Icons.icon_p2p class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <h3 class="text-sm font-bold mb-2">
                Direct connection between people. Peer-to-peer.
              </h3>
              <div
                class="shadow-retro-field bg-white p-3 mb-2"
                aria-label="Voice call mockup"
              >
                <.diagram_voice_call_mockup class="w-full max-w-lg mx-auto" />
              </div>
              <ul class="text-sm space-y-1">
                <li>Voice calls &mdash; direct P2P via WebRTC</li>
                <li>Video calls with camera toggle</li>
                <li>File transfer &mdash; send files directly, no server upload</li>
                <li>Picture-in-Picture mode for multitasking</li>
                <li>Media controls: mute, camera, screen share</li>
                <li>End-to-end encrypted by default</li>
                <li>TURN relay fallback for strict firewalls</li>
              </ul>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                <Icons.icon_checkmark class="w-3 h-3 inline" /> Encrypted
              </.window_status_bar_field>
            </.window_status_bar>
          </.window>

          <%!-- ══════════════ ADMIN ══════════════ --%>
          <.window>
            <.window_title_bar title="Administration" controls={[:close]}>
              <:icon><Icons.icon_rules class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <h3 class="text-sm font-bold mb-2">Your server, your rules.</h3>
              <ul class="text-sm space-y-1">
                <li>Full administration panel</li>
                <li>User and channel management</li>
                <li>Rate limiting and moderation</li>
                <li>Real-time logs and metrics</li>
                <li>Backup and restore</li>
              </ul>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                <Icons.icon_checkmark class="w-3 h-3 inline" /> Full control
              </.window_status_bar_field>
            </.window_status_bar>
          </.window>
        </div>

        <%!-- ══════════════ COMMANDS (full width) ══════════════ --%>
        <.window>
          <.window_title_bar title="IRC Commands" controls={[:close]}>
            <:icon><Icons.icon_terminal class="w-4 h-4" /></:icon>
          </.window_title_bar>
          <.window_body>
            <h3 class="text-sm font-bold mb-2">Powerful IRC-style commands.</h3>
            <div class="shadow-retro-field bg-canvas-bg text-canvas-fg p-3 mb-2">
              <.commands_mockup />
            </div>
            <p class="text-sm">Over 20 commands with smart autocomplete.</p>
          </.window_body>
          <.window_status_bar>
            <.window_status_bar_field grow>
              <Icons.icon_checkmark class="w-3 h-3 inline" /> 20+ commands
            </.window_status_bar_field>
          </.window_status_bar>
        </.window>
      </section>
    </.landing_layout>
    """
  end

  @chat_mockup_text """
  #elixir
  ───────────────────

  ● alice                           10:23
    Good morning! Anyone tried Phoenix 1.8?

  ● bob                             10:24
    Yes! LiveView is amazing

  ● carol                           10:25
    Agreed, performance is way better\
  """

  defp chat_mockup(assigns) do
    assigns = assign(assigns, :text, @chat_mockup_text)

    ~H"""
    <pre class="text-xs font-mono whitespace-pre">{@text}</pre>
    """
  end

  @commands_mockup_text """
  /join #channel     → join a channel
  /msg @nick text    → direct message
  /nick new_nick     → change nickname
  /help              → see all commands
  /whois @nick       → info about a user\
  """

  defp commands_mockup(assigns) do
    assigns = assign(assigns, :text, @commands_mockup_text)

    ~H"""
    <pre class="text-xs font-mono whitespace-pre">{@text}</pre>
    """
  end
end
