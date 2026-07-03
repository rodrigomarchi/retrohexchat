defmodule RetroHexChat.Arcade do
  @moduledoc """
  Public API for the Arcade bounded context.
  Single-player WASM games (Doom, Quake) with isolated session management.
  """

  alias RetroHexChat.Arcade.{Catalog, Content, Queries, Service, SoloSessionServer}
  alias RetroHexChat.Arcade.Schema.SoloSession
  alias RetroHexChat.Services.Queries, as: ServiceQueries

  @typedoc """
  Resolved, presentation-ready summary of a solo arcade session for a chat
  activity card. The creator nick is resolved from `creator_id`; the game name
  from the catalog; timestamps stay raw for timezone-aware rendering.
  """
  @type summary :: %{
          kind: :arcade,
          token: String.t(),
          status: String.t(),
          terminal?: boolean(),
          created_by: String.t() | nil,
          created_at: DateTime.t() | nil,
          lobby_at: DateTime.t() | nil,
          started_at: DateTime.t() | nil,
          closed_at: DateTime.t() | nil,
          closed_reason: String.t() | nil,
          duration_seconds: integer() | nil,
          game_id: String.t() | nil,
          game_name: String.t() | nil
        }

  # --- Session lifecycle ---

  @spec create_session(integer()) ::
          {:ok, %{session: SoloSession.t(), token: String.t()}} | {:error, String.t()}
  defdelegate create_session(creator_id), to: Service

  @spec join_session(String.t(), integer()) :: :ok | {:error, String.t()}
  defdelegate join_session(token, user_id), to: Service

  @spec close_session(String.t(), integer(), String.t()) :: :ok | {:error, String.t()}
  defdelegate close_session(token, user_id, reason), to: Service

  @spec get_session(String.t()) :: {:ok, SoloSession.t()} | {:error, :not_found}
  def get_session(token) do
    case Queries.get_session_by_token(token) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  @doc """
  Resolves a solo arcade session into a `t:summary/0` for rendering a rich
  activity card (creator nick, game name, lifecycle timestamps, duration).
  """
  @spec session_summary(String.t()) :: {:ok, summary()} | {:error, :not_found}
  def session_summary(token) do
    case Queries.get_session_by_token(token) do
      nil ->
        {:error, :not_found}

      session ->
        {:ok,
         %{
           kind: :arcade,
           token: session.token,
           status: session.status,
           terminal?: SoloSession.terminal?(session.status),
           created_by: ServiceQueries.get_nickname_by_id(session.creator_id),
           created_at: session.inserted_at,
           lobby_at: session.lobby_at,
           started_at: session.game_started_at,
           closed_at: session.closed_at,
           closed_reason: session.closed_reason,
           duration_seconds: session.duration_seconds,
           game_id: session.game_id,
           game_name: game_name(session.game_id)
         }}
    end
  end

  defp game_name(nil), do: nil

  defp game_name(game_id) do
    case Catalog.get_game(game_id) do
      {:ok, game} -> game.name
      {:error, :not_found} -> nil
    end
  end

  @spec session_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate session_info(token), to: SoloSessionServer, as: :get_state

  # --- Lobby ---

  @spec select_game(String.t(), integer(), String.t()) :: :ok | {:error, atom() | String.t()}
  defdelegate select_game(token, user_id, game_id), to: Service

  # --- Game lifecycle ---

  @spec finish_game(String.t(), integer()) :: :ok | {:error, atom()}
  defdelegate finish_game(token, user_id), to: Service

  # --- Catalog ---

  @spec list_games() :: [Catalog.game()]
  defdelegate list_games, to: Catalog

  @spec get_game(String.t()) :: {:ok, Catalog.game()} | {:error, :not_found}
  defdelegate get_game(game_id), to: Catalog

  # --- Content ---

  @spec get_game_content(String.t()) :: {:ok, Content.content()} | {:error, :not_found}
  defdelegate get_game_content(game_id), to: Content, as: :get_content
end
