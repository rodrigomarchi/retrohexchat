defmodule RetroHexChat.Arcade do
  @moduledoc """
  Public API for the Arcade bounded context.
  Single-player WASM games (Doom, Quake) with isolated session management.
  """

  alias RetroHexChat.Arcade.{Catalog, Content, Queries, Service, SoloSessionServer}
  alias RetroHexChat.Arcade.Schema.SoloSession

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
