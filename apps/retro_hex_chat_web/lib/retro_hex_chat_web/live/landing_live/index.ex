defmodule RetroHexChatWeb.LandingLive.Index do
  @moduledoc false
  use Phoenix.LiveView

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.Diagrams

  alias Phoenix.LiveView.JS
  alias RetroHexChatWeb.Icons

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_page: :home)}
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <.landing_layout active_page={@active_page}>
      <%!-- ══════════════ HERO + DESKTOP ══════════════ --%>
      <section class="m-4" aria-labelledby="hero-heading">
        <div class="grid md:grid-cols-[1fr_auto] gap-4">
          <.window>
            <.window_title_bar title="Retro Hex Chat — Welcome" controls={[:close]}>
              <:icon><Icons.icon_chat class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body class="text-center py-6">
              <h1 id="hero-heading" class="mb-3">
                <img
                  src="/images/landing/wordmark.svg"
                  alt="Retro Hex Chat"
                  class="inline-block max-w-[400px] w-full"
                />
              </h1>

              <p class="text-sm mb-2">
                Your server. Your conversations. Nobody in between.<br />
                Built with today&rsquo;s technology.
              </p>

              <p class="text-xs mb-4">
                Run your own server. Your data stays with you.<br />
                Voice and video calls go directly between users &mdash; no middleman.<br />
                No corporation. No algorithms. No permission needed.<br />
                <strong>Your data. Your rules. Your community.</strong>
              </p>

              <div class="mb-3">
                <a href="/connect" class="no-underline">
                  <button
                    type="button"
                    class="inline-flex items-center gap-1 h-9 px-4 text-sm shadow-retro-raised bg-surface active:shadow-retro-sunken font-bold"
                  >
                    <Icons.icon_connect class="w-4 h-4" /> Connect
                  </button>
                </a>
              </div>

              <p class="text-xs text-gray-600">
                Open source project &bull; Built with Elixir &amp; Phoenix
              </p>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>Ready</.window_status_bar_field>
              <.window_status_bar_field>v0.1.0</.window_status_bar_field>
            </.window_status_bar>
          </.window>

          <.window class="md:w-[200px]">
            <.window_title_bar title="C:\Desktop" controls={[:close]}>
              <:icon><Icons.icon_folder class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <div class="grid grid-cols-2 gap-4 justify-items-center py-2">
                <a
                  href="/features"
                  class="flex flex-col items-center gap-1 text-xs no-underline text-text hover:underline"
                >
                  <Icons.icon_folder class="w-8 h-8" />
                  <span>My Chats</span>
                </a>
                <a
                  href="/privacy"
                  class="flex flex-col items-center gap-1 text-xs no-underline text-text hover:underline"
                >
                  <Icons.icon_lock class="w-8 h-8" />
                  <span>Privacy</span>
                </a>
                <button
                  type="button"
                  class="flex flex-col items-center gap-1 text-xs bg-transparent border-0 cursor-pointer hover:underline"
                  phx-click={JS.show(to: "#readme-popup")}
                >
                  <Icons.icon_notepad class="w-8 h-8" />
                  <span>README.txt</span>
                </button>
                <button
                  type="button"
                  class="flex flex-col items-center gap-1 text-xs bg-transparent border-0 cursor-pointer hover:underline"
                  phx-click={JS.show(to: "#trash-popup")}
                >
                  <Icons.icon_trash class="w-8 h-8" />
                  <span>Trash</span>
                </button>
              </div>
            </.window_body>
          </.window>
        </div>
      </section>

      <%!-- ══════════════ THE PROBLEM + THE SOLUTION ══════════════ --%>
      <section class="m-4" aria-labelledby="problem-heading">
        <div class="grid md:grid-cols-2 gap-4 mb-4">
          <.window>
            <.window_title_bar title="The Problem" controls={[:close]}>
              <:icon><Icons.icon_warning class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <h2 id="problem-heading" class="text-sm font-bold mb-2">
                Your community isn&rsquo;t yours.
              </h2>

              <div class="shadow-retro-field bg-white p-3">
                <ul class="space-y-2 text-xs">
                  <li class="flex items-start gap-2">
                    <Icons.icon_ban class="w-4 h-4 shrink-0 mt-0.5" />
                    <span>
                      <strong>Discord can ban your server tomorrow.</strong>
                      No warning. No appeal. No backup.
                    </span>
                  </li>
                  <li class="flex items-start gap-2">
                    <Icons.icon_dollar class="w-4 h-4 shrink-0 mt-0.5" />
                    <span>
                      <strong>Slack charges for messages you already sent.</strong>
                      Your history, behind a paywall.
                    </span>
                  </li>
                  <li class="flex items-start gap-2">
                    <Icons.icon_globe_blocked class="w-4 h-4 shrink-0 mt-0.5" />
                    <span>
                      <strong>Telegram can be blocked in your entire country.</strong>
                      One court order and your community is gone.
                    </span>
                  </li>
                  <li class="flex items-start gap-2">
                    <Icons.icon_robot class="w-4 h-4 shrink-0 mt-0.5" />
                    <span>
                      <strong>Your data trains another company&rsquo;s AI.</strong>
                      You never consented.
                    </span>
                  </li>
                </ul>
              </div>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>C:\TRUTH\</.window_status_bar_field>
            </.window_status_bar>
          </.window>

          <.window>
            <.window_title_bar title="The Solution" controls={[:close]}>
              <:icon><Icons.icon_chat class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <h3 class="text-sm font-bold mb-2">
                Take back control.
              </h3>

              <ul class="space-y-2 text-xs mb-3">
                <li class="flex items-start gap-2">
                  <Icons.icon_server class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>
                    <strong>You own the server, the data, the rules.</strong>
                    Install on your own hardware or a $5/month VPS.
                  </span>
                </li>
                <li class="flex items-start gap-2">
                  <Icons.icon_p2p class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>
                    <strong>P2P voice and video calls.</strong>
                    Direct between users via WebRTC &mdash; no middleman.
                  </span>
                </li>
                <li class="flex items-start gap-2">
                  <Icons.icon_shield class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>
                    <strong>No corporation can shut you down.</strong>
                    Open source, MIT licensed, community-owned.
                  </span>
                </li>
                <li class="flex items-start gap-2">
                  <Icons.icon_code class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>
                    <strong>No &ldquo;Pro&rdquo; plan. No algorithms.</strong>
                    Free software. Yours forever.
                  </span>
                </li>
              </ul>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                <Icons.icon_checkmark class="w-3 h-3 inline" /> Ready
              </.window_status_bar_field>
            </.window_status_bar>
          </.window>
        </div>

        <%!-- ══════════════ P2P DIAGRAM ══════════════ --%>
        <.window class="mb-4">
          <.window_title_bar title="Direct connection. No middleman." controls={[:close]}>
            <:icon><Icons.icon_p2p class="w-4 h-4" /></:icon>
          </.window_title_bar>
          <.window_body>
            <div
              class="shadow-retro-field bg-white p-3 mb-2"
              aria-label="Peer-to-peer connection diagram"
            >
              <.diagram_p2p_architecture class="w-full max-w-lg mx-auto" />
            </div>
            <p class="text-sm text-center">
              The server only introduces users. Once connected,
              voice, video, and files flow <strong>directly</strong>
              between them &mdash; encrypted, private, and fast.
            </p>
          </.window_body>
          <.window_status_bar>
            <.window_status_bar_field grow>
              <Icons.icon_checkmark class="w-3 h-3 inline" /> Got it
            </.window_status_bar_field>
          </.window_status_bar>
        </.window>
      </section>

      <%!-- ══════════════ GAMES ══════════════ --%>
      <section class="m-4" aria-labelledby="games-heading">
        <div class="grid md:grid-cols-2 gap-4">
          <%!-- P2P Multiplayer Games --%>
          <.window>
            <.window_title_bar title="Multiplayer Games" controls={[:close]}>
              <:icon><Icons.icon_joystick class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <h2 id="games-heading" class="text-sm font-bold mb-2">
                28 multiplayer games. Right from the chat.
              </h2>
              <div
                class="shadow-retro-field bg-white p-3 mb-2"
                aria-label="P2P multiplayer games flow diagram"
              >
                <.diagram_p2p_games class="w-full max-w-lg mx-auto" />
              </div>
              <p class="text-sm">
                Type <strong>/game @nick</strong> to challenge anyone.
                Games run on HTML5 Canvas with state synced via WebRTC DataChannel &mdash; <strong>no server involvement</strong>, just like voice calls.
              </p>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                <Icons.icon_checkmark class="w-3 h-3 inline" /> 28 games
              </.window_status_bar_field>
            </.window_status_bar>
          </.window>

          <%!-- Solo Arcade Games --%>
          <.window>
            <.window_title_bar title="Solo Arcade" controls={[:close]}>
              <:icon><Icons.icon_game_arcade class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <h3 class="text-sm font-bold mb-2">
                18 classic games. Running in your browser.
              </h3>
              <div
                class="shadow-retro-field bg-white p-3 mb-2"
                aria-label="Solo arcade flow diagram"
              >
                <.diagram_arcade_flow class="w-full max-w-lg mx-auto" />
              </div>
              <p class="text-sm">
                Join <strong>#games</strong> and type <strong>!play</strong> &mdash;
                the arcade bot sends you a link to the game lobby.
                Pick from DOOM, Quake, Wolfenstein 3D, Half-Life, and ScummVM adventures &mdash;
                all running as <strong>WebAssembly</strong> in your browser. No downloads.
              </p>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                <Icons.icon_checkmark class="w-3 h-3 inline" /> 18 games
              </.window_status_bar_field>
            </.window_status_bar>
          </.window>
        </div>
      </section>

      <%!-- ══════════════ EASTER EGG: README.txt popup ══════════════ --%>
      <div
        id="readme-popup"
        class="hidden fixed inset-0 z-modal flex items-center justify-center bg-overlay-bg"
        phx-click={JS.hide(to: "#readme-popup")}
      >
        <div class="max-w-lg w-full mx-4" phx-click-away={JS.hide(to: "#readme-popup")}>
          <.window>
            <.window_title_bar
              title="README.txt — Notepad"
              controls={[:close]}
              on_close={JS.hide(to: "#readme-popup")}
            >
              <:icon><Icons.icon_notepad class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <.readme_text />
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>Ln 1, Col 1</.window_status_bar_field>
            </.window_status_bar>
          </.window>
        </div>
      </div>

      <%!-- ══════════════ EASTER EGG: Trash popup ══════════════ --%>
      <div
        id="trash-popup"
        class="hidden fixed inset-0 z-modal flex items-center justify-center bg-overlay-bg"
        phx-click={JS.hide(to: "#trash-popup")}
      >
        <div class="max-w-sm w-full mx-4" phx-click-away={JS.hide(to: "#trash-popup")}>
          <.window>
            <.window_title_bar
              title="Trash"
              controls={[:close]}
              on_close={JS.hide(to: "#trash-popup")}
            >
              <:icon><Icons.icon_trash class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body class="text-center py-4">
              <p class="text-sm">
                No trash here.<br /> Just clean code. &#x2728;
              </p>
            </.window_body>
          </.window>
        </div>
      </div>
    </.landing_layout>
    """
  end

  @readme_content """
  In the 2000s, the internet was ours.

  We had IRC, forums, blogs, and a freedom
  we didn't know we could lose. We ran servers
  in our basements. We built networks with
  friends. The code was free. The web was
  decentralized.

  Then we traded that for convenience.
  And when we noticed, the internet belonged
  to five companies.

  Retro Hex Chat is a reminder that we can
  have both: the convenience of 2026
  and the freedom of 2000.

  Run your server. Talk directly with your
  friends. Your data stays with you.

  — The creators of Retro Hex Chat\
  """

  defp readme_text(assigns) do
    assigns = assign(assigns, :text, @readme_content)

    ~H"""
    <pre class="text-xs whitespace-pre-wrap">{@text}</pre>
    """
  end
end
