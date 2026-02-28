defmodule RetroHexChatWeb.LandingLive.Index do
  @moduledoc false
  use Phoenix.LiveView

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Window

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
      <%!-- ══════════════ HERO ══════════════ --%>
      <section class="m-4" aria-labelledby="hero-heading">
        <.window class="mb-4">
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

        <.window>
          <.window_title_bar title="C:\Desktop" controls={[:close]}>
            <:icon><Icons.icon_folder class="w-4 h-4" /></:icon>
          </.window_title_bar>
          <.window_body>
            <div class="flex gap-6 justify-center py-2">
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
