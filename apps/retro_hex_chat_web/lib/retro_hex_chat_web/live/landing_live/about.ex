defmodule RetroHexChatWeb.LandingLive.About do
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
       active_page: :about,
       page_title: "About Retro Hex Chat — Why self-hosted chat matters",
       page_description:
         "Understand the problem with centralized chat platforms and how Retro Hex Chat gives you back control of your community."
     )}
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <.landing_layout active_page={@active_page}>
      <%!-- ══════════════ THE PROBLEM ══════════════ --%>
      <section class="m-4" aria-labelledby="problem-heading">
        <.window class="mb-4">
          <.window_title_bar title="C:\TRUTH\about_modern_chat.txt" controls={[:close]}>
            <:icon><Icons.icon_notepad class="w-4 h-4" /></:icon>
          </.window_title_bar>
          <.window_body>
            <h2 id="problem-heading" class="text-lg font-bold mb-2">
              <Icons.icon_warning class="w-4 h-4 inline" /> Your community isn&rsquo;t yours.
            </h2>

            <p class="text-sm mb-1">
              You built a community on Discord. Or on Slack.
              Months of investment. Thousands of messages. Real connections.
            </p>
            <p class="text-sm mb-2">Now think about this:</p>

            <div class="shadow-retro-field bg-white p-3 mb-3">
              <ul class="space-y-2 text-sm">
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
                  <Icons.icon_document_alert class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>
                    <strong>Twitter/X changed the DM rules. Again.</strong>
                    Your contact network, hostage to a corporation.
                  </span>
                </li>
                <li class="flex items-start gap-2">
                  <Icons.icon_robot class="w-4 h-4 shrink-0 mt-0.5" />
                  <span>
                    <strong>Your data trains another company&rsquo;s AI.</strong>
                    Your conversations, photos, and files become product.
                    You never consented.
                  </span>
                </li>
              </ul>
            </div>

            <div class="text-sm">
              <p class="mb-1"><strong>In the 2000s, it wasn&rsquo;t like this.</strong></p>
              <p class="mb-1">
                You ran an IRC server in your basement.
                Connected to EFnet, Undernet, DALnet.
                Your community existed on a network nobody controlled.
                Nobody could take it from you.
              </p>
              <p class="italic">
                Then came the &ldquo;convenience&rdquo;. And with it came the control.
              </p>
            </div>
          </.window_body>
          <.window_status_bar>
            <.window_status_bar_field grow>C:\TRUTH\</.window_status_bar_field>
          </.window_status_bar>
        </.window>
      </section>

      <%!-- ══════════════ THE SOLUTION ══════════════ --%>
      <section class="m-4" aria-labelledby="solution-heading">
        <h2 id="solution-heading" class="sr-only">The Solution</h2>

        <div class="grid md:grid-cols-2 gap-4 mb-4">
          <.window>
            <.window_title_bar title="What is Retro Hex Chat" controls={[:close]}>
              <:icon><Icons.icon_chat class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <p class="text-sm mb-2">
                Retro Hex Chat is <strong>chat software</strong> that anyone
                can install and run on their own server.
              </p>
              <p class="text-sm mb-2">
                Your data lives in <strong>your database</strong>.
                Voice and video calls go <strong>directly between users</strong>
                via WebRTC &mdash; not through the server.
              </p>
              <ul class="space-y-1 text-sm mb-2">
                <li class="flex items-center gap-2">
                  <Icons.icon_server class="w-4 h-4 shrink-0" />
                  <span>You own the server, the data, the rules</span>
                </li>
                <li class="flex items-center gap-2">
                  <Icons.icon_p2p class="w-4 h-4 shrink-0" />
                  <span>P2P calls never touch a middleman</span>
                </li>
                <li class="flex items-center gap-2">
                  <Icons.icon_shield class="w-4 h-4 shrink-0" />
                  <span>No corporation can shut you down</span>
                </li>
              </ul>
              <p class="text-sm">That&rsquo;s it. Simple as that.</p>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                <Icons.icon_checkmark class="w-3 h-3 inline" /> Ready
              </.window_status_bar_field>
            </.window_status_bar>
          </.window>

          <.window>
            <.window_title_bar title="What it's NOT" controls={[:close]}>
              <:icon><Icons.icon_warning class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <p class="text-sm mb-1"><strong>Retro Hex Chat is NOT a service.</strong></p>
              <p class="text-sm mb-1">There&rsquo;s no company behind it controlling anything.</p>
              <p class="text-sm mb-1">
                There&rsquo;s no &ldquo;Pro&rdquo; or &ldquo;Enterprise&rdquo; plan.
              </p>
              <p class="text-sm mb-1">There&rsquo;s no algorithm deciding what you see.</p>
              <p class="text-sm mb-1">It can&rsquo;t be bought, acquired, or shut down.</p>
              <p class="text-sm mt-2">
                <strong>
                  It&rsquo;s free software. It&rsquo;s yours. It&rsquo;s community-owned.
                </strong>
              </p>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>
                <Icons.icon_checkmark class="w-3 h-3 inline" /> Ready
              </.window_status_bar_field>
            </.window_status_bar>
          </.window>
        </div>

        <.window>
          <.window_title_bar title="Direct connection. No middleman." controls={[:close]}>
            <:icon><Icons.icon_p2p class="w-4 h-4" /></:icon>
          </.window_title_bar>
          <.window_body>
            <p class="text-sm mb-2">
              <strong>Voice, video, and files go directly between users.</strong>
            </p>

            <div
              class="shadow-retro-field bg-white p-3 mb-2"
              aria-label="Peer-to-peer connection diagram"
            >
              <.diagram_p2p_architecture class="w-full max-w-lg mx-auto" />
            </div>

            <p class="text-sm">
              The server only introduces users to each other. Once connected,
              all voice, video, and file data flows <strong>directly</strong>
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
    </.landing_layout>
    """
  end
end
