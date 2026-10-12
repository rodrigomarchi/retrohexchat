defmodule RetroHexChat.VirtualSpace.Construct.Panels do
  @moduledoc """
  What the pieces that open a panel show: a board the channel's topic and its
  pinned lines, a screen the newest picture posted in the conversation, a sign
  its line and whether the person looking may rewrite it.

  The runtime only says which panel a piece opened (`Construct.Layout.use/5`);
  filling it means reading the conversation, which is this module's job and
  never the runtime's — a world stepping avatars is no place for a query.
  """

  alias RetroHexChat.Channels.Pins
  alias RetroHexChat.Channels.Server, as: ChannelServer
  alias RetroHexChat.Chat.Attachments
  alias RetroHexChat.Chat.Content
  alias RetroHexChat.Nickname
  alias RetroHexChat.VirtualSpace.Speech

  @board_pins 5

  @typedoc "A panel as the runtime opened it, before it is filled in."
  @type modal :: %{required(:kind) => String.t(), optional(atom()) => term()}

  @doc """
  Fill a panel in for `nickname`, who opened it in a Construct of
  `conversation`. A kind with nothing to read is returned as it came.
  """
  @spec fill(modal(), Speech.conversation(), String.t() | nil) :: modal()
  def fill(%{kind: "board"} = modal, {:channel, channel_name}, _nickname),
    do: Map.merge(modal, board(channel_name))

  def fill(%{kind: "screen"} = modal, conversation, _nickname),
    do: Map.put(modal, :image, Attachments.latest_image(conversation))

  def fill(%{kind: "sign"} = modal, conversation, nickname) do
    Map.put(modal, :can_edit, may_write?(conversation, nickname, Map.get(modal, :placed_by)))
  end

  def fill(modal, _conversation, _nickname), do: modal

  @doc """
  Whether `nickname` may speak for the conversation on its signs: an operator
  or the owner of a channel, and either person of a private conversation.
  """
  @spec moderator?(Speech.conversation(), String.t()) :: boolean()
  def moderator?({:direct_message, _participants}, _nickname), do: true

  def moderator?({:channel, channel_name}, nickname) do
    case ChannelServer.get_state(channel_name) do
      {:ok, %{members: members}} ->
        key = Nickname.key(nickname)

        Enum.any?(members, fn {member, role} ->
          role in [:owner, :operator] and Nickname.key(member) == key
        end)

      {:error, _reason} ->
        false
    end
  end

  defp may_write?(_conversation, nil, _placed_by), do: false

  defp may_write?(conversation, nickname, placed_by) do
    (is_binary(placed_by) and Nickname.key(placed_by) == Nickname.key(nickname)) or
      moderator?(conversation, nickname)
  end

  defp board(channel_name) do
    topic =
      case ChannelServer.get_state(channel_name) do
        {:ok, %{topic: topic}} when is_binary(topic) and topic != "" -> topic
        _no_topic -> nil
      end

    pins =
      channel_name
      |> Pins.list(limit: @board_pins)
      |> Map.fetch!(:items)
      |> Enum.map(fn pin ->
        %{
          author: pin.author_nickname,
          text: Content.strip_formatting(pin.content || "", pin.content_format)
        }
      end)

    %{topic: topic, pins: pins}
  end
end
