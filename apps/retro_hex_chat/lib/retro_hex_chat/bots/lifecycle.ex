defmodule RetroHexChat.Bots.Lifecycle do
  @moduledoc """
  Runtime lifecycle operations for configured bots.
  """
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Accounts.NickLocales
  alias RetroHexChat.Bots.{Bot, Queries, Registry, Server, Supervisor}
  alias RetroHexChat.Bots.Capabilities.Scheduler.Durable, as: ScheduleJobs
  alias RetroHexChat.Locales

  @spec ensure_started(Bot.t()) :: {:ok, pid()} | {:error, term()}
  def ensure_started(%Bot{enabled: false}), do: {:error, :disabled}

  def ensure_started(%Bot{} = bot) do
    case Registry.lookup(bot.nickname) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, :not_found} ->
        bot
        |> runtime_data()
        |> Supervisor.start_bot()
        |> normalize_start()
    end
  end

  @doc """
  Creates a bot from `attrs` and starts it. Every way a bot is made (the
  `/bot create` command and the Bot Management dialog) ends here, so a new bot
  is always running with what the database says it has.
  """
  @spec create(map()) :: {:ok, Bot.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    with {:ok, bot} <- Queries.create_bot(attrs) do
      _ = ensure_started(bot)
      {:ok, bot}
    end
  end

  @doc """
  Stops a running bot and starts it again from the database; a bot that is
  not running stays stopped.
  """
  @spec restart_if_running(Bot.t()) :: :ok | {:error, term()}
  def restart_if_running(%Bot{} = bot) do
    case Registry.lookup(bot.nickname) do
      {:ok, _pid} ->
        Supervisor.stop_bot(bot.nickname)
        bot |> ensure_started() |> normalize_ok()

      {:error, :not_found} ->
        :ok
    end
  end

  @doc "Hands the running bot its custom commands again, read from the database."
  @spec reload_commands(Bot.t()) :: :ok
  def reload_commands(%Bot{} = bot) do
    if_running(bot.nickname, fn nickname ->
      commands =
        Map.new(Queries.list_custom_commands(bot.id), fn cmd ->
          {cmd.trigger,
           %{
             "response" => cmd.response,
             "description" => cmd.description || "",
             "enabled" => cmd.enabled
           }}
        end)

      Server.reload_commands(nickname, commands)
    end)
  end

  @doc """
  Calls `fun` with the bot's nickname when its process is running, and does
  nothing otherwise: a change saved while the bot is stopped reaches it at its
  next start.
  """
  @spec if_running(String.t(), (String.t() -> term())) :: term()
  def if_running(nickname, fun) do
    case Registry.lookup(nickname) do
      {:ok, _pid} -> fun.(nickname)
      {:error, :not_found} -> :ok
    end
  end

  @spec reload_capabilities_or_start(Bot.t()) :: :ok | {:error, term()}
  def reload_capabilities_or_start(%Bot{enabled: false}), do: :ok

  def reload_capabilities_or_start(%Bot{} = bot) do
    case Registry.lookup(bot.nickname) do
      {:ok, _pid} ->
        Server.reload_capabilities(bot.nickname, bot.capabilities)

      {:error, :not_found} ->
        bot
        |> ensure_started()
        |> normalize_ok()
    end
  catch
    :exit, _reason ->
      bot
      |> ensure_started()
      |> normalize_ok()
  end

  @doc """
  Sets the language `bot` speaks — a code the chat offers, written however
  (`pt-br`, `PT_BR`) — or clears it with `nil`, and tells every open screen,
  which draws the flag beside the bot's nickname again.
  """
  @spec set_locale(Bot.t(), String.t() | nil) ::
          {:ok, Bot.t()} | {:error, :unknown_locale | Ecto.Changeset.t()}
  def set_locale(%Bot{} = bot, nil), do: put_locale(bot, nil)

  def set_locale(%Bot{} = bot, locale) do
    case Locales.normalize(locale) do
      nil -> {:error, :unknown_locale}
      code -> put_locale(bot, code)
    end
  end

  defp put_locale(bot, locale) do
    with {:ok, updated} <- Queries.update_bot(bot, %{locale: locale}) do
      if bot.locale != locale, do: NickLocales.announce(bot.nickname, locale)
      {:ok, updated}
    end
  end

  @spec destroy_bot(Bot.t()) :: {:ok, Bot.t()} | {:error, Ecto.Changeset.t()}
  def destroy_bot(%Bot{} = bot) do
    ScheduleJobs.cancel_bot(bot.id)
    part_from_configured_channels(bot)
    Supervisor.stop_bot(bot.nickname)
    Queries.delete_bot(bot)
  end

  @spec part_from_configured_channels(Bot.t()) :: :ok
  def part_from_configured_channels(%Bot{} = bot) do
    bot.id
    |> Queries.list_channel_configs()
    |> Enum.each(&part_channel(bot, &1.channel_name))

    :ok
  end

  defp part_channel(bot, channel) do
    case Registry.lookup(bot.nickname) do
      {:ok, _pid} ->
        case safe_bot_part(bot.nickname, channel) do
          :ok -> :ok
          _ -> direct_channel_part(channel, bot.nickname)
        end

      {:error, :not_found} ->
        direct_channel_part(channel, bot.nickname)
    end
  end

  defp safe_bot_part(nickname, channel) do
    Server.part_channel(nickname, channel)
  catch
    :exit, _reason -> {:error, :exit}
  end

  defp direct_channel_part(channel, nickname) do
    case RetroHexChat.Channels.Registry.lookup(channel) do
      {:ok, _pid} ->
        RetroHexChat.Channels.Server.part(channel, nickname, dgettext("bots", "Bot destroyed"))
        :ok

      {:error, :not_found} ->
        :ok
    end
  catch
    :exit, _reason -> :ok
  end

  @spec runtime_data(Bot.t()) :: map()
  defp runtime_data(%Bot{} = bot) do
    bot = Queries.preload_associations(bot)

    %{
      id: bot.id,
      name: bot.name,
      nickname: bot.nickname,
      command_prefix: bot.command_prefix,
      created_by: bot.created_by,
      enabled: bot.enabled,
      cooldown_ms: bot.cooldown_ms,
      capabilities: bot.capabilities,
      channel_configs: bot.channel_configs,
      custom_commands: bot.custom_commands
    }
  end

  @spec normalize_start(DynamicSupervisor.on_start_child()) :: {:ok, pid()} | {:error, term()}
  defp normalize_start({:ok, pid}), do: {:ok, pid}
  defp normalize_start({:ok, pid, _info}), do: {:ok, pid}
  defp normalize_start({:error, {:already_started, pid}}), do: {:ok, pid}
  defp normalize_start({:error, reason}), do: {:error, reason}

  @spec normalize_ok({:ok, pid()} | {:error, term()}) :: :ok | {:error, term()}
  defp normalize_ok({:ok, _pid}), do: :ok
  defp normalize_ok({:error, reason}), do: {:error, reason}
end
