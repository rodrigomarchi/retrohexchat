defmodule RetroHexChat.VirtualSpace do
  @moduledoc """
  Public API for the virtual space bounded context.

  A virtual space is a multiplayer tile map attached directly to a text
  channel. All external callers use this module; internals live in
  `RetroHexChat.VirtualSpace.*`.
  """

  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  alias RetroHexChat.Admin.GlobalMutes
  alias RetroHexChat.Observability
  alias RetroHexChat.VirtualSpace.ChannelSpaceServer
  alias RetroHexChat.VirtualSpace.Construct
  alias RetroHexChat.VirtualSpace.Construct.Layout
  alias RetroHexChat.VirtualSpace.Construct.Panels
  alias RetroHexChat.VirtualSpace.Construct.Store
  alias RetroHexChat.VirtualSpace.DirectMessageSpace
  alias RetroHexChat.VirtualSpace.Map, as: SpaceMap
  alias RetroHexChat.VirtualSpace.Schema.Session
  alias RetroHexChat.VirtualSpace.SessionRecorder
  alias RetroHexChat.VirtualSpace.Speech
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

  @doc """
  Walk into a space's Construct.

  The room is started on the first arrival with whatever was built in it last
  time. No gathering is recorded and no card is written: the Construct is a room
  of the space, and the space's own gathering already stands for the visit.
  `participants` are the pair of a private space, as its join token names them;
  a channel's Construct reads its members from the channel.
  """
  @spec join_construct_space(
          String.t(),
          %{
            :user_id => integer() | nil,
            :nickname => String.t(),
            optional(:avatar) => String.t() | nil
          },
          [String.t()] | nil
        ) :: {:ok, join_result()} | {:error, atom()}
  def join_construct_space(construct_id, actor, participants) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :join],
      %{space_kind: "construct"},
      fn -> join_construct(construct_id, actor, participants, 3) end
    )
  end

  # The last one out stops the room, and its registry entry outlives it for a
  # moment: somebody walking in through the gate in that moment finds a room
  # that is already gone. Asking again finds it gone for good, and starts it.
  defp join_construct(construct_id, actor, participants, attempts) do
    with {:ok, started} <- ensure_construct_process(construct_id, participants) do
      count_in_gathering(started, construct_id, actor.nickname)

      construct_id
      |> ChannelSpaceServer.join(%{
        user_id: actor.user_id,
        nickname: actor.nickname,
        avatar: Map.get(actor, :avatar)
      })
      |> case do
        {:error, :not_found} when attempts > 1 ->
          Process.sleep(10)
          join_construct(construct_id, actor, participants, attempts - 1)

        joined ->
          with_session(joined, nil)
      end
    end
  end

  @doc """
  One edit to a Construct: place, move, remove or turn a piece, write on a
  sign, or paint the floor.

  The runtime decides; this stores what it decided, so the room is there the
  next time anybody comes back. A failed write is logged and the edit stands —
  the next one rewrites the whole room anyway.
  """
  @spec build_construct(String.t(), String.t(), String.t(), Layout.op()) ::
          {:ok, non_neg_integer()} | {:error, ChannelSpaceServer.build_error()}
  def build_construct(construct_id, participant_key, nickname, op) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :construct, :build],
      %{space_kind: "construct", op: elem(op, 0)},
      fn ->
        with {:ok, op} <- authorize_edit(construct_id, nickname, op),
             {:ok, %{revision: revision} = layout} <-
               ChannelSpaceServer.build(construct_id, participant_key, op) do
          persist_construct(construct_id, layout, revision, nickname)
          {:ok, revision}
        end
      end
    )
  end

  # Writing on a sign is saying something to everyone who walks in: the muted
  # cannot, and the conversation's moderators may rewrite anybody's.
  defp authorize_edit(construct_id, nickname, {:label, id, text}) do
    if GlobalMutes.muted?(nickname),
      do: {:error, :muted},
      else: {:ok, {:label, id, text, moderator?(construct_id, nickname)}}
  end

  defp authorize_edit(_construct_id, _nickname, op), do: {:ok, op}

  defp moderator?(construct_id, nickname) do
    case Construct.parent_id(construct_id) do
      # Either person of a private conversation speaks for it.
      {:ok, "dm:" <> _pair} ->
        true

      {:ok, channel_name} ->
        Panels.moderator?({:channel, channel_name}, nickname)

      :error ->
        false
    end
  end

  @doc """
  Fill in the panel a Construct piece opened — a board's topic and pins, a
  screen's newest picture, whether a sign may be rewritten by `nickname`.
  """
  @spec fill_construct_panel(Panels.modal(), Speech.conversation(), String.t() | nil) ::
          Panels.modal()
  defdelegate fill_construct_panel(modal, conversation, nickname), to: Panels, as: :fill

  defp persist_construct(construct_id, layout, revision, nickname) do
    case Store.save(construct_id, layout, revision, nickname) do
      :ok ->
        :ok

      {:error, changeset} ->
        Logger.error(
          "Construct layout not stored: construct_id=#{construct_id} " <>
            "revision=#{revision} errors=#{inspect(changeset.errors)}"
        )
    end
  end

  @spec leave_construct_space_viewer(String.t(), String.t()) :: :ok
  defdelegate leave_construct_space_viewer(construct_id, participant_key),
    to: ChannelSpaceServer,
    as: :leave_construct_viewer

  @doc "The Construct behind a space's gate."
  @spec construct_id(String.t()) :: String.t()
  defdelegate construct_id(parent_id), to: Construct, as: :space_id

  @doc "The space a Construct belongs to."
  @spec construct_parent(String.t()) :: {:ok, String.t()} | :error
  defdelegate construct_parent(construct_id), to: Construct, as: :parent_id

  # The Construct is a room of its space's gathering: walking into it is
  # arriving at that gathering, and starting it adds a world the gathering is
  # going on in.
  defp count_in_gathering(started, construct_id, nickname) do
    {:ok, parent_id} = Construct.parent_id(construct_id)

    case started do
      {:started, pid} -> SessionRecorder.construct_started(parent_id, pid, nickname)
      :running -> SessionRecorder.arrived(parent_id, nickname)
    end
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

  @doc """
  Sit, stand or press E on something. In a Construct, a piece that changed is
  stored, and a die rolled or a coin flipped is said in the conversation by
  whoever did it — `nickname`, which only a Construct needs.
  """
  @spec interact(String.t(), String.t(), ChannelSpaceServer.interact_payload(), String.t() | nil) ::
          :ok | {:ok, %{modal: map()}} | {:error, atom()}
  def interact(space_id, participant_key, payload, nickname \\ nil) do
    Observability.span(
      [:retro_hex_chat, :virtual_space, :interact],
      %{"chat.channel" => space_id, space_kind: Atom.to_string(space_kind(space_id))},
      fn ->
        space_id
        |> ChannelSpaceServer.interact(participant_key, payload)
        |> after_use(space_id, nickname)
      end
    )
  end

  defp after_use({:ok, %{changed: changed} = used}, construct_id, nickname) do
    persist_construct(construct_id, changed, changed.revision, nickname)
    announce_roll(used[:announce], nickname)
    :ok
  end

  defp after_use(result, _space_id, _nickname), do: result

  defp announce_roll(%{conversation: conversation, kind: kind, face: face}, nickname)
       when is_binary(nickname) do
    case Speech.say(conversation, nickname, "/me " <> roll_line(kind, face)) do
      :ok -> :ok
      {:error, reason} -> Logger.debug("Construct roll not said: #{inspect(reason)}")
    end
  end

  defp announce_roll(_announce, _nickname), do: :ok

  defp roll_line("die", face), do: dgettext("chat", "threw the dice and got %{face}", face: face)
  # The coin's two faces are its gold and its silver side, which is what the
  # piece shows; heads and tails are idioms no two languages share.
  defp roll_line("coin", "heads"),
    do: dgettext("chat", "threw the coin, and it landed gold side up")

  defp roll_line("coin", _tails),
    do: dgettext("chat", "threw the coin, and it landed silver side up")

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

  @spec step_ms() :: non_neg_integer()
  defdelegate step_ms(), to: ChannelSpaceServer

  @spec action_ms() :: non_neg_integer()
  defdelegate action_ms(), to: ChannelSpaceServer

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

  @spec leave_channel_space_viewer(String.t(), String.t()) :: :ok
  defdelegate leave_channel_space_viewer(channel_name, participant_key),
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
  not in. A channel's space is standing room for the whole channel, so once it
  is running every member is in it, whether or not they opened the map. A
  space nobody has opened has no process, and **nobody is inside** is the
  answer for it — the channel's members are only standing in a space that is
  actually there.
  """
  @spec roster(String.t()) :: [String.t()]
  def roster(space_id) do
    case space_kind(space_id) do
      :direct_message -> with_construct(space_id, nicknames(direct_message_snapshot(space_id)))
      :channel -> with_construct(space_id, nicknames(snapshot(space_id)))
      :construct -> nicknames(snapshot(space_id))
    end
  end

  # Somebody in a space's Construct is in the space: it is a room of it.
  defp with_construct(space_id, nicknames) do
    inside = space_id |> Construct.space_id() |> snapshot() |> nicknames()
    Enum.sort(Enum.uniq(nicknames ++ inside))
  end

  @doc """
  Which of the two kinds of space an id names.

  The id carries it: a private space is keyed by its two participants and says
  so in its prefix, a channel space is the channel's own name. Reading it from
  the id is what lets an address resolve to a space without a lookup, and it is
  written once here so the prefix is not spelled out at each caller.
  """
  @spec space_kind(String.t()) :: :channel | :direct_message | :construct
  def space_kind("construct:" <> _rest), do: :construct
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

  @doc """
  Say a line inside a space: it goes to the conversation the space belongs to,
  and the space draws it as a bubble over the speaker. See `Speech`.
  """
  @spec say(Speech.conversation(), String.t(), String.t()) :: :ok | {:error, String.t()}
  defdelegate say(conversation, nickname, text), to: Speech

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

  defp ensure_construct_process(construct_id, participants) do
    with {:ok, parent} <- construct_parent_spec(construct_id, participants) do
      case RetroHexChat.VirtualSpace.Registry.lookup({:construct_space, construct_id}) do
        {:ok, _pid} ->
          {:ok, :running}

        {:error, :not_found} ->
          construct_id
          |> Supervisor.start_construct_child(parent, Store.load(construct_id))
          |> started()
      end
    end
  end

  defp construct_parent_spec(construct_id, participants) do
    case Construct.parent_id(construct_id) do
      {:ok, "dm:" <> _pair = parent_id} ->
        with {:ok, participants} <- validate_direct_message_space(parent_id, participants) do
          {:ok, {:direct_message, parent_id, participants}}
        end

      {:ok, channel_name} ->
        {:ok, {:channel, channel_name}}

      :error ->
        {:error, :not_found}
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
