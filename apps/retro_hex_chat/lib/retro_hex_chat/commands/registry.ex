defmodule RetroHexChat.Commands.Registry do
  @moduledoc """
  Maps command names to handler modules.
  Handlers are registered at compile time.
  """

  @commands %{
    "autojoin" => RetroHexChat.Commands.Handlers.AutoJoin,
    "away" => RetroHexChat.Commands.Handlers.Away,
    "ban" => RetroHexChat.Commands.Handlers.Ban,
    "clear" => RetroHexChat.Commands.Handlers.Clear,
    "ctcp" => RetroHexChat.Commands.Handlers.Ctcp,
    "cs" => RetroHexChat.Commands.Handlers.Cs,
    "help" => RetroHexChat.Commands.Handlers.Help,
    "ignore" => RetroHexChat.Commands.Handlers.Ignore,
    "invite" => RetroHexChat.Commands.Handlers.Invite,
    "join" => RetroHexChat.Commands.Handlers.Join,
    "kick" => RetroHexChat.Commands.Handlers.Kick,
    "leave" => RetroHexChat.Commands.Handlers.Part,
    "list" => RetroHexChat.Commands.Handlers.List,
    "me" => RetroHexChat.Commands.Handlers.Me,
    "mode" => RetroHexChat.Commands.Handlers.Mode,
    "msg" => RetroHexChat.Commands.Handlers.Msg,
    "nick" => RetroHexChat.Commands.Handlers.Nick,
    "notice" => RetroHexChat.Commands.Handlers.Notice,
    "notice_routing" => RetroHexChat.Commands.Handlers.NoticeRouting,
    "notify" => RetroHexChat.Commands.Handlers.Notify,
    "ns" => RetroHexChat.Commands.Handlers.Ns,
    "part" => RetroHexChat.Commands.Handlers.Part,
    "perform" => RetroHexChat.Commands.Handlers.Perform,
    "query" => RetroHexChat.Commands.Handlers.Query,
    "quit" => RetroHexChat.Commands.Handlers.Quit,
    "topic" => RetroHexChat.Commands.Handlers.Topic,
    "unignore" => RetroHexChat.Commands.Handlers.Unignore,
    "whois" => RetroHexChat.Commands.Handlers.Whois
  }

  @spec lookup(String.t()) :: {:ok, module()} | {:error, :unknown_command}
  def lookup(name) do
    case Map.fetch(@commands, name) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, :unknown_command}
    end
  end

  @spec list_commands() :: [String.t()]
  def list_commands do
    Map.keys(@commands)
  end

  @spec known?(String.t()) :: boolean()
  def known?(name), do: Map.has_key?(@commands, name)
end
