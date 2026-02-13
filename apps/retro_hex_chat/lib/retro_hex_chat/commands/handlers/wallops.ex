defmodule RetroHexChat.Commands.Handlers.Wallops do
  @moduledoc "Handler for /wallops <message> — broadcast to +w users."
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @pubsub RetroHexChat.PubSub
  @topic "server:wallops"

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, %{is_admin: false, is_server_operator: false}) do
    {:error, "Permission denied: you must be a server operator."}
  end

  def execute([], _context) do
    {:error, "Usage: /wallops <message>"}
  end

  def execute(args, context) do
    content = Enum.join(args, " ")

    Phoenix.PubSub.broadcast(
      @pubsub,
      @topic,
      {:wallops,
       %{
         sender: context.nickname,
         content: content,
         timestamp: DateTime.utc_now()
       }}
    )

    {:ok, :system, %{content: "Wallops sent."}}
  end

  @impl true
  @spec help() :: %{
          name: String.t(),
          syntax: String.t(),
          description: String.t(),
          examples: [String.t()]
        }
  def help do
    %{
      name: "wallops",
      syntax: "/wallops <message>",
      description: "Send a wallops message to all users with +w mode. Requires server operator.",
      examples: ["/wallops Server maintenance in 10 minutes"]
    }
  end

  @impl true
  def category, do: :user
end
