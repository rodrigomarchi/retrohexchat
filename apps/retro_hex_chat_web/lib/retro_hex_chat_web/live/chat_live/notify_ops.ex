defmodule RetroHexChatWeb.ChatLive.NotifyOps do
  @moduledoc """
  Pure Notify-list operations shared by the two surfaces that edit it — the
  standalone Notify List dialog and the Address Book's Notify tab. They are
  separate use cases (never open at once) that read/mutate the same
  `session.notify_list`, so the data + the mutation logic are shared here while
  each surface owns its own selection / draft / sub-dialog UI state.

  Every function takes and returns plain `Session`/list data (no socket): the
  add/remove/edit ops return `{:ok, session, status}` or `{:error, status}` so
  the caller can bubble the new session + status line and run the socket-level
  side effects it owns (timer cancel, PM open, persistence).
  """
  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.Session
  alias RetroHexChat.Presence.{NotifyList, Tracker}
  alias RetroHexChat.Topics

  @type result :: {:ok, Session.t(), String.t()} | {:error, String.t()}

  @spec add(Session.t(), String.t(), String.t() | nil) :: result()
  def add(session, nick, note) do
    note = blank_to_nil(note)

    case NotifyList.add_entry(session.notify_list, session.nickname, nick, note) do
      {:ok, list} ->
        list = sync_entry_online(list, nick)

        {:ok, Session.set_notify_list(session, list),
         dgettext("chat", "Added %{nickname} to notify list", nickname: nick)}

      {:error, :self_add} ->
        {:error, dgettext("chat", "Cannot add yourself to the notify list")}

      {:error, :duplicate} ->
        {:error, dgettext("chat", "%{nickname} is already in your notify list", nickname: nick)}

      {:error, :list_full} ->
        {:error, dgettext("chat", "Notify list is full (max 50 entries)")}
    end
  end

  @spec remove(Session.t(), String.t()) :: result()
  def remove(session, nick) do
    case NotifyList.remove_entry(session.notify_list, nick) do
      {:ok, list} ->
        {:ok, Session.set_notify_list(session, list),
         dgettext("chat", "Removed %{nickname} from notify list", nickname: nick)}

      {:error, :not_found} ->
        {:error, dgettext("chat", "%{nickname} is not in your notify list", nickname: nick)}
    end
  end

  @spec update_note(Session.t(), String.t(), String.t() | nil) :: result()
  def update_note(session, nick, note) do
    note = blank_to_nil(note)

    case NotifyList.update_note(session.notify_list, nick, note) do
      {:ok, list} ->
        {:ok, Session.set_notify_list(session, list),
         dgettext("chat", "Updated note for %{nickname}", nickname: nick)}

      {:error, :not_found} ->
        {:error, dgettext("chat", "%{nickname} is not in your notify list", nickname: nick)}
    end
  end

  @spec toggle_auto_whois(Session.t()) :: Session.t()
  def toggle_auto_whois(session) do
    current = session.notify_list.settings.auto_whois
    Session.set_notify_list(session, NotifyList.set_auto_whois(session.notify_list, !current))
  end

  @spec toggle_auto_add_pm(Session.t()) :: Session.t()
  def toggle_auto_add_pm(session) do
    current = NotifyList.auto_add_pm?(session.notify_list)
    Session.set_notify_list(session, NotifyList.set_auto_add_pm(session.notify_list, !current))
  end

  @doc "The note text for a tracked nick (case-insensitive), or `\"\"`."
  @spec note_for(map(), String.t() | nil) :: String.t()
  def note_for(notify_list, nick) when is_binary(nick) do
    downcased = String.downcase(nick)

    notify_list.entries
    |> Enum.find(&(String.downcase(&1.tracked_nickname) == downcased))
    |> case do
      nil -> ""
      entry -> Map.get(entry, :note) || ""
    end
  end

  def note_for(_notify_list, _nick), do: ""

  @spec sync_entry_online(map(), String.t()) :: map()
  defp sync_entry_online(notify_list, nickname) do
    online_nicks = Tracker.list_users(Topics.presence()) |> Enum.map(& &1.nickname)

    if Enum.any?(online_nicks, &(String.downcase(&1) == String.downcase(nickname))) do
      NotifyList.set_online(notify_list, nickname, true)
    else
      notify_list
    end
  end

  defp blank_to_nil(value) when value in ["", nil], do: nil
  defp blank_to_nil(value), do: value
end
