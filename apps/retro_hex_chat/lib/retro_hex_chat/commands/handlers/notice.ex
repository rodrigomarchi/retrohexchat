defmodule RetroHexChat.Commands.Handlers.Notice do
  @moduledoc """
  Handler for the /notice command.
  Sends a notice to a user or channel without creating a PM window.
  """

  @behaviour RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, "Usage: /notice <target> <message>"}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], RetroHexChat.Commands.Handler.context()) ::
          RetroHexChat.Commands.Handler.result()
  def execute([], _context),
    do: {:error, "Usage: /notice <target> <message>"}

  def execute([_target], _context),
    do: {:error, "No message specified. Usage: /notice <target> <message>"}

  def execute([target | rest], _context) do
    content = Enum.join(rest, " ")
    {:ok, :notice, %{target: target, content: content}}
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
      name: "notice",
      syntax: "/notice <target> <message>",
      description:
        "Send a notice to a user or channel. Notices use -Nick- formatting and do not open PM windows.",
      examples: [
        "/notice Alice Check out #project",
        "/notice #elixir Server maintenance in 30 minutes"
      ]
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
      command: "notice",
      syntax: "/notice <target> <message>",
      description:
        "Send a notice to a user or channel. Notices use -Nick- formatting and do not open PM windows.",
      category: :user,
      parameters: [
        %Parameter{
          name: "target",
          required: true,
          type: :nick,
          position: 0,
          description: "Destinatário (nick ou canal)"
        },
        %Parameter{
          name: "message",
          required: true,
          type: :text,
          position: 1,
          description: "Conteúdo do aviso"
        }
      ],
      examples: [
        "/notice Alice Check out #project",
        "/notice #elixir Server maintenance in 30 minutes"
      ]
    }
  end
end
