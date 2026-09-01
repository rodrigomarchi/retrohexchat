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
  Whether `creator_id` may mint a link of `kind`.

  The kind is taken and, today, not used to distinguish: every kind asks the
  same thing of the same person. It is in the signature because the question is
  genuinely per kind — a guest pass, when it exists, is exactly a kind with a
  different answer — and because a caller that had to remember to pass it is a
  caller that has already thought about which one it is minting.
  """
  @spec can_create?(String.t(), term()) :: :ok | {:error, :unauthorized}
  def can_create?(kind, creator_id) when is_binary(kind) and is_integer(creator_id) do
    if registered?(creator_id), do: :ok, else: {:error, :unauthorized}
  end

  def can_create?(_kind, _creator_id), do: {:error, :unauthorized}

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
