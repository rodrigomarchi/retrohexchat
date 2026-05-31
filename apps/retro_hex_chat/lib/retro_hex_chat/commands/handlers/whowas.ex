defmodule RetroHexChat.Commands.Handlers.Whowas do
  @moduledoc "Handler for /whowas <nickname>"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, dgettext("commands", "Usage: /whowas <nickname>")}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, dgettext("commands", "Usage: /whowas <nickname>")}

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
      syntax: dgettext("commands", "/whowas <nickname>"),
      description:
        dgettext(
          "commands",
          "Look up information about a user who recently disconnected.\nShows last seen time, channels, and quit message. Data cached for up to 1 hour.\nFor online users, use /whois instead."
        ),
      examples: [dgettext("commands", "/whowas SomeUser")]
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
      syntax: dgettext("commands", "/whowas <nickname>"),
      description:
        dgettext("commands", "Look up information about a user who recently disconnected."),
      category: :user,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: dgettext("commands", "Recently disconnected user")
        }
      ],
      examples: [dgettext("commands", "/whowas SomeUser")]
    }
  end
end
