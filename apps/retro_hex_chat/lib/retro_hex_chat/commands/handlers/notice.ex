defmodule RetroHexChat.Commands.Handlers.Notice do
  @moduledoc """
  Handler for the /notice command.
  Sends a notice to a user or channel without creating a PM window.
  """
  use Gettext, backend: RetroHexChat.Gettext

  @behaviour RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, gettext("Usage: /notice <target> <message>")}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], RetroHexChat.Commands.Handler.context()) ::
          RetroHexChat.Commands.Handler.result()
  def execute([], _context),
    do: {:error, gettext("Usage: /notice <target> <message>")}

  def execute([_target], _context),
    do: {:error, gettext("No message specified. Usage: /notice <target> <message>")}

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
      syntax: gettext("/notice <target> <message>"),
      description:
        gettext(
          "Send a notice to a user or channel without opening a PM window on their side.\nBoth target and message are required. Target can be a nickname or a #channel."
        ),
      examples: [
        gettext("/notice Alice Check out #project"),
        gettext("/notice #elixir Server maintenance in 30 minutes")
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
      syntax: gettext("/notice <target> <message>"),
      description:
        gettext(
          "Send a lightweight notice to a user or channel that doesn't open a PM window on their side."
        ),
      category: :user,
      parameters: [
        %Parameter{
          name: "target",
          required: true,
          type: :nick,
          position: 0,
          description: gettext("Recipient (nickname or channel)")
        },
        %Parameter{
          name: "message",
          required: true,
          type: :text,
          position: 1,
          description: gettext("Notice content")
        }
      ],
      examples: [
        gettext("/notice Alice Check out #project"),
        gettext("/notice #elixir Server maintenance in 30 minutes")
      ]
    }
  end
end
