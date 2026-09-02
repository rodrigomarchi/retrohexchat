defmodule RetroHexChat.VirtualSpace do
  @moduledoc """
  Public API for the virtual space bounded context.

  A virtual space is a multiplayer tile map attached directly to a text
  channel. All external callers use this module; internals live in
  `RetroHexChat.VirtualSpace.*`.
  """

  alias RetroHexChat.Observability
  alias RetroHexChat.VirtualSpace.ChannelSpaceServer
  alias RetroHexChat.VirtualSpace.DirectMessageSpace
  alias RetroHexChat.VirtualSpace.Map, as: SpaceMap
  alias RetroHexChat.VirtualSpace.Schema.Session
  alias RetroHexChat.VirtualSpace.SessionRecorder
  alias RetroHexChat.VirtualSpace.Supervisor

  @typedoc """
  What one join produced, beyond a seat in the world.

  `session` is filled in for the person who walked into an empty space and for
  nobody else: it is the gathering they just started, and the caller that gets
  it is the one that owes the conversation a card.
  """
  @type join_result :: %{
          participant: ChannelSpaceServer.participant(),
          snapshot: map(),
          map: map(),
          session: SessionRecorder.opened() | nil
        }

  @spec join_channel_space(String.t(), %{
          :user_id => integer() | nil,
          :nickname => String.t(),
          optional(:avatar) => String.t() | nil
        }) :: {:ok, join_result()} | {:error, atom()}
  def join_channel_space(channel_name, actor) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :join],
      %{"chat.channel" => channel_name, space_kind: "channel"},
      fn ->
        with {:ok, started} <- ensure_channel_space_process(channel_name) do
          session = record_opening(started, channel_name, :channel, actor)

          channel_name
          |> ChannelSpaceServer.join(%{
            user_id: actor.user_id,
            nickname: actor.nickname,
            avatar: Map.get(actor, :avatar)
          })
          |> with_session(session)
        end
      end
    )
  end

  @spec join_direct_message_space(
          String.t(),
          %{
            :user_id => integer() | nil,
            :nickname => String.t(),
            optional(:avatar) => String.t() | nil
          },
          [String.t()]
        ) :: {:ok, join_result()} | {:error, atom()}
  def join_direct_message_space(space_id, actor, participants) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :join],
      %{space_kind: "direct_message"},
      fn ->
        with {:ok, started} <- ensure_direct_message_space_process(space_id, participants) do
          session = record_opening(started, space_id, :direct_message, actor)

          space_id
          |> ChannelSpaceServer.join_direct_message(%{
            user_id: actor.user_id,
            nickname: actor.nickname,
            avatar: Map.get(actor, :avatar)
          })
          |> with_session(session)
        end
      end
    )
  end

  # A gathering begins when somebody walks into an empty world, which is the
  # same moment the world itself begins. Exactly one caller sees the process
  # start — the losers of the race get `:already_started` — so exactly one
  # gathering is opened, and exactly one card is written for it.
  #
  # Everybody else is an arrival, told to the recorder rather than read off the
  # roster: a channel space draws the whole channel on its map, so the roster
  # answers who belongs here and the card asks who actually came.
  defp record_opening({:started, pid}, space_id, kind, actor),
    do: SessionRecorder.opened(space_id, kind, pid, actor)

  defp record_opening(:running, space_id, _kind, actor) do
    SessionRecorder.arrived(space_id, actor.nickname)
    nil
  end

  defp with_session({:ok, result}, session), do: {:ok, Map.put(result, :session, session)}
  defp with_session(other, _session), do: other

  @spec input(String.t(), String.t(), ChannelSpaceServer.input_payload()) ::
          :ok | {:error, ChannelSpaceServer.input_error()}
  def input(channel_name, participant_key, payload) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :input],
      %{"chat.channel" => channel_name, space_kind: "channel"},
      fn -> ChannelSpaceServer.input(channel_name, participant_key, payload) end
    )
  end

  @spec input_direct_message(String.t(), String.t(), ChannelSpaceServer.input_payload()) ::
          :ok | {:error, ChannelSpaceServer.input_error()}
  def input_direct_message(space_id, participant_key, payload) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :input],
      %{space_kind: "direct_message"},
      fn -> ChannelSpaceServer.input_direct_message(space_id, participant_key, payload) end
    )
  end

  @spec interact(String.t(), String.t(), ChannelSpaceServer.interact_payload()) ::
          :ok | {:ok, %{modal: map()}} | {:error, atom()}
  def interact(channel_name, participant_key, payload) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :interact],
      %{"chat.channel" => channel_name, space_kind: "channel"},
      fn -> ChannelSpaceServer.interact(channel_name, participant_key, payload) end
    )
  end

  @spec interact_direct_message(String.t(), String.t(), ChannelSpaceServer.interact_payload()) ::
          :ok | {:ok, %{modal: map()}} | {:error, atom()}
  def interact_direct_message(space_id, participant_key, payload) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :interact],
      %{space_kind: "direct_message"},
      fn -> ChannelSpaceServer.interact_direct_message(space_id, participant_key, payload) end
    )
  end

  @spec action(String.t(), String.t(), ChannelSpaceServer.action_payload()) ::
          :ok | {:error, atom()}
  def action(channel_name, participant_key, payload) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :action],
      %{"chat.channel" => channel_name, space_kind: "channel"},
      fn -> ChannelSpaceServer.action(channel_name, participant_key, payload) end
    )
  end

  @spec action_direct_message(String.t(), String.t(), ChannelSpaceServer.action_payload()) ::
          :ok | {:error, atom()}
  def action_direct_message(space_id, participant_key, payload) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :action],
      %{space_kind: "direct_message"},
      fn -> ChannelSpaceServer.action_direct_message(space_id, participant_key, payload) end
    )
  end

  @spec avatars() :: [String.t()]
  defdelegate avatars(), to: ChannelSpaceServer

  @spec step_ms() :: non_neg_integer()
  defdelegate step_ms(), to: ChannelSpaceServer

  @spec select_avatar(String.t(), String.t(), String.t()) :: :ok | {:error, atom()}
  def select_avatar(channel_name, participant_key, avatar) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :avatar, :select],
      %{"chat.channel" => channel_name, space_kind: "channel", avatar: avatar},
      fn -> ChannelSpaceServer.select_avatar(channel_name, participant_key, avatar) end
    )
  end

  @spec select_avatar_direct_message(String.t(), String.t(), String.t()) ::
          :ok | {:error, atom()}
  def select_avatar_direct_message(space_id, participant_key, avatar) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :avatar, :select],
      %{space_kind: "direct_message", avatar: avatar},
      fn -> ChannelSpaceServer.select_avatar_direct_message(space_id, participant_key, avatar) end
    )
  end

  @spec leave_channel_space_viewer(String.t()) :: :ok
  defdelegate leave_channel_space_viewer(channel_name),
    to: ChannelSpaceServer,
    as: :leave_channel_viewer

  @spec leave_direct_message_space_viewer(String.t(), String.t()) :: :ok
  defdelegate leave_direct_message_space_viewer(space_id, participant_key),
    to: ChannelSpaceServer,
    as: :leave_direct_message_viewer

  @spec channel_space_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate channel_space_info(channel_name), to: ChannelSpaceServer, as: :get_state

  @spec direct_message_space_info(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate direct_message_space_info(space_id),
    to: ChannelSpaceServer,
    as: :get_direct_message_state

  @spec snapshot(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate snapshot(channel_name), to: ChannelSpaceServer

  @spec direct_message_snapshot(String.t()) :: {:ok, map()} | {:error, :not_found}
  defdelegate direct_message_snapshot(space_id), to: ChannelSpaceServer

  @doc """
  Who is standing in a space right now, by nickname.

  The one question the screens outside a space ask of it: the antechamber
  someone is waiting in, and the card the chat draws for a space its reader is
  not in. A space nobody has opened has no process, and **nobody is inside** is
  the answer for it — the members of the channel a space hangs off are not
  people in the space, and a card that counted them would announce a crowd
  standing in an empty room.
  """
  @spec roster(String.t()) :: [String.t()]
  def roster(space_id) do
    case space_kind(space_id) do
      :direct_message -> nicknames(direct_message_snapshot(space_id))
      :channel -> nicknames(snapshot(space_id))
    end
  end

  @doc """
  Which of the two kinds of space an id names.

  The id carries it: a private space is keyed by its two participants and says
  so in its prefix, a channel space is the channel's own name. Reading it from
  the id is what lets an address resolve to a space without a lookup, and it is
  written once here so the prefix is not spelled out at each caller.
  """
  @spec space_kind(String.t()) :: :channel | :direct_message
  def space_kind("dm:" <> _rest), do: :direct_message
  def space_kind(_space_id), do: :channel

  @doc """
  One gathering by its token, whether it is still going or long over.

  The card in a conversation is about a gathering rather than about the place:
  the address of a space stays good forever, and a card that read the place
  would say the same thing about a party that ended last month as about the one
  happening now.
  """
  @spec get_session(String.t()) :: {:ok, Session.t()} | {:error, :not_found}
  def get_session(token) when is_binary(token) do
    case SessionRecorder.get_session(token) do
      %Session{} = session -> {:ok, session}
      nil -> {:error, :not_found}
    end
  end

  def get_session(_token), do: {:error, :not_found}

  @doc "The gathering going on in a space right now, or `nil`."
  @spec open_session(String.t()) :: Session.t() | nil
  defdelegate open_session(space_id), to: SessionRecorder

  @doc "How many distinct people passed through one gathering."
  @spec session_visitors(Session.t()) :: non_neg_integer()
  def session_visitors(%Session{id: id}), do: SessionRecorder.count_visitors(id)

  defp nicknames({:ok, %{participants: participants}}) do
    participants |> Elixir.Map.values() |> Enum.map(& &1.nickname) |> Enum.sort()
  end

  defp nicknames(_absent), do: []

  @spec get_map(String.t()) :: {:ok, map()} | {:error, :unknown_map}
  defdelegate get_map(map_id), to: SpaceMap, as: :get

  @spec map_ids() :: [String.t()]
  defdelegate map_ids(), to: SpaceMap, as: :ids

  @spec direct_message_space_id(String.t(), String.t()) :: String.t()
  defdelegate direct_message_space_id(nick_a, nick_b), to: DirectMessageSpace, as: :space_id

  defp ensure_channel_space_process(channel_name) do
    case RetroHexChat.VirtualSpace.Registry.lookup({:channel_space, channel_name}) do
      {:ok, _pid} -> {:ok, :running}
      {:error, :not_found} -> started(Supervisor.start_channel_child(channel_name))
    end
  end

  defp started({:ok, pid}), do: {:ok, {:started, pid}}
  defp started({:error, {:already_started, _pid}}), do: {:ok, :running}
  defp started({:error, reason}), do: {:error, reason}

  defp ensure_direct_message_space_process(space_id, participants) do
    case validate_direct_message_space(space_id, participants) do
      {:ok, participants} -> ensure_direct_message_child(space_id, participants)
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_direct_message_space(space_id, participants) do
    with {:ok, [nick_a, nick_b] = participants} <-
           DirectMessageSpace.normalize_participants(participants),
         ^space_id <- DirectMessageSpace.space_id(nick_a, nick_b) do
      {:ok, participants}
    else
      _ -> {:error, :invalid_participants}
    end
  end

  defp ensure_direct_message_child(space_id, participants) do
    case RetroHexChat.VirtualSpace.Registry.lookup({:direct_message_space, space_id}) do
      {:ok, _pid} ->
        {:ok, :running}

      {:error, :not_found} ->
        started(Supervisor.start_direct_message_child(space_id, participants))
    end
  end
end
