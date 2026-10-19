defmodule RetroHexChat.Games.Channels do
  @moduledoc """
  The channels the Retro Games live in: one per game, named after it
  (`#hex-pong`), and `#retro-games` for all of them at once.

  Nobody founds these. The server keeps them — registered under the GameServ
  service, published to the public archive from the day they exist, exempt from
  the expiry that clears a founder's quiet channel — and GameServ sits in each
  one to say what was played there.

  Everything here is idempotent: `ensure_all/0` runs on every boot and leaves
  an existing channel exactly as its operators left it — topic, modes and
  archive included.
  """

  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  alias RetroHexChat.Channels.Server, as: ChannelServer
  alias RetroHexChat.Channels.Supervisor, as: ChannelSupervisor
  alias RetroHexChat.Chat.Archive
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.Queries, as: ServiceQueries
  alias RetroHexChat.Services.RegisteredChannel

  @service "GameServ"
  @feed "#retro-games"

  @doc "The nickname the games service speaks under."
  @spec service() :: String.t()
  def service, do: @service

  @doc "The channel every game's results are also announced in."
  @spec feed() :: String.t()
  def feed, do: @feed

  @doc "Every channel the games service keeps: each game's, then the feed."
  @spec names() :: [String.t()]
  def names, do: Catalog.channel_names() ++ [@feed]

  @doc """
  Make every games channel exist: registered, published, running, with
  GameServ inside. Returns how many were created on this pass.
  """
  @spec ensure_all() :: {:ok, %{created: non_neg_integer(), channels: pos_integer()}}
  def ensure_all do
    created = Enum.count(names(), &(ensure(&1) == :created))
    {:ok, %{created: created, channels: length(names())}}
  end

  @doc """
  Make one games channel exist. `:created` the first time, `:ok` after.
  """
  @spec ensure(String.t()) :: :created | :ok
  def ensure(name) do
    outcome = ensure_registered(name)

    # Published once, as the channel is made. Turning the archive off later
    # is its operators' decision, and a reboot does not undo it.
    if outcome == :created, do: {:ok, _channel} = Archive.publish(name)

    case ensure_present(name) do
      :ok -> :ok
      {:error, reason} -> Logger.warning("Games: GameServ is not in #{name}: #{inspect(reason)}")
    end

    # A process that was already running when the row was written started
    # unregistered, and would stop once its last member left.
    if outcome == :created, do: ChannelServer.mark_registered(name)

    outcome
  end

  @doc """
  Put GameServ in a running games channel, starting the channel if nothing is
  holding it. A channel's membership is its process's, so a channel that
  restarted has forgotten the service was there; asking again is how it comes
  back.
  """
  @spec ensure_present(String.t()) :: :ok | {:error, term()}
  def ensure_present(name) do
    with {:ok, _pid} <- ChannelSupervisor.ensure_started(name) do
      case ChannelServer.join(name, @service, nil, bot: true) do
        {:ok, _joined} -> :ok
        {:error, _already_inside} -> :ok
      end
    end
  end

  defp ensure_registered(name) do
    case ServiceQueries.find_registered_channel(name) do
      %RegisteredChannel{} ->
        :ok

      nil ->
        {:ok, _channel} =
          %RegisteredChannel{}
          |> RegisteredChannel.system_changeset(%{
            name: name,
            founder_nickname: @service,
            topic: topic(name),
            modes: "+nt"
          })
          |> Repo.insert()

        Logger.info("Games: created #{name}")
        :created
    end
  end

  # Written once, in the server's language, as the channel's first topic; its
  # operators own it after that.
  defp topic(@feed),
    do:
      dgettext(
        "games",
        "Every Retro Games match as it finishes. Each game has its own channel too. This channel is archived publicly."
      )

  defp topic(name) do
    {:ok, game_id} = Catalog.game_for_channel(name)
    {:ok, game} = Catalog.get_game(game_id)

    dgettext(
      "games",
      "Results and rankings of %{game}, and people to play with. Everything said here is published in a public archive.",
      game: game.name
    )
  end
end
