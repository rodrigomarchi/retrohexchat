defmodule RetroHexChat.Commands.Handlers.Timer do
  @moduledoc "Handler for /timer [subcommand] [args]"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Chat.TimerManager
  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_raw_args), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:ok, :system,
     %{
       content:
         "Usage: /timer <name> <seconds> <command> — one-shot timer\n" <>
           "       /timer <name> repeat <seconds> <command> — repeating timer\n" <>
           "       /timer list — show active timers\n" <>
           "       /timer stop <name> — cancel a timer"
     }}
  end

  def execute(args, _context) do
    case TimerManager.parse_timer_args(args) do
      {:ok, %{action: :list}} ->
        {:ok, :ui_action, :timer_list, %{}}

      {:ok, %{action: :stop, name: name}} ->
        {:ok, :ui_action, :timer_stop, %{name: name}}

      {:ok, %{action: :create} = data} ->
        {:ok, :ui_action, :timer_create,
         %{
           name: data.name,
           type: data.type,
           interval: data.interval,
           command: data.command
         }}

      {:error, msg} ->
        {:error, msg}
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
      name: "timer",
      syntax: "/timer <name> [repeat] <seconds> <command>",
      description: "Schedule a command to run after a delay. Timers are session-only.",
      examples: [
        "/timer remind 1800 /me reminds everyone: standup in 30 minutes",
        "/timer heartbeat repeat 600 /me is still here",
        "/timer list",
        "/timer stop heartbeat"
      ]
    }
  end

  @impl true
  def category, do: :config

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "timer",
      syntax: "/timer <name> [repeat] <seconds> <command>",
      description: "Schedule a command to run after a delay. Timers are session-only.",
      category: :config,
      parameters: [
        %Parameter{
          name: "name",
          required: true,
          type: :text,
          position: 0,
          description: "Nome do timer"
        },
        %Parameter{
          name: "args",
          required: true,
          type: :text,
          position: 1,
          description: "Configuração: [repeat] <segundos> <comando>"
        }
      ],
      examples: [
        "/timer remind 1800 /me reminds everyone: standup in 30 minutes",
        "/timer heartbeat repeat 600 /me is still here",
        "/timer list",
        "/timer stop heartbeat"
      ]
    }
  end
end
