defmodule RetroHexChat.Commands.Handlers.Whois do
  @moduledoc "Handler for /whois <nickname>"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, "Usage: /whois <nickname>"}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, "Usage: /whois <nickname>"}

  def execute([target | _rest], _context) do
    {:ok, :ui_action, :show_whois_info, %{nickname: target}}
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
      name: "whois",
      syntax: "/whois <nickname>",
      description:
        "Look up detailed information about an online user.\nShows: nickname, channels (shared channels highlighted), idle time, away status, bio, and registration status.\nUser must be online. For offline users, use /whowas.",
      examples: ["/whois SomeUser"]
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
      command: "whois",
      syntax: "/whois <nickname>",
      description: "Look up detailed information about an online user.",
      category: :user,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: "User to look up"
        }
      ],
      examples: ["/whois SomeUser"]
    }
  end
end
