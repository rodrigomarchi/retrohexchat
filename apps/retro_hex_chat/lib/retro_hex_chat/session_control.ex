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

  Every caller in the domain means `:all` — a ban, a kick, a dropped nick, a
  nuke, a ghost. `:chat` has exactly one caller, the chat's own takeover, which
  is why `:all` is the default: the narrow scope is the one that has to be
  asked for.

  Sessions addressed by device rather than by person (`chat_device_session:*`)
  are not this module's business; they identify one device session, not a
  nickname.
  """

  require Logger

  alias RetroHexChat.Topics

  @pubsub RetroHexChat.PubSub

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
