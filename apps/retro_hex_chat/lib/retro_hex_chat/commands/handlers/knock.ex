defmodule RetroHexChat.Commands.Handlers.Knock do
  @moduledoc "Handler for /knock #channel [message]"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, "Usage: /knock #channel [message]"}
  end

  def execute([channel_name | rest], _context) do
    if String.starts_with?(channel_name, "#") do
      message = if rest == [], do: nil, else: Enum.join(rest, " ")
      {:ok, :ui_action, :knock_channel, %{channel: channel_name, message: message}}
    else
      {:error, "Usage: /knock #channel [message]"}
    end
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
      name: "knock",
      syntax: "/knock #channel [message]",
      description:
        "Request access to an invite-only channel. Channel operators will see your knock.",
      examples: [
        "/knock #private",
        "/knock #private Hey, can I join?"
      ]
    }
  end
end
