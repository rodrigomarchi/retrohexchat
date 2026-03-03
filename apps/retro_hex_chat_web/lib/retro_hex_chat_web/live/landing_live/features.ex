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
         "Real-time chat, channels, P2P voice/video calls, 28 multiplayer games, " <>
           "18 classic arcade games, programmable bots, IRC-style commands, and built-in help."
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
              <div class="space-y-1.5">
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_websocket class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>Real-time messages via <strong>WebSocket</strong></span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_fmt_emoji class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>Emoji reactions and inline formatting</span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_chat class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>Threads, nested replies, and direct messages</span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_link class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>Link previews with rich metadata</span>
                </div>
              </div>
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
              <div class="shadow-retro-field bg-canvas-bg text-canvas-fg p-3 mb-2">
                <.channel_list_mockup />
              </div>
              <div class="space-y-1.5">
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_channels class="w-4 h-4 shrink-0 mt-0.5" />
                  <span><strong>Public:</strong> open to anyone who wants to join</span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_lock class="w-4 h-4 shrink-0 mt-0.5" />
                  <span><strong>Private:</strong> invite-only for your group</span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_security class="w-4 h-4 shrink-0 mt-0.5" />
                  <span><strong>Protected:</strong> password-gated access</span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_btn_settings class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>Topic, modes, slow mode &mdash; you control it</span>
                </div>
              </div>
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
              <div class="space-y-1.5">
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_microphone class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>Voice calls &mdash; direct P2P via WebRTC</span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_camera class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>Video calls with camera toggle and PiP</span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_file_send class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>File transfer &mdash; send files directly, no upload</span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_shield class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>End-to-end encrypted with TURN relay fallback</span>
                </div>
              </div>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                <Icons.icon_checkmark class="w-3 h-3 inline" /> Encrypted
              </.window_status_bar_field>
            </.window_status_bar>
          </.window>

          <%!-- ══════════════ P2P GAMES ══════════════ --%>
          <.window>
            <.window_title_bar title="Multiplayer Games" controls={[:close]}>
              <:icon><Icons.icon_joystick class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <h3 class="text-sm font-bold mb-2">
                28 multiplayer games via WebRTC.
              </h3>
              <div class="shadow-retro-field bg-white p-3 mb-2">
                <div class="grid grid-cols-4 gap-2 justify-items-center">
                  <div class="flex flex-col items-center gap-0.5">
                    <Icons.icon_game_pong class="w-8 h-8" />
                    <span class="text-[9px]">Pong</span>
                  </div>
                  <div class="flex flex-col items-center gap-0.5">
                    <Icons.icon_game_space class="w-8 h-8" />
                    <span class="text-[9px]">Star Duel</span>
                  </div>
                  <div class="flex flex-col items-center gap-0.5">
                    <Icons.icon_game_tanks class="w-8 h-8" />
                    <span class="text-[9px]">Tanks</span>
                  </div>
                  <div class="flex flex-col items-center gap-0.5">
                    <Icons.icon_game_trails class="w-8 h-8" />
                    <span class="text-[9px]">Trails</span>
                  </div>
                  <div class="flex flex-col items-center gap-0.5">
                    <Icons.icon_game_boxing class="w-8 h-8" />
                    <span class="text-[9px]">Boxing</span>
                  </div>
                  <div class="flex flex-col items-center gap-0.5">
                    <Icons.icon_game_hockey class="w-8 h-8" />
                    <span class="text-[9px]">Hockey</span>
                  </div>
                  <div class="flex flex-col items-center gap-0.5">
                    <Icons.icon_game_invaders class="w-8 h-8" />
                    <span class="text-[9px]">Invaders</span>
                  </div>
                  <div class="flex flex-col items-center gap-0.5">
                    <Icons.icon_game_enduro class="w-8 h-8" />
                    <span class="text-[9px]">Enduro</span>
                  </div>
                </div>
              </div>
              <div class="space-y-1.5">
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_terminal class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>Challenge anyone with <strong>/game @nick</strong></span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_webrtc class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>Real-time sync via WebRTC DataChannel</span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_p2p class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>No server &mdash; same P2P tech as voice calls</span>
                </div>
              </div>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                <Icons.icon_checkmark class="w-3 h-3 inline" /> 28 games
              </.window_status_bar_field>
            </.window_status_bar>
          </.window>

          <%!-- ══════════════ SOLO ARCADE ══════════════ --%>
          <.window>
            <.window_title_bar title="Solo Arcade" controls={[:close]}>
              <:icon><Icons.icon_game_arcade class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <h3 class="text-sm font-bold mb-2">
                18 classic games via WebAssembly.
              </h3>
              <div class="shadow-retro-field bg-white p-3 mb-2">
                <div class="grid grid-cols-4 gap-2 justify-items-center">
                  <div class="flex flex-col items-center gap-0.5">
                    <Icons.icon_game_doom class="w-8 h-8" />
                    <span class="text-[9px]">DOOM</span>
                  </div>
                  <div class="flex flex-col items-center gap-0.5">
                    <Icons.icon_game_quake class="w-8 h-8" />
                    <span class="text-[9px]">Quake</span>
                  </div>
                  <div class="flex flex-col items-center gap-0.5">
                    <Icons.icon_game_wolfenstein class="w-8 h-8" />
                    <span class="text-[9px]">Wolf3D</span>
                  </div>
                  <div class="flex flex-col items-center gap-0.5">
                    <Icons.icon_game_halflife class="w-8 h-8" />
                    <span class="text-[9px]">Half-Life</span>
                  </div>
                  <div class="flex flex-col items-center gap-0.5">
                    <Icons.icon_game_bass class="w-8 h-8" />
                    <span class="text-[9px]">BASS</span>
                  </div>
                  <div class="flex flex-col items-center gap-0.5">
                    <Icons.icon_game_drascula class="w-8 h-8" />
                    <span class="text-[9px]">Drascula</span>
                  </div>
                  <div class="flex flex-col items-center gap-0.5">
                    <Icons.icon_game_fotaq class="w-8 h-8" />
                    <span class="text-[9px]">FOTAQ</span>
                  </div>
                  <div class="flex flex-col items-center gap-0.5">
                    <Icons.icon_game_quake2 class="w-8 h-8" />
                    <span class="text-[9px]">Quake II</span>
                  </div>
                </div>
              </div>
              <div class="space-y-1.5">
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_channels class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>
                    Join <strong>#games</strong>
                    channel (<code class="text-[10px]">/join #games</code>)
                  </span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_terminal class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>Type <strong>!play</strong> &mdash; the bot sends you an arcade link</span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_code class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>Runs entirely in the browser via WebAssembly</span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_laptop class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>No downloads, no plugins &mdash; opens in a new window</span>
                </div>
              </div>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                <Icons.icon_checkmark class="w-3 h-3 inline" /> 18 games
              </.window_status_bar_field>
            </.window_status_bar>
          </.window>

          <%!-- ══════════════ BOTS ══════════════ --%>
          <.window>
            <.window_title_bar title="Bots" controls={[:close]}>
              <:icon><Icons.icon_robot class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <h3 class="text-sm font-bold mb-2">
                Programmable bots with pluggable capabilities.
              </h3>
              <div class="shadow-retro-field bg-canvas-bg text-canvas-fg p-3 mb-2">
                <.bot_mockup />
              </div>
              <div class="space-y-1.5">
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_question class="w-4 h-4 shrink-0 mt-0.5" />
                  <span><strong>Trivia:</strong> quiz games with leaderboards</span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_dice class="w-4 h-4 shrink-0 mt-0.5" />
                  <span><strong>Dice:</strong> RPG-style rolling (!roll 2d6+3)</span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_ban class="w-4 h-4 shrink-0 mt-0.5" />
                  <span><strong>Moderation:</strong> word filters and spam detection</span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_rss class="w-4 h-4 shrink-0 mt-0.5" />
                  <span><strong>RSS:</strong> feed monitoring with announcements</span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_clock class="w-4 h-4 shrink-0 mt-0.5" />
                  <span><strong>Scheduler:</strong> timed messages and reminders</span>
                </div>
              </div>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                <Icons.icon_checkmark class="w-3 h-3 inline" /> Extensible
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
              <div class="space-y-2 mb-2">
                <div class="shadow-retro-field bg-white p-2 text-xs">
                  <strong>
                    <Icons.icon_dialog_admin_console class="w-4 h-4 inline" /> Admin Panel
                  </strong>
                  <br /> Full dashboard with real-time logs and metrics.
                </div>
                <div class="shadow-retro-field bg-white p-2 text-xs">
                  <strong>
                    <Icons.icon_community class="w-4 h-4 inline" /> User Management
                  </strong>
                  <br /> Accounts, roles, bans, and registration control.
                </div>
                <div class="shadow-retro-field bg-white p-2 text-xs">
                  <strong>
                    <Icons.icon_shield class="w-4 h-4 inline" /> Moderation
                  </strong>
                  <br /> Rate limiting, flood protection, and word filters.
                </div>
                <div class="shadow-retro-field bg-white p-2 text-xs">
                  <strong>
                    <Icons.icon_backup class="w-4 h-4 inline" /> Backup &amp; Restore
                  </strong>
                  <br /> Export and import your data anytime.
                </div>
              </div>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                <Icons.icon_checkmark class="w-3 h-3 inline" /> Full control
              </.window_status_bar_field>
            </.window_status_bar>
          </.window>

          <%!-- ══════════════ HELP SYSTEM ══════════════ --%>
          <.window>
            <.window_title_bar title="Built-in Help" controls={[:close]}>
              <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <h3 class="text-sm font-bold mb-2">
                CHM-style help system built in.
              </h3>
              <div class="shadow-retro-field bg-canvas-bg text-canvas-fg p-3 mb-2">
                <.help_mockup />
              </div>
              <div class="space-y-1.5">
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_btn_help_topics class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>Press <strong>F1</strong> or type <strong>/help</strong> anywhere</span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_btn_search class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>Searchable topics with keyword matching</span>
                </div>
                <div class="flex items-start gap-2 text-xs">
                  <Icons.icon_link class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>Cross-referenced &ldquo;See Also&rdquo; links</span>
                </div>
              </div>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                <Icons.icon_checkmark class="w-3 h-3 inline" /> Self-documented
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

  @channel_list_mockup_text """
  #general       23 users  Welcome to the server!
  #elixir        12 users  Elixir & Phoenix talk
  #gaming         8 users  Game nights every Friday
  #private    🔒  3 users  Invite only\
  """

  defp channel_list_mockup(assigns) do
    assigns = assign(assigns, :text, @channel_list_mockup_text)

    ~H"""
    <pre class="text-xs font-mono whitespace-pre">{@text}</pre>
    """
  end

  @bot_mockup_text """
  ● TriviaBot                       14:30
    🎯 Category: Science
    Q: What planet has the most moons?
  ● alice                           14:31
    Saturn
  ● TriviaBot                       14:31
    ✓ Correct! alice scores 3 points\
  """

  defp bot_mockup(assigns) do
    assigns = assign(assigns, :text, @bot_mockup_text)

    ~H"""
    <pre class="text-xs font-mono whitespace-pre">{@text}</pre>
    """
  end

  @help_mockup_text """
  Help Topics
  ─────────────────────
  ▸ Getting Started
  ▸ Commands
    ▸ /join   ▸ /msg
    ▸ /call   ▸ /game
  ▸ Features
  ▸ Keyboard Shortcuts\
  """

  defp help_mockup(assigns) do
    assigns = assign(assigns, :text, @help_mockup_text)

    ~H"""
    <pre class="text-xs font-mono whitespace-pre">{@text}</pre>
    """
  end
end
