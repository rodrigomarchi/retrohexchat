defmodule RetroHexChatWeb.Components.UI.Landing.LandingMockups do
  @moduledoc """
  Shared landing-page mockups and terminal snippets.

  These are visual/content components used by the public pages. Keeping them in
  UI avoids private HEEx helpers inside individual Landing LiveViews.
  """
  use RetroHexChatWeb.Component

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

  @spec readme_text(map()) :: Phoenix.LiveView.Rendered.t()
  def readme_text(assigns) do
    assigns = assign(assigns, :text, @readme_content)

    ~H"""
    <pre class="text-xs whitespace-pre-wrap">{@text}</pre>
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

  @spec chat_mockup(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_mockup(assigns) do
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

  @spec commands_mockup(map()) :: Phoenix.LiveView.Rendered.t()
  def commands_mockup(assigns) do
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

  @spec channel_list_mockup(map()) :: Phoenix.LiveView.Rendered.t()
  def channel_list_mockup(assigns) do
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

  @spec bot_mockup(map()) :: Phoenix.LiveView.Rendered.t()
  def bot_mockup(assigns) do
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
    ▸ /p2p    ▸ /whois
  ▸ Features
  ▸ Keyboard Shortcuts\
  """

  @spec help_mockup(map()) :: Phoenix.LiveView.Rendered.t()
  def help_mockup(assigns) do
    assigns = assign(assigns, :text, @help_mockup_text)

    ~H"""
    <pre class="text-xs font-mono whitespace-pre">{@text}</pre>
    """
  end

  @clone_text dgettext_noop(
                "landing",
                "$ git clone https://github.com/rodrigomarchi/retro_hex_chat.git\n$ cd retro_hex_chat"
              )
  @setup_text dgettext_noop("landing", "$ make setup")
  @run_text dgettext_noop(
              "landing",
              "$ make server\n[info] Running RetroHexChatWeb.Endpoint at http://localhost:4000"
            )

  @spec step_clone(map()) :: Phoenix.LiveView.Rendered.t()
  def step_clone(assigns) do
    assigns =
      assign(assigns, :text, Gettext.dgettext(RetroHexChatWeb.Gettext, "landing", @clone_text))

    ~H"""
    <pre class="bg-canvas-bg text-canvas-fg p-3 text-xs font-mono overflow-x-auto">{@text}</pre>
    """
  end

  @spec step_setup(map()) :: Phoenix.LiveView.Rendered.t()
  def step_setup(assigns) do
    assigns =
      assign(assigns, :text, Gettext.dgettext(RetroHexChatWeb.Gettext, "landing", @setup_text))

    ~H"""
    <pre class="bg-canvas-bg text-canvas-fg p-3 text-xs font-mono overflow-x-auto">{@text}</pre>
    """
  end

  @spec step_run(map()) :: Phoenix.LiveView.Rendered.t()
  def step_run(assigns) do
    assigns =
      assign(assigns, :text, Gettext.dgettext(RetroHexChatWeb.Gettext, "landing", @run_text))

    ~H"""
    <pre class="bg-canvas-bg text-canvas-fg p-3 text-xs font-mono overflow-x-auto">{@text}</pre>
    """
  end
end
