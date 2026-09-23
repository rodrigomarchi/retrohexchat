defmodule RetroHexChat.SessionControl do
  @moduledoc """
  Ending someone's session, and saying which of their sessions is meant.

  A person can have more than one thing open: the chat in one tab, a call or a
  space in another. Two different events used to arrive as the same message on
  the same topic — "another tab took over this chat" and "you were banned" —
  and nothing on the receiving side could tell them apart. A surface that
  listened died on every login; one that did not listen survived a ban.

  So the scope is the topic, not a flag the receiver has to read:

    * `:chat` publishes only on `Topics.inbox/1`. The chat ends; a call in
      another tab keeps going.
    * `:all` publishes on `Topics.inbox/1` and `Topics.surfaces/1`. Everything
      the person has open ends.

  Every caller means `:all` — a ban, a kick, a dropped nick, a nuke, a ghost —
  which is why it is the default: the narrow scope is the one that has to be
  asked for, and nothing asks for it today. Opening the chat used to, and that
  is the one thing `:chat` was for.

  It no longer ends anything, because a nickname may now hold several chat
  sessions at once. What is enforced instead is a ceiling, and `enforce_limit/2`
  is the only thing here that addresses one session rather than a person: it
  reaches a single screen over its own topic, leaving every other screen of the
  same nickname untouched.
  """

  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Topics

  @pubsub RetroHexChat.PubSub

  # Each session is a process with subscriptions, timers and state, so there has
  # to be a ceiling; three is a desktop, a phone and one more without the number
  # being the thing anybody notices.
  @default_max_sessions 3

  @type scope :: :chat | :all

  @doc """
  Ends `nickname`'s sessions within `scope`, carrying `payload` to each.

  The scope is stamped onto the payload after the caller's keys, so a `:scope`
  the caller happened to include cannot widen where the message goes.
  """
  @spec disconnect(String.t(), map(), scope()) :: :ok
  def disconnect(nickname, payload, scope \\ :all)

  def disconnect(nickname, payload, scope)
      when is_binary(nickname) and is_map(payload) and scope in [:chat, :all] do
    message = {:force_disconnect, Map.put(payload, :scope, scope)}

    nickname
    |> topics(scope)
    |> Enum.each(&broadcast(&1, message, nickname))
  end

  @doc "How many chat sessions one nickname may hold at once."
  @spec max_sessions() :: pos_integer()
  def max_sessions do
    Application.get_env(:retro_hex_chat, :max_chat_sessions, @default_max_sessions)
  end

  @doc """
  Makes room for the session identified by `session_ref`, ending the oldest
  screens only if the ceiling is already full.

  Opening the chat is not a takeover any more: the screens somebody already has
  keep working, and only the count is enforced. A screen that gives way here is
  told to leave the channels alone — the screens that outlive it hold the same
  membership, and parting would take them out of a conversation they are still
  in.
  """
  @spec enforce_limit(String.t(), String.t() | nil) :: :ok
  def enforce_limit(nickname, session_ref) when is_binary(nickname) do
    keep = max(max_sessions() - 1, 0)

    nickname
    |> TrustedDevices.open_sessions_for_nick(except: session_ref)
    |> Enum.drop(-keep)
    |> Enum.each(fn session ->
      TrustedDevices.end_session(session.session_ref, %{
        reason: dgettext("accounts", "Session ended — this was your oldest window"),
        skip_channel_cleanup: true,
        skip_whowas: true,
        keep_reconnect_state: true,
        stop_reason: "session_limit"
      })
    end)
  end

  defp topics(nickname, :chat), do: [Topics.inbox(nickname)]
  defp topics(nickname, :all), do: [Topics.inbox(nickname), Topics.surfaces(nickname)]

  defp broadcast(topic, message, nickname) do
    Phoenix.PubSub.broadcast(@pubsub, topic, message)
    :ok
  rescue
    error ->
      Logger.warning(
        "Forced disconnect broadcast to #{topic} failed for #{nickname}: #{inspect(error)}"
      )

      :ok
  end
end
