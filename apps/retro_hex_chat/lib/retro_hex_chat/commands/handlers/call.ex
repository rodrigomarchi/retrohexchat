defmodule RetroHexChat.Commands.Handlers.Call do
  @moduledoc "Handler for /call <nickname> — initiate a P2P audio call."
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handlers.P2p

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, "Uso: /call <nickname>"}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, "Uso: /call <nickname>"}

  def execute([target | _rest], context) do
    P2p.do_execute(target, "audio_call", context)
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
      name: "call",
      syntax: "/call <nickname>",
      description: "Iniciar uma chamada de audio P2P com outro usuario.",
      examples: ["/call mario"]
    }
  end

  @impl true
  def category, do: :user
end
