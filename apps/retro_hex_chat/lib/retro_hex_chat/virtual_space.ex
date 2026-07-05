defmodule RetroHexChat.VirtualSpace do
  @moduledoc """
  Public API for the virtual space bounded context.

  A virtual space is a multiplayer virtual office on a tile map, created from
  a channel via `/space` and joined through a shareable link. All external
  callers (handlers, LiveViews, Channels) use this module; internals live in
  `RetroHexChat.VirtualSpace.*`.
  """

  alias RetroHexChat.VirtualSpace.Map, as: SpaceMap
  alias RetroHexChat.VirtualSpace.Policy
  alias RetroHexChat.VirtualSpace.Queries
  alias RetroHexChat.VirtualSpace.Schema.Session
  alias RetroHexChat.VirtualSpace.Service
  alias RetroHexChat.VirtualSpace.SessionServer

  @spec create_session(Policy.actor(), String.t(), Service.create_opts()) ::
          {:ok, %{session: Session.t(), token: String.t()}}
          | {:error,
             Policy.error() | :ttl_too_long | :create_failed | {:rate_limited, pos_integer()}}
  defdelegate create_session(actor, channel_name, opts), to: Service

  @spec join_session(String.t(), Policy.actor()) ::
          {:ok,
           %{participant: SessionServer.participant(), snapshot: map(), session: Session.t()}}
          | {:error, Policy.error() | :not_found}
  defdelegate join_session(token, actor), to: Service

  @spec leave(String.t(), String.t()) :: :ok
  defdelegate leave(token, participant_key), to: Service

  @spec close_session(String.t(), Policy.actor(), String.t()) ::
          :ok | {:error, Policy.error() | :not_found}
  defdelegate close_session(token, actor, reason), to: Service

  @spec session_summary(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate session_summary(token), to: Service

  @spec session_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate session_info(token), to: SessionServer, as: :get_state

  @spec snapshot(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate snapshot(token), to: SessionServer

  @spec get_session(String.t()) :: {:ok, Session.t()} | {:error, :not_found}
  def get_session(token) do
    case Queries.get_session_by_token(token) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  @spec can_join?(Policy.actor(), Session.t()) :: :ok | {:error, Policy.error()}
  defdelegate can_join?(actor, session), to: Policy

  @spec check_capacity(Session.t(), integer()) :: :ok | {:error, :space_full}
  defdelegate check_capacity(session, user_id), to: Service

  @spec get_map(String.t()) :: {:ok, map()} | {:error, :unknown_map}
  defdelegate get_map(map_id), to: SpaceMap, as: :get

  @spec map_ids() :: [String.t()]
  defdelegate map_ids(), to: SpaceMap, as: :ids
end
