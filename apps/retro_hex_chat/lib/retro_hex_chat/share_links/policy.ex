defmodule RetroHexChat.ShareLinks.Policy do
  @moduledoc """
  Who may mint a share link, and who may close one.

  Minting needs a registered nickname, and that is not a formality: the row
  records who made it, revocation is asked of that person, and a link nobody is
  accountable for is one nobody can be asked about. Four surfaces mint links and
  each of them resolved a nickname before calling — asking again here is what
  makes the rule survive a fifth caller that forgets to.

  Closing is the creator's, and also **an operator of the channel the link leads
  into**. A link is an address into a room, and a room inside a channel is that
  channel's business: an operator who can close the conference itself but not
  the address people keep arriving through has half a moderation tool. The
  operator rule reaches only the kinds that name a channel — a call and a
  channel space. A P2P session and a private space have no channel to be an
  operator of, and a solo game link leads nowhere anybody needs protecting from.

  It says nothing about *following* a link. That is decision D1 of the plan and
  belongs to the surface: the link carries which room it is, never permission to
  be in it.
  """
  import Ecto.Query

  alias RetroHexChat.Channels.Membership
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.GroupCall
  alias RetroHexChat.Repo
  alias RetroHexChat.ShareLinks.Schema.Link
  alias RetroHexChat.VirtualSpace

  @doc """
  Whether `creator_id` may mint a link of `kind` at `target`.

  Every kind needs a registered nickname. Beyond that the kinds divide by who
  made the room: a call, a match and a space session are minted by whoever just
  created them, so there is nobody else to ask. A channel is the exception —
  it existed before the link and outlives it, so minting one asks the channel.
  """
  @spec can_create?(String.t(), term(), map()) :: :ok | {:error, :unauthorized}
  def can_create?(kind, creator_id, target \\ %{})

  def can_create?(kind, creator_id, target) when is_binary(kind) and is_integer(creator_id) do
    if registered?(creator_id),
      do: can_create_kind?(kind, creator_id, target),
      else: unauthorized()
  end

  def can_create?(_kind, _creator_id, _target), do: unauthorized()

  # A channel link is the one kind whose room existed before the link and will
  # outlive it, so minting one is not a side effect of having just made the
  # room. Handing out a room's address is a thing only the people in it may do,
  # and in an invite-only room it is the same decision as letting somebody in —
  # which belongs to whoever already makes that decision.
  defp can_create_kind?("channel", creator_id, %{"channel" => name}) when is_binary(name) do
    case nickname_of(creator_id) do
      nil -> unauthorized()
      nickname -> channel_sharer?(name, nickname)
    end
  end

  defp can_create_kind?("channel", _creator_id, _target), do: unauthorized()
  defp can_create_kind?(_kind, _creator_id, _target), do: :ok

  defp channel_sharer?(channel_name, nickname) do
    case Server.get_state(channel_name) do
      {:ok, state} -> member_may_share?(state, nickname)
      _unreachable -> unauthorized()
    end
  end

  defp member_may_share?(state, nickname) do
    target = String.downcase(nickname)

    entry =
      Enum.find(state.members, fn {member, _role} -> String.downcase(member) == target end)

    case {entry, get_in(state, [:modes_detail, :invite_only])} do
      {nil, _invite_only} -> unauthorized()
      {{_member, role}, true} -> if operator_rank?(role), do: :ok, else: unauthorized()
      {{_member, _role}, _open} -> :ok
    end
  end

  defp operator_rank?(role), do: Membership.rank(role) >= Membership.rank(:operator)

  defp unauthorized, do: {:error, :unauthorized}

  defp nickname_of(creator_id) do
    from(r in "registered_nicks", where: r.id == ^creator_id, select: r.nickname)
    |> Repo.one()
  end

  @doc """
  Whether `nickname` may close `link`.

  Answered against the link that exists rather than the one that was asked for,
  so a slug somebody guessed is refused on the same line as a slug they may not
  close.
  """
  @spec can_revoke?(Link.t(), term()) :: :ok | {:error, :unauthorized}
  def can_revoke?(%Link{} = link, nickname) when is_binary(nickname) and nickname != "" do
    if creator?(link, nickname) or channel_operator?(link, nickname) do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  def can_revoke?(_link, _nickname), do: {:error, :unauthorized}

  defp registered?(user_id) do
    from(r in "registered_nicks", where: r.id == ^user_id, select: true)
    |> Repo.exists?()
  end

  defp creator?(%Link{creator_id: creator_id}, nickname) do
    from(r in "registered_nicks",
      where:
        r.id == ^creator_id and fragment("lower(?)", r.nickname) == ^String.downcase(nickname),
      select: true
    )
    |> Repo.exists?()
  end

  # The channel a link leads into, when it leads into one at all.
  defp channel_operator?(link, nickname) do
    case channel_of(link) do
      nil -> false
      channel_name -> operator?(channel_name, nickname)
    end
  end

  defp channel_of(%Link{kind: "call", target: %{"room_token" => room_token}}) do
    case GroupCall.get_room(room_token) do
      {:ok, room} -> room.channel_name
      _gone -> nil
    end
  end

  defp channel_of(%Link{kind: "space", target: %{"space_id" => space_id, "mode" => "channel"}}) do
    if VirtualSpace.space_kind(space_id) == :channel, do: space_id, else: nil
  end

  defp channel_of(%Link{kind: "channel", target: %{"channel" => name}}) when is_binary(name),
    do: name

  defp channel_of(%Link{}), do: nil

  defp operator?(channel_name, nickname) do
    target = String.downcase(nickname)

    case Server.get_state(channel_name) do
      {:ok, %{members: members}} ->
        Enum.any?(members, fn {member, role} ->
          String.downcase(member) == target and
            Membership.rank(role) >= Membership.rank(:operator)
        end)

      _unreachable ->
        false
    end
  end
end
