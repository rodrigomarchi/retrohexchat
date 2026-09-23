defmodule RetroHexChat.Notifications.Policy do
  @moduledoc """
  Which messages are worth waking somebody up for.

  Two filters, and between them they are the difference between a feature and
  spam. The first is the kind of line: a join, a mode change, a service reply
  or an error is the room talking about itself, and nobody installed anything
  to be told about it. The second is who wrote it — almost every line on this
  server is written by a bot, and a bot has never had anything to say that was
  worth a phone lighting up.

  Deliberately not here: whether the reader is looking. That is a runtime fact
  with a lifetime of seconds, so it is read as late as possible, in the worker,
  rather than at the moment the message was written.
  """

  alias RetroHexChat.Bots.Registry, as: BotRegistry

  # What a person says, and what a person does. Everything else on this list —
  # system, service, error, notice, the P2P pair — is the product narrating
  # itself.
  @notifiable_types ~w(message action)

  @doc "Whether a message of this type could ever be worth a notification."
  @spec notifiable_type?(atom() | String.t() | nil) :: boolean()
  def notifiable_type?(type) when is_atom(type) and not is_nil(type),
    do: notifiable_type?(Atom.to_string(type))

  def notifiable_type?(type) when is_binary(type), do: type in @notifiable_types
  def notifiable_type?(_type), do: false

  @doc "Whether this author's messages can produce a notification at all."
  @spec notifiable_author?(String.t() | nil) :: boolean()
  def notifiable_author?(nickname) when is_binary(nickname) and nickname != "" do
    not BotRegistry.bot?(nickname)
  end

  def notifiable_author?(_nickname), do: false
end
