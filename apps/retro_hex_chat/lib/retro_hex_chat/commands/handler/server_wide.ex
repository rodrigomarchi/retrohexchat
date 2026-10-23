defmodule RetroHexChat.Commands.Handler.ServerWide do
  @moduledoc """
  A message from staff to everybody on the server — `/announce`, `/wallops` —
  published on its own topic as `{tag, %{sender, content, timestamp}}`.
  """

  @pubsub RetroHexChat.PubSub

  @doc "Publishes `words`, joined, on `topic` as `{tag, notice}` from `sender`."
  @spec broadcast(String.t(), atom(), String.t(), [String.t()]) :: :ok | {:error, term()}
  def broadcast(topic, tag, sender, words) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      topic,
      {tag, %{sender: sender, content: Enum.join(words, " "), timestamp: DateTime.utc_now()}}
    )
  end
end
