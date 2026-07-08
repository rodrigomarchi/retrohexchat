defmodule RetroHexChat.VirtualSpace do
  @moduledoc """
  Public API for the virtual space bounded context.

  A virtual space is a multiplayer tile map attached directly to a text
  channel. All external callers use this module; internals live in
  `RetroHexChat.VirtualSpace.*`.
  """

  alias RetroHexChat.VirtualSpace.Map, as: SpaceMap
  alias RetroHexChat.VirtualSpace.SessionServer
  alias RetroHexChat.VirtualSpace.Supervisor

  @spec join_channel_space(String.t(), %{user_id: integer() | nil, nickname: String.t()}) ::
          {:ok, %{participant: SessionServer.participant(), snapshot: map(), map: map()}}
          | {:error, atom()}
  def join_channel_space(channel_name, actor) do
    with :ok <- ensure_channel_space_process(channel_name) do
      SessionServer.join(channel_name, %{user_id: actor.user_id, nickname: actor.nickname})
    end
  end

  @spec input(String.t(), String.t(), SessionServer.input_payload()) ::
          :ok | {:error, SessionServer.input_error()}
  defdelegate input(token, participant_key, payload), to: SessionServer

  @spec interact(String.t(), String.t(), SessionServer.interact_payload()) ::
          :ok | {:ok, %{modal: map()}} | {:error, atom()}
  defdelegate interact(token, participant_key, payload), to: SessionServer

  @spec chat_bubble(String.t(), String.t(), String.t()) :: :ok | {:error, atom()}
  defdelegate chat_bubble(token, participant_key, text), to: SessionServer

  @spec admin_action(String.t(), SessionServer.actor(), map()) :: :ok | {:error, atom()}
  defdelegate admin_action(token, actor, action), to: SessionServer

  @spec leave_channel_space_viewer(String.t()) :: :ok
  defdelegate leave_channel_space_viewer(channel_name),
    to: SessionServer,
    as: :leave_channel_viewer

  @spec session_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate session_info(token), to: SessionServer, as: :get_state

  @spec snapshot(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate snapshot(token), to: SessionServer

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
