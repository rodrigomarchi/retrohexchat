defmodule RetroHexChat.Commands.Handlers.Announce do
  @moduledoc "Handler for /announce <message> — admin global broadcast."
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @pubsub RetroHexChat.PubSub
  @topic "server:announcements"

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, %{is_admin: false}) do
    {:error, "Permission denied: you must be a server administrator."}
  end

  def execute([], _context) do
    {:error, "Usage: /announce <message>"}
  end

  def execute(args, %{is_admin: true, nickname: sender}) do
    content = Enum.join(args, " ")

    Phoenix.PubSub.broadcast(
      @pubsub,
      @topic,
      {:announcement,
       %{
         sender: sender,
         content: content,
         timestamp: DateTime.utc_now()
       }}
    )

    {:ok, :system, %{content: "Announcement sent to all users."}}
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
      name: "announce",
      syntax: "/announce <message>",
      description:
        "Send a global announcement to all connected users. Requires server administrator.",
      examples: ["/announce Server will restart at midnight"]
    }
  end

  @impl true
  def category, do: :advanced
end
