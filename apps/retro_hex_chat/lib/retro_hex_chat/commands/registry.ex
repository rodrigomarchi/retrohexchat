defmodule RetroHexChat.Commands.Registry do
  @moduledoc """
  Maps command names to handler modules.
  Handlers are registered at compile time.
  """

  @commands %{
    "alias" => RetroHexChat.Commands.Handlers.Alias,
    "announce" => RetroHexChat.Commands.Handlers.Announce,
    "autorespond" => RetroHexChat.Commands.Handlers.AutoRespond,
    "autojoin" => RetroHexChat.Commands.Handlers.AutoJoin,
    "away" => RetroHexChat.Commands.Handlers.Away,
    "ban" => RetroHexChat.Commands.Handlers.Ban,
    "bio" => RetroHexChat.Commands.Handlers.Bio,
    "clear" => RetroHexChat.Commands.Handlers.Clear,
    "clearmotd" => RetroHexChat.Commands.Handlers.ClearMotd,
    "clearwelcome" => RetroHexChat.Commands.Handlers.ClearWelcome,
    "ctcp" => RetroHexChat.Commands.Handlers.Ctcp,
    "cs" => RetroHexChat.Commands.Handlers.Cs,
    "help" => RetroHexChat.Commands.Handlers.Help,
    "ignore" => RetroHexChat.Commands.Handlers.Ignore,
    "invite" => RetroHexChat.Commands.Handlers.Invite,
    "join" => RetroHexChat.Commands.Handlers.Join,
    "kick" => RetroHexChat.Commands.Handlers.Kick,
    "knock" => RetroHexChat.Commands.Handlers.Knock,
    "leave" => RetroHexChat.Commands.Handlers.Part,
    "list" => RetroHexChat.Commands.Handlers.List,
    "me" => RetroHexChat.Commands.Handlers.Me,
    "mode" => RetroHexChat.Commands.Handlers.Mode,
    "motd" => RetroHexChat.Commands.Handlers.Motd,
    "msg" => RetroHexChat.Commands.Handlers.Msg,
    "nick" => RetroHexChat.Commands.Handlers.Nick,
    "notice" => RetroHexChat.Commands.Handlers.Notice,
    "notice_routing" => RetroHexChat.Commands.Handlers.NoticeRouting,
    "notify" => RetroHexChat.Commands.Handlers.Notify,
    "ns" => RetroHexChat.Commands.Handlers.Ns,
    "part" => RetroHexChat.Commands.Handlers.Part,
    "popups" => RetroHexChat.Commands.Handlers.Popups,
    "perform" => RetroHexChat.Commands.Handlers.Perform,
    "query" => RetroHexChat.Commands.Handlers.Query,
    "quit" => RetroHexChat.Commands.Handlers.Quit,
    "setmotd" => RetroHexChat.Commands.Handlers.SetMotd,
    "setwelcome" => RetroHexChat.Commands.Handlers.SetWelcome,
    "timer" => RetroHexChat.Commands.Handlers.Timer,
    "topic" => RetroHexChat.Commands.Handlers.Topic,
    "umode" => RetroHexChat.Commands.Handlers.Umode,
    "unignore" => RetroHexChat.Commands.Handlers.Unignore,
    "wallops" => RetroHexChat.Commands.Handlers.Wallops,
    "whois" => RetroHexChat.Commands.Handlers.Whois,
    "whowas" => RetroHexChat.Commands.Handlers.Whowas
  }

  @category_order [:basics, :channel, :user, :config, :advanced]
  @category_labels %{
    basics: "Básicos",
    channel: "Canal",
    user: "Usuário",
    config: "Configuração",
    advanced: "Avançado"
  }

  @command_metadata (for {name, module} <- @commands do
                       help = module.help()

                       category =
                         if function_exported?(module, :category, 0),
                           do: module.category(),
                           else: :basics

                       %{
                         name: name,
                         description: help.description,
                         category: Map.fetch!(@category_labels, category),
                         category_atom: category
                       }
                     end)

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

  @doc """
  Returns metadata for all commands: name, description, category label.
  """
  @spec command_metadata() :: [
          %{
            name: String.t(),
            description: String.t(),
            category: String.t(),
            category_atom: atom()
          }
        ]
  def command_metadata, do: @command_metadata

  @doc """
  Returns commands grouped by category in display order.
  Each group is `{category_label, [%{name, description}]}`.
  """
  @spec commands_by_category() :: [{String.t(), [%{name: String.t(), description: String.t()}]}]
  def commands_by_category do
    grouped =
      @command_metadata
      |> Enum.group_by(& &1.category_atom)

    for cat <- @category_order, commands = Map.get(grouped, cat, []), commands != [] do
      label = Map.fetch!(@category_labels, cat)
      sorted = Enum.sort_by(commands, & &1.name)
      {label, Enum.map(sorted, &Map.take(&1, [:name, :description]))}
    end
  end
end
