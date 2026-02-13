defmodule RetroHexChat.Commands.Handlers.Whowas do
  @moduledoc "Handler for /whowas <nickname>"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, "Usage: /whowas <nickname>"}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, "Usage: /whowas <nickname>"}

  def execute([target | _rest], _context) do
    {:ok, :ui_action, :show_whowas_info, %{nickname: target}}
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
      name: "whowas",
      syntax: "/whowas <nickname>",
      description:
        "Display information about a recently disconnected user. Shows last seen time, channels, and quit message.",
      examples: ["/whowas SomeUser"]
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
      command: "whowas",
      syntax: "/whowas <nickname>",
      description:
        "Display information about a recently disconnected user. Shows last seen time, channels, and quit message.",
      category: :user,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: "Usuário desconectado recentemente"
        }
      ],
      examples: ["/whowas SomeUser"]
    }
  end
end
