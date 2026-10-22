defmodule RetroHexChat.Arcade do
  @moduledoc """
  Public API for the Arcade bounded context.
  Single-player WASM games with isolated session management.
  """

  alias RetroHexChat.Arcade.{Catalog, Content, Plays, Queries, Service}
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

  @spec game_name(String.t()) :: String.t()
  defdelegate game_name(game_id), to: Catalog

  @spec engine_name(atom()) :: String.t()
  defdelegate engine_name(engine), to: Catalog

  @spec game_url(Catalog.game()) :: String.t()
  defdelegate game_url(game), to: Catalog

  # --- Channels ---

  @spec channel_name(String.t()) :: String.t()
  defdelegate channel_name(game_id), to: Catalog

  @spec feed_channel() :: String.t()
  defdelegate feed_channel, to: Catalog

  @spec game_for_channel(String.t()) :: {:ok, String.t()} | :error
  defdelegate game_for_channel(channel), to: Catalog

  # --- Plays ---

  @spec play_cards_for_messages([integer()]) :: %{integer() => Plays.card()}
  defdelegate play_cards_for_messages(ids), to: Plays, as: :cards_for_messages

  @spec recent_plays(String.t(), pos_integer()) :: [map()]
  defdelegate recent_plays(game_id, limit), to: Plays, as: :recent

  @spec most_played(String.t(), DateTime.t(), pos_integer()) :: [map()]
  defdelegate most_played(game_id, since, limit), to: Plays

  @spec play_count_since(String.t(), DateTime.t()) :: non_neg_integer()
  defdelegate play_count_since(game_id, since), to: Plays, as: :count_since

  @spec player_plays(String.t(), integer()) :: map()
  defdelegate player_plays(game_id, player_id), to: Plays, as: :player_record

  # --- Content ---

  @spec get_game_content(String.t()) :: {:ok, Content.content()} | {:error, :not_found}
  defdelegate get_game_content(game_id), to: Content, as: :get_content
end
