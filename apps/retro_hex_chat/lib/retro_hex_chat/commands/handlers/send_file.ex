defmodule RetroHexChat.Commands.Handlers.SendFile do
  @moduledoc "Handler for /sendfile <nickname> — initiate a P2P file transfer."
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handlers.P2p

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, "Uso: /sendfile <nickname>"}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, "Uso: /sendfile <nickname>"}

  def execute([target | _rest], context) do
    P2p.do_execute(target, "file_transfer", context)
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
      name: "sendfile",
      syntax: "/sendfile <nickname>",
      description: "Iniciar uma transferencia de arquivo P2P com outro usuario.",
      examples: ["/sendfile mario"]
    }
  end

  @impl true
  def category, do: :user
end
