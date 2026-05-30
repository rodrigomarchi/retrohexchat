defmodule RetroHexChat.Commands.Handlers.Admin.Server do
  @moduledoc "Admin subcommands for server management."

  alias RetroHexChat.Admin
  alias RetroHexChat.Admin.AuditLogs
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Services.Queries

  @valid_settings ~w(server_name server_description welcome_message max_channels registration whowas_retention_seconds)

  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(["info"], context) do
    server_name = Queries.get_setting("server_name") || "RetroHexChat"
    server_desc = Queries.get_setting("server_description")
    online_count = length(Tracker.list_users("presence:global"))

    channel_count =
      case Registry.select(RetroHexChat.Channels.ChannelRegistry, [{{:_, :_, :_}, [], [true]}]) do
        list -> length(list)
      end

    nick_count = Queries.count_registered_nicks()
    registration = Queries.get_setting("registration") || "open"
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    uptime_hours = div(uptime_ms, 3_600_000)
    uptime_days = div(uptime_hours, 24)
    remaining_hours = rem(uptime_hours, 24)

    AuditLogs.log(context.nickname, "server.info")

    desc_line = if server_desc, do: "\n#{server_desc}", else: ""

    text =
      "*** #{server_name} ***#{desc_line}\n" <>
        "Users online: #{online_count}\n" <>
        "Active channels: #{channel_count}\n" <>
        "Registered nicks: #{nick_count}\n" <>
        "Registration: #{registration}\n" <>
        "BEAM uptime: #{uptime_days}d #{remaining_hours}h"

    {:ok, :system, %{content: text}}
  end

  def execute(["set", key, value], context) when key in @valid_settings do
    case validate_setting_value(key, value) do
      :ok ->
        case Admin.set_setting(key, value, context.nickname) do
          {:ok, msg} -> {:ok, :system, %{content: "*** #{msg}"}}
          {:error, msg} -> {:error, msg}
        end

      {:error, msg} ->
        {:error, msg}
    end
  end

  def execute(["set", key | rest], context) when key in @valid_settings do
    value = Enum.join(rest, " ")
    execute(["set", key, value], context)
  end

  def execute(["set", key | _], _context) do
    {:error, "Unknown setting: #{key}. Valid: #{Enum.join(@valid_settings, ", ")}"}
  end

  def execute(["get", key], _context) do
    value = Queries.get_setting(key)
    text = if value, do: "*** #{key} = '#{value}'", else: "*** #{key} is not set"
    {:ok, :system, %{content: text}}
  end

  def execute(["settings"], _context) do
    settings = Queries.list_settings()

    text =
      if settings == [] do
        "*** No server settings configured."
      else
        header = "*** Server Settings ***"

        lines =
          Enum.map(settings, fn s ->
            "  #{s.key} = '#{s.value}' (by #{s.updated_by})"
          end)

        Enum.join([header | lines], "\n")
      end

    {:ok, :system, %{content: text}}
  end

  def execute([], _context) do
    {:error, "Usage: /admin server <info|set|get|settings>"}
  end

  def execute([subcmd | _], _context) do
    {:error, "Unknown server subcommand: #{subcmd}. Try: info, set, get, settings"}
  end

  @spec validate_setting_value(String.t(), String.t()) :: :ok | {:error, String.t()}
  defp validate_setting_value("max_channels", value) do
    case Integer.parse(value) do
      {n, ""} when n > 0 -> :ok
      _ -> {:error, "max_channels must be a positive integer"}
    end
  end

  defp validate_setting_value("registration", value) when value in ~w(open closed), do: :ok

  defp validate_setting_value("registration", _) do
    {:error, "registration must be 'open' or 'closed'"}
  end

  defp validate_setting_value("whowas_retention_seconds", value) do
    case Integer.parse(value) do
      {n, ""} when n >= 1 and n <= 86_400 -> :ok
      _ -> {:error, "whowas_retention_seconds must be an integer from 1 to 86400"}
    end
  end

  defp validate_setting_value(_key, _value), do: :ok
end
