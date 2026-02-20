defmodule RetroHexChat.Commands.Handlers.SetMotd do
  @moduledoc "Handler for /setmotd <text> — admin sets the MOTD."
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.Motd

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, %{is_admin: false}) do
    {:error, "Permission denied: you must be a server administrator."}
  end

  def execute([], _context) do
    {:error, "Usage: /setmotd <text>"}
  end

  def execute(args, %{is_admin: true, nickname: nickname}) do
    content = Enum.join(args, " ")

    case Motd.set(content, nickname) do
      :ok -> {:ok, :system, %{content: "MOTD has been updated."}}
      {:error, msg} -> {:error, msg}
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
      name: "setmotd",
      syntax: "/setmotd <text>",
      description:
        "Set the server's Message of the Day shown to all users when they connect.\nRequires: server administrator. Message text is required.",
      examples: ["/setmotd Welcome to RetroHexChat!"]
    }
  end

  @impl true
  def category, do: :advanced

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "setmotd",
      syntax: "/setmotd <text>",
      description: "Set the server's Message of the Day shown to all users when they connect.",
      category: :advanced,
      parameters: [
        %Parameter{
          name: "text",
          required: true,
          type: :text,
          position: 0,
          description: "Message of the Day text"
        }
      ],
      examples: ["/setmotd Welcome to RetroHexChat!"]
    }
  end
end
