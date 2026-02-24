defmodule RetroHexChat.Games do
  @moduledoc """
  Public API for the Games bounded context.
  All external callers use this module.
  """

  alias RetroHexChat.Games.{Catalog, Queries, Service, SessionServer}
  alias RetroHexChat.Games.Schema.GameSession

  # --- Session lifecycle ---

  @spec create_session(integer(), integer()) ::
          {:ok, %{session: GameSession.t(), token: String.t()}} | {:error, String.t()}
  defdelegate create_session(creator_id, peer_id), to: Service

  @spec join_session(String.t(), integer()) :: :ok | {:error, String.t()}
  defdelegate join_session(token, user_id), to: Service

  @spec close_session(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
  defdelegate close_session(token, user_id, reason), to: Service

  @spec get_session(String.t()) :: {:ok, GameSession.t()} | {:error, :not_found}
  def get_session(token) do
    case Queries.get_session_by_token(token) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  @spec session_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate session_info(token), to: SessionServer, as: :get_state

  # --- Lobby ---

  @spec send_lobby_message(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
  defdelegate send_lobby_message(token, user_id, content), to: Service

  @spec select_game(String.t(), integer(), String.t()) :: :ok | {:error, atom()}
  defdelegate select_game(token, user_id, game_id), to: Service

  @spec respond_game(String.t(), integer(), boolean()) :: :ok | {:error, atom()}
  defdelegate respond_game(token, user_id, accepted?), to: Service

  # --- Game result ---

  @spec finish_game(String.t(), integer(), map()) :: :ok | {:error, atom()}
  defdelegate finish_game(token, user_id, result), to: Service

  # --- State transitions ---

  @spec transition_status(String.t(), atom()) :: :ok | {:error, String.t()}
  defdelegate transition_status(token, new_status), to: SessionServer, as: :transition

  # --- Catalog ---

  @spec list_games() :: [Catalog.game()]
  defdelegate list_games, to: Catalog

  @spec get_game(String.t()) :: {:ok, Catalog.game()} | {:error, :not_found}
  defdelegate get_game(game_id), to: Catalog

  # --- WebRTC ICE servers (reuse P2P TURN config) ---

  @spec ice_servers(String.t()) :: [map()]
  def ice_servers(user_id) do
    RetroHexChat.P2P.ice_servers(user_id)
  end
end
