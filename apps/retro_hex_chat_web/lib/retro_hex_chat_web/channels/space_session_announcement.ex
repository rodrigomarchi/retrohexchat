defmodule RetroHexChatWeb.SpaceSessionAnnouncement do
  @moduledoc """
  Writing a gathering into the conversation it belongs to.

  A space is a place and its address always works, so this line is not the only
  way in — the entry beside the tabs is always a door. What the line is for is
  the two things a conversation cannot get from a door: it says something is
  happening in here right now, and once everybody has gone home it is the record
  of how long they stayed and how many came.

  It is written from the web layer because a card is an address and an address
  has a host. The domain opened the gathering and knows nothing about origins.

  **Only a registered nickname announces one.** A shared address carries who is
  accountable for it, which is the rule `ShareLinks` enforces at its own door;
  a guest still walks into the space, and the space is still entered from the
  conversation's own entry. There is simply no card, because there is nobody to
  put on it.
  """

  use Gettext, backend: RetroHexChatWeb.Gettext

  require Logger

  alias RetroHexChat.Chat.Service, as: ChatService
  alias RetroHexChat.ShareLinks
  alias RetroHexChatWeb.ShareLinkRef

  @typedoc "The space that was just opened, as the channel that opened it knows it."
  @type opening :: %{
          space_id: String.t(),
          mode: String.t(),
          token: String.t(),
          nickname: String.t(),
          user_id: integer() | nil,
          participants: [String.t()]
        }

  @doc """
  Posts the card for a gathering that has just started.

  Best effort by design: the person is already standing in the space by the time
  this runs, and a conversation that did not get its line is a smaller failure
  than a join that came apart over one.
  """
  @spec announce(opening()) :: :ok
  def announce(%{user_id: user_id} = opening) when is_integer(user_id) do
    case mint(opening) do
      {:ok, link} -> post(opening, ShareLinkRef.url(link.slug))
      {:error, reason} -> Logger.warning("Space session link failed: #{inspect(reason)}")
    end

    :ok
  end

  def announce(_opening), do: :ok

  defp mint(opening) do
    ShareLinks.create(%{
      kind: "space",
      target: %{
        "space_id" => opening.space_id,
        "mode" => opening.mode,
        "session_token" => opening.token
      },
      creator_id: opening.user_id,
      creator_nick: opening.nickname
    })
  end

  # A channel hears it as the channel; the two people in a private space hear it
  # as a line in the conversation they already have. Neither is a message
  # somebody typed, so both carry the system type — and the card is drawn from
  # the address in it either way.
  defp post(%{mode: "direct_message"} = opening, url) do
    case peer(opening) do
      nil ->
        :ok

      peer ->
        ChatService.send_private_message(opening.nickname, peer, content(opening, url), "system")
    end
  end

  defp post(opening, url) do
    ChatService.send_system_message(opening.space_id, content(opening, url))
  end

  defp content(opening, url) do
    dgettext("chat", "%{nickname} opened the space — %{url}",
      nickname: opening.nickname,
      url: url
    )
  end

  defp peer(%{nickname: nickname, participants: participants}) when is_list(participants) do
    normalized = String.downcase(nickname)
    Enum.find(participants, &(String.downcase(&1) != normalized))
  end

  defp peer(_opening), do: nil
end
