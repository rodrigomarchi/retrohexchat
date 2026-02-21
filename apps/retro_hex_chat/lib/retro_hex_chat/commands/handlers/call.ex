defmodule RetroHexChat.Commands.Handlers.Call do
  @moduledoc "Handler for /call <nickname> — initiate a P2P audio call."
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handlers.P2p

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, "Usage: /call <nickname>"}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, "Usage: /call <nickname>"}

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
      description:
        "Start a peer-to-peer audio call with another user.\nRequires: both you and the target must be registered and identified (/ns identify).\nYou cannot call yourself. Creates a P2P session — the peer must accept in their lobby.",
      examples: ["/call mario"]
    }
  end

  @impl true
  def category, do: :user

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "call",
      syntax: "/call <nickname>",
      description:
        "Start a peer-to-peer audio call with another user.\nRequires: both users must be registered and identified (/ns identify).",
      category: :user,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: "User to call"
        }
      ],
      examples: ["/call mario"]
    }
  end
end
