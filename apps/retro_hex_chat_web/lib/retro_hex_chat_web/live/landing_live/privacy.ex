defmodule RetroHexChatWeb.LandingLive.Privacy do
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
       active_page: :privacy,
       page_title: "Privacy Comparison — Retro Hex Chat vs Discord, Slack & Telegram",
       page_description:
         "Side-by-side privacy comparison: data ownership, call routing, message access, AI training, and source code transparency."
     )}
  end

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <.landing_layout active_page={@active_page}>
      <section class="m-4" aria-labelledby="privacy-heading">
        <.window>
          <.window_title_bar title="Privacy" controls={[:close]}>
            <:icon><Icons.icon_lock class="w-4 h-4" /></:icon>
          </.window_title_bar>
          <.window_body>
            <h2 id="privacy-heading" class="text-lg font-bold mb-3">
              Your data stays with you. Period.
            </h2>

            <div class="shadow-retro-field bg-white p-2 mb-3 overflow-x-auto">
              <table class="w-full text-xs border-collapse">
                <thead>
                  <tr>
                    <th class="text-left p-1 border-b border-gray-400"></th>
                    <th class="text-left p-1 border-b border-gray-400">
                      Discord / Slack / Telegram
                    </th>
                    <th class="text-left p-1 border-b border-gray-400">Retro Hex Chat</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td class="p-1 border-b border-gray-200">
                      <strong>Who owns the server?</strong>
                    </td>
                    <td class="p-1 border-b border-gray-200">A corporation</td>
                    <td class="p-1 border-b border-gray-200">You</td>
                  </tr>
                  <tr>
                    <td class="p-1 border-b border-gray-200">
                      <strong>Where are messages stored?</strong>
                    </td>
                    <td class="p-1 border-b border-gray-200">Their cloud, their terms</td>
                    <td class="p-1 border-b border-gray-200">Your server, your database</td>
                  </tr>
                  <tr>
                    <td class="p-1 border-b border-gray-200">
                      <strong>Voice and video calls</strong>
                    </td>
                    <td class="p-1 border-b border-gray-200">Routed through their servers</td>
                    <td class="p-1 border-b border-gray-200">Direct P2P via WebRTC</td>
                  </tr>
                  <tr>
                    <td class="p-1 border-b border-gray-200">
                      <strong>Can they read your messages?</strong>
                    </td>
                    <td class="p-1 border-b border-gray-200">Yes &mdash; and they do</td>
                    <td class="p-1 border-b border-gray-200">No &mdash; only you have access</td>
                  </tr>
                  <tr>
                    <td class="p-1 border-b border-gray-200">
                      <strong>Data used for AI training?</strong>
                    </td>
                    <td class="p-1 border-b border-gray-200">Often, and without consent</td>
                    <td class="p-1 border-b border-gray-200">Never. Your data is yours.</td>
                  </tr>
                  <tr>
                    <td class="p-1 border-b border-gray-200">
                      <strong>Can they ban your community?</strong>
                    </td>
                    <td class="p-1 border-b border-gray-200">Yes, at any time</td>
                    <td class="p-1 border-b border-gray-200">No &mdash; you own the server</td>
                  </tr>
                  <tr>
                    <td class="p-1"><strong>Source code</strong></td>
                    <td class="p-1">Closed. Trust them blindly.</td>
                    <td class="p-1">Open source. Audit it yourself.</td>
                  </tr>
                </tbody>
              </table>
            </div>

            <p class="text-sm">
              No tracking. No profiling. No data harvesting.
              Just a chat server that <strong>respects your privacy</strong>.
            </p>
          </.window_body>
          <.window_status_bar>
            <.window_status_bar_field grow>Your data. Your rules.</.window_status_bar_field>
          </.window_status_bar>
        </.window>
      </section>
    </.landing_layout>
    """
  end
end
