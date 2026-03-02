defmodule RetroHexChatWeb.LandingLive.Faq do
  @moduledoc false
  use Phoenix.LiveView

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Window
  import RetroHexChatWeb.Components.UI.Accordion

  alias RetroHexChatWeb.Icons

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active_page: :faq,
       page_title: "FAQ — Retro Hex Chat",
       page_description:
         "Frequently asked questions about Retro Hex Chat: P2P calls, server requirements, security, contributing, and more."
     )}
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <.landing_layout active_page={@active_page}>
      <section class="m-4" aria-labelledby="faq-heading">
        <h2 id="faq-heading" class="sr-only">Frequently Asked Questions</h2>

        <div class="grid md:grid-cols-2 gap-4">
          <%!-- ══════════════ GETTING STARTED ══════════════ --%>
          <.window>
            <.window_title_bar title="Getting Started" controls={[:close]}>
              <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <.accordion>
                <.accordion_item>
                  <.accordion_trigger group="faq-start">
                    <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
                    What is P2P?
                  </.accordion_trigger>
                  <.accordion_content>
                    <p class="text-sm">
                      P2P (peer-to-peer) means data goes directly between users without
                      passing through a server. Retro Hex Chat uses WebRTC for voice calls,
                      video calls, and file transfers. The server only helps users find
                      each other (signaling), then steps out of the way.
                    </p>
                  </.accordion_content>
                </.accordion_item>

                <.accordion_item>
                  <.accordion_trigger group="faq-start">
                    <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
                    Do I need to run my own server?
                  </.accordion_trigger>
                  <.accordion_content>
                    <p class="text-sm">
                      Not necessarily! You can create an account on any public server.
                      Running your own server is for those who want total control.
                    </p>
                  </.accordion_content>
                </.accordion_item>

                <.accordion_item>
                  <.accordion_trigger group="faq-start">
                    <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
                    Is it free?
                  </.accordion_trigger>
                  <.accordion_content>
                    <p class="text-sm">
                      Yes, the software is 100% free and open source (MIT).
                      If you run your own server, you only pay for hosting
                      (a $5/month VPS is enough).
                    </p>
                  </.accordion_content>
                </.accordion_item>

                <.accordion_item>
                  <.accordion_trigger group="faq-start">
                    <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
                    How is it different from Discord?
                  </.accordion_trigger>
                  <.accordion_content>
                    <p class="text-sm">
                      On Discord, your data lives on their servers and your communities
                      can be removed at any time. On Retro Hex Chat, you control your
                      data, voice and video calls go directly between users via P2P,
                      and the code is open source &mdash; you can audit every line.
                    </p>
                  </.accordion_content>
                </.accordion_item>

                <.accordion_item>
                  <.accordion_trigger group="faq-start">
                    <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
                    What if my server goes down?
                  </.accordion_trigger>
                  <.accordion_content>
                    <p class="text-sm">
                      Your data lives in your PostgreSQL database. Regular backups mean
                      you can restore on any new machine. Active P2P calls continue
                      working even if the server has a brief interruption, since they
                      connect directly between users.
                    </p>
                  </.accordion_content>
                </.accordion_item>

                <.accordion_item>
                  <.accordion_trigger group="faq-start">
                    <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
                    Is it secure?
                  </.accordion_trigger>
                  <.accordion_content>
                    <p class="text-sm">
                      Yes. Server connections use HTTPS/WSS with TLS encryption.
                      P2P calls are encrypted end-to-end via DTLS-SRTP (built into WebRTC).
                      Passwords are hashed with bcrypt. And the code is open source
                      &mdash; anyone can audit it for vulnerabilities.
                    </p>
                  </.accordion_content>
                </.accordion_item>
              </.accordion>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>6 questions</.window_status_bar_field>
            </.window_status_bar>
          </.window>

          <%!-- ══════════════ TECHNICAL & COMMUNITY ══════════════ --%>
          <.window>
            <.window_title_bar title="Technical & Community" controls={[:close]}>
              <:icon><Icons.icon_code class="w-4 h-4" /></:icon>
            </.window_title_bar>
            <.window_body>
              <.accordion>
                <.accordion_item>
                  <.accordion_trigger group="faq-tech">
                    <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
                    What technologies are used?
                  </.accordion_trigger>
                  <.accordion_content>
                    <p class="text-sm">
                      Elixir and Phoenix on the backend, PostgreSQL for data, a retro design system
                      for the classic look, WebSocket for real-time messaging, and WebRTC for P2P.
                      Everything is open source.
                    </p>
                  </.accordion_content>
                </.accordion_item>

                <.accordion_item>
                  <.accordion_trigger group="faq-tech">
                    <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
                    How can I contribute?
                  </.accordion_trigger>
                  <.accordion_content>
                    <p class="text-sm">
                      Check out our contributing guide on GitHub! We accept code, documentation,
                      translation, design, testing, and bug reports. Issues marked
                      &ldquo;good first issue&rdquo; are a great place to start.
                    </p>
                  </.accordion_content>
                </.accordion_item>

                <.accordion_item>
                  <.accordion_trigger group="faq-tech">
                    <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
                    How can I support financially?
                  </.accordion_trigger>
                  <.accordion_content>
                    <p class="text-sm">
                      Through GitHub Sponsors. Every contribution, no matter how small,
                      helps keep the project alive and in active development.
                    </p>
                  </.accordion_content>
                </.accordion_item>

                <.accordion_item>
                  <.accordion_trigger group="faq-tech">
                    <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
                    Does it work on mobile?
                  </.accordion_trigger>
                  <.accordion_content>
                    <p class="text-sm">
                      Yes! The interface is responsive and works on any modern browser.
                      Native apps are planned for the future.
                    </p>
                  </.accordion_content>
                </.accordion_item>

                <.accordion_item>
                  <.accordion_trigger group="faq-tech">
                    <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
                    Can I use it for my company or team?
                  </.accordion_trigger>
                  <.accordion_content>
                    <p class="text-sm">
                      Absolutely. Run a private server, create invite-only channels,
                      and keep all your team&rsquo;s communication on your own infrastructure.
                      No per-seat pricing, no message limits.
                    </p>
                  </.accordion_content>
                </.accordion_item>

                <.accordion_item>
                  <.accordion_trigger group="faq-tech">
                    <:icon><Icons.icon_question class="w-4 h-4" /></:icon>
                    How do sessions work?
                  </.accordion_trigger>
                  <.accordion_content>
                    <p class="text-sm">
                      Each nickname can only have <strong>one active session</strong> at a time.
                      If you connect from another browser or tab, the previous session is
                      automatically disconnected. If your connection drops, the client attempts
                      to reconnect up to 10 times with exponential backoff. After all attempts
                      fail, the session expires and you&rsquo;re redirected to the login screen.
                      Registered nicknames are protected by password &mdash; only the owner
                      can connect with that nick.
                    </p>
                  </.accordion_content>
                </.accordion_item>
              </.accordion>
            </.window_body>
            <.window_status_bar>
              <.window_status_bar_field grow>6 questions</.window_status_bar_field>
            </.window_status_bar>
          </.window>
        </div>
      </section>
    </.landing_layout>
    """
  end
end
