defmodule RetroHexChat.Chat.Roster do
  @moduledoc """
  Who is in the conversation somebody is looking at.

  A channel and a private conversation are the same idea addressed two ways
  (`RetroHexChat.Chat.Conversation` says where a message goes; this says who is
  there), and the screen that lists them is one list. What differs is only where
  the answer comes from: a channel keeps its membership in its own process, a
  private conversation has no process and no join at all — its two people are
  whoever is addressing whom, and the only live fact about them is presence.

  Asking that question in one place is what keeps the two kinds from drifting.
  While it lived in the channel loader, a private conversation had no answer, so
  the screen kept showing the roster of the last channel visited — a list that
  belonged to a conversation nobody was looking at, feeding the user list, the
  window title's count and the composer's tab-complete alike.

  ## Ordering

  Members carry a `rank`, and the display order is `{rank, nickname}`. A channel
  ranks by role, so the sections come out owner-first. A private conversation
  ranks the other person ahead of you: the conversation is about them, and there
  are only ever the two of you to order.

  ## Degrading

  A channel process that cannot be reached yields an empty roster rather than
  raising. A roster is being described, not a permission granted, and an empty
  user list is a survivable screen — a crashed render is not.
  """

  require Logger

  alias RetroHexChat.Bots
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Topics

  @typedoc "Which kind of conversation the roster describes."
  @type kind :: :channel | :private

  @typedoc "A conversation to describe: a channel by name, or the two people in a query."
  @type target :: {:channel, String.t()} | {:private, String.t(), String.t()}

  @typedoc "One person in the conversation, as the user list renders them."
  @type member :: %{
          nickname: String.t(),
          role: atom(),
          away: boolean(),
          away_message: String.t() | nil,
          muted: boolean(),
          online: boolean(),
          rank: non_neg_integer()
        }

  @type t :: %__MODULE__{
          kind: kind(),
          label: String.t() | nil,
          members: [member()],
          topic: String.t() | nil,
          modes: String.t() | nil
        }

  defstruct kind: :channel, label: nil, members: [], topic: nil, modes: nil

  @role_ranks %{owner: 0, operator: 1, half_operator: 2, voiced: 3, regular: 4, bot: 5}

  @doc """
  The roster of `target`, with the conversation's own facts alongside it.

  `topic` and `modes` only exist for a channel, and they come back from the same
  read as the membership — the user list and the topic bar describe one
  conversation and should never be a state apart.
  """
  @spec of(target()) :: t()
  def of({:channel, name}) when is_binary(name) do
    case Server.get_state(name) do
      {:ok, state} ->
        %__MODULE__{
          kind: :channel,
          label: name,
          members: channel_members(name, state),
          topic: state.topic,
          modes: state.modes
        }

      {:error, reason} ->
        # An empty user list and a channel that could not be found look
        # identical on screen, and only one of them is normal. Say which, or the
        # next person debugging an empty list has nothing to go on.
        Logger.warning("Roster for #{name} left empty: #{inspect(reason)}")
        %__MODULE__{kind: :channel, label: name}
    end
  end

  def of({:private, viewer, peer}) when is_binary(viewer) and is_binary(peer) do
    %__MODULE__{
      kind: :private,
      label: peer,
      members: [private_member(peer, 0), private_member(viewer, 1)]
    }
  end

  @doc "The display rank of a channel role — the order the user list groups by."
  @spec role_rank(atom()) :: non_neg_integer()
  def role_rank(role), do: Map.get(@role_ranks, role, @role_ranks.regular)

  @doc """
  A channel member as a join event describes one: a nickname and a role.

  The same shape the full read produces, so a roster assembled from deltas and
  one loaded from the channel process cannot disagree about what a member is.
  """
  @spec channel_member(String.t(), atom()) :: member()
  def channel_member(nickname, role) do
    %{
      nickname: nickname,
      role: role,
      away: false,
      away_message: nil,
      muted: false,
      online: true,
      rank: role_rank(role)
    }
  end

  @doc """
  Gives `member` a new channel role.

  Role and rank move together, or a promoted operator draws in the operator
  section while still sorting where they used to be. Every place that reacts to
  a mode change goes through here rather than writing the role field directly.
  """
  @spec put_role(member(), atom()) :: member()
  def put_role(member, role) do
    %{member | role: role, rank: role_rank(role)}
  end

  @spec channel_members(String.t(), map()) :: [member()]
  defp channel_members(name, state) do
    presence = channel_presence(name)
    muted = MapSet.new(Map.get(state, :channel_mutes, []))

    Enum.map(state.members, fn {nickname, role} ->
      meta = Map.get(presence, String.downcase(nickname), %{})

      %{
        nickname: nickname,
        role: role,
        away: Map.get(meta, :away, false),
        away_message: Map.get(meta, :away_message),
        muted: MapSet.member?(muted, nickname),
        online: true,
        rank: role_rank(role)
      }
    end)
  end

  @spec channel_presence(String.t()) :: %{optional(String.t()) => map()}
  defp channel_presence(name) do
    name
    |> Topics.channel()
    |> Tracker.list_users()
    |> Map.new(fn user -> {String.downcase(user.nickname), user} end)
  end

  # One keyed presence read per person, not a scan of the server-wide topic:
  # a private roster is looked up on every conversation switch, and that topic
  # holds everybody connected.
  @spec private_member(String.t(), non_neg_integer()) :: member()
  defp private_member(nickname, rank) do
    meta = Tracker.meta(Topics.presence(), nickname)

    %{
      nickname: nickname,
      role: if(Bots.Registry.bot?(nickname), do: :bot, else: :regular),
      away: (meta && Map.get(meta, :away, false)) || false,
      away_message: meta && Map.get(meta, :away_message),
      muted: false,
      online: meta != nil,
      rank: rank
    }
  end
end
