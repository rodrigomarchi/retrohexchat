defmodule RetroHexChat.Bots.Lifecycle do
  @moduledoc """
  Runtime lifecycle operations for configured bots.
  """
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Bots.{Bot, Queries, Registry, Server, Supervisor}

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

  @spec destroy_bot(Bot.t()) :: {:ok, Bot.t()} | {:error, Ecto.Changeset.t()}
  def destroy_bot(%Bot{} = bot) do
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
