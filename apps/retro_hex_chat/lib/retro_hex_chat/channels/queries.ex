defmodule RetroHexChat.Channels.Queries do
  @moduledoc "Queries for channel initialization from persisted state."

  alias RetroHexChat.Services.Queries, as: ServiceQueries

  @spec find_registered_channel(String.t()) :: struct() | nil
  def find_registered_channel(name) do
    ServiceQueries.find_registered_channel(name)
  end

  @spec load_persisted_state(String.t()) :: map() | nil
  def load_persisted_state(channel_name) do
    case find_registered_channel(channel_name) do
      nil ->
        nil

      channel ->
        bans = ServiceQueries.list_bans(channel_name)
        ban_exceptions = ServiceQueries.list_ban_exceptions(channel_name)
        invite_exceptions = ServiceQueries.list_invite_exceptions(channel_name)

        %{
          topic: channel.topic || "",
          modes: channel.modes || "",
          mode_key: channel.mode_key,
          mode_limit: channel.mode_limit,
          bans: Enum.map(bans, & &1.banned_nickname),
          ban_exceptions: Enum.map(ban_exceptions, & &1.nickname),
          invite_exceptions: Enum.map(invite_exceptions, & &1.nickname)
        }
    end
  end
end
