defmodule RetroHexChatWeb.ChatLive.ChatTitle do
  @moduledoc """
  The single source of truth for the chat's identity strings.

  One derivation feeds every surface that names the current conversation: the
  desktop window title bar, its taskbar button and the browser tab. They are the
  same string by construction, so none of them can drift from the others.

  ## Format

      #lobby[Troll]   channel tab — `#channel[nick]`
      Joe:Troll       PM tab — `remote:mine`
      Status[Troll]   status tab

  The conversation label and the nickname are identifiers, so the composition is
  literal punctuation and never goes through Gettext. Only the status tab's label
  is translated, and it reuses the msgid the tab bar already ships.

  ## Who applies it

  The window title and the taskbar button read these functions at render time,
  so change tracking keeps them current with no state of their own.

  The browser tab cannot: `page_title` only produces a diff when it is a socket
  assign changed before the render, and the chat session is written from ~30
  modules with no callback that runs after them (`attach_hook/4` on
  `:handle_event`/`:handle_info` runs *before* the handler, and assigns changed
  in an `:after_render` hook are dropped by `Utils.clear_changed/1`). The tab
  title also has to carry the activity flash, which alternates on top of it.

  So one client-side owner composes both: the server renders `document_title/2`
  into the `DocumentTitleHook` element and the hook applies it on every patch.
  That ownership is exclusive by construction — the chat renders its first-paint
  title as `initial_title` rather than `page_title`, and the chat root layout
  declares no title default, which is what keeps LiveView's own mount-time write
  from clobbering the hook.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.Session

  @app_name "RetroHexChat"

  @doc """
  The active conversation's label: a channel name, a PM peer, or the status tab.

  `show_status_tab?` wins over the session's active channel/PM: the session keeps
  pointing at the last conversation while the status tab is on screen.
  """
  @spec conversation(Session.t(), boolean()) :: String.t()
  def conversation(session, show_status_tab?)

  def conversation(%Session{}, true), do: status_label()

  def conversation(%Session{active_pm: pm}, false) when is_binary(pm) and pm != "", do: pm

  def conversation(%Session{active_channel: channel}, false)
      when is_binary(channel) and channel != "",
      do: channel

  def conversation(%Session{}, false), do: status_label()

  @doc """
  The window/taskbar/tab title: `#lobby[Troll]` for a channel, `Joe:Troll` for a
  PM (remote peer first, then the viewer).

  Falls back to the application name when the session carries no nickname, which
  only happens before the connect flow has named the user.
  """
  @spec window_title(Session.t(), boolean()) :: String.t()
  def window_title(%Session{nickname: nick}, _show_status_tab?)
      when not is_binary(nick) or nick == "",
      do: @app_name

  def window_title(%Session{active_pm: pm, nickname: nick}, false)
      when is_binary(pm) and pm != "",
      do: "#{pm}:#{nick}"

  def window_title(%Session{nickname: nick} = session, show_status_tab?),
    do: "#{conversation(session, show_status_tab?)}[#{nick}]"

  @doc """
  The browser tab title. Identical to the window title — the tab and the window
  name the same thing, and the activity flash is what signals unread.
  """
  @spec document_title(Session.t(), boolean()) :: String.t()
  def document_title(%Session{} = session, show_status_tab?),
    do: window_title(session, show_status_tab?)

  @doc """
  The live status shown after the window title: the identity state, plus the
  member count when the active conversation is a channel that has one.

  This is where the chat says who you are — the header's status bar dropped its
  account widget once the title carried the same facts.
  """
  @spec window_meta(Session.t(), non_neg_integer()) :: String.t()
  def window_meta(%Session{} = session, user_count) when is_integer(user_count) do
    state = state_label(Session.identity_state(session))

    if session.active_pm == nil and user_count > 0 do
      "#{state} · #{user_count}"
    else
      state
    end
  end

  @spec status_label() :: String.t()
  defp status_label, do: dgettext("chat", "Status")

  # Same msgids the status bar's account widget used before the title took the
  # job, so every locale keeps its translation.
  @spec state_label(atom()) :: String.t()
  defp state_label(:away), do: dgettext("ui", "Away")
  defp state_label(:identified), do: dgettext("ui", "Identified")
  defp state_label(_state), do: dgettext("ui", "Guest")
end
