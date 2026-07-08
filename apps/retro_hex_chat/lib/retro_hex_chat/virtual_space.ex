defmodule RetroHexChat.VirtualSpace do
  @moduledoc """
  Public API for the virtual space bounded context.

  A virtual space is a multiplayer tile map attached directly to a text
  channel. All external callers use this module; internals live in
  `RetroHexChat.VirtualSpace.*`.
  """

  alias RetroHexChat.VirtualSpace.ChannelSpaceServer
  alias RetroHexChat.VirtualSpace.Map, as: SpaceMap
  alias RetroHexChat.VirtualSpace.Supervisor

  @spec join_channel_space(String.t(), %{user_id: integer() | nil, nickname: String.t()}) ::
          {:ok, %{participant: ChannelSpaceServer.participant(), snapshot: map(), map: map()}}
          | {:error, atom()}
  def join_channel_space(channel_name, actor) do
    with :ok <- ensure_channel_space_process(channel_name) do
      ChannelSpaceServer.join(channel_name, %{user_id: actor.user_id, nickname: actor.nickname})
    end
  end

  @spec input(String.t(), String.t(), ChannelSpaceServer.input_payload()) ::
          :ok | {:error, ChannelSpaceServer.input_error()}
  defdelegate input(channel_name, participant_key, payload), to: ChannelSpaceServer

  @spec interact(String.t(), String.t(), ChannelSpaceServer.interact_payload()) ::
          :ok | {:ok, %{modal: map()}} | {:error, atom()}
  defdelegate interact(channel_name, participant_key, payload), to: ChannelSpaceServer

  @spec action(String.t(), String.t(), ChannelSpaceServer.action_payload()) ::
          :ok | {:error, atom()}
  defdelegate action(channel_name, participant_key, payload), to: ChannelSpaceServer

  @spec leave_channel_space_viewer(String.t()) :: :ok
  defdelegate leave_channel_space_viewer(channel_name),
    to: ChannelSpaceServer,
    as: :leave_channel_viewer

  @spec channel_space_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate channel_space_info(channel_name), to: ChannelSpaceServer, as: :get_state

  @spec snapshot(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate snapshot(channel_name), to: ChannelSpaceServer

  @spec get_map(String.t()) :: {:ok, map()} | {:error, :unknown_map}
  defdelegate get_map(map_id), to: SpaceMap, as: :get

  @spec map_ids() :: [String.t()]
  defdelegate map_ids(), to: SpaceMap, as: :ids

  defp ensure_channel_space_process(channel_name) do
    case RetroHexChat.VirtualSpace.Registry.lookup({:channel_space, channel_name}) do
      {:ok, _pid} ->
        :ok

      {:error, :not_found} ->
        case Supervisor.start_channel_child(channel_name) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end
end
