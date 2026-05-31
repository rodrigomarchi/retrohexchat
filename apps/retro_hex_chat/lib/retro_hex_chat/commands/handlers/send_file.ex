defmodule RetroHexChat.Commands.Handlers.SendFile do
  @moduledoc "Handler for /sendfile <nickname> — initiate a P2P file transfer."
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handlers.P2p

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, gettext("Usage: /sendfile <nickname>")}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, gettext("Usage: /sendfile <nickname>")}

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
      syntax: gettext("/sendfile <nickname>"),
      description:
        gettext(
          "Send a file to another user through a direct peer-to-peer connection.\nRequires: both you and the target must be registered and identified (/ns identify).\nYou cannot send files to yourself. Creates a P2P session — the peer must accept."
        ),
      examples: [gettext("/sendfile mario")]
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
      command: "sendfile",
      syntax: gettext("/sendfile <nickname>"),
      description:
        gettext(
          "Send a file to another user through a direct peer-to-peer connection.\nRequires: both users must be registered and identified (/ns identify)."
        ),
      category: :user,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: gettext("File recipient")
        }
      ],
      examples: [gettext("/sendfile mario")]
    }
  end
end
