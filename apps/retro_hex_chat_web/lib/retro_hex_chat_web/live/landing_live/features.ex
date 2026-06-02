defmodule RetroHexChatWeb.LandingLive.Features do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

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
       canonical_path: "/features",
       page_title: dgettext("landing", "Features — Retro Hex Chat"),
       page_description:
         dgettext(
           "landing",
           "Real-time chat, channels, P2P voice/video calls, 28 multiplayer games, "
         ) <>
           dgettext(
             "landing",
             "18 classic arcade games, programmable bots, IRC-style commands, and built-in help."
           )
     )}
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
