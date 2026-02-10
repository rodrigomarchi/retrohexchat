defmodule RetroHexChat.Chat.Queries do
  @moduledoc """
  Database queries for chat messages with cursor-based pagination.
  """

  import Ecto.Query

  alias RetroHexChat.Chat.{Message, PrivateMessage}
  alias RetroHexChat.Repo

  @default_limit 50

  @spec insert_message(map()) :: {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
  def insert_message(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @spec list_messages(String.t(), keyword()) :: [Message.t()]
  def list_messages(channel_name, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    before_id = Keyword.get(opts, :before_id)

    Message
    |> where([m], m.channel_name == ^channel_name)
    |> maybe_before(before_id)
    |> order_by([m], desc: m.id)
    |> limit(^limit)
    |> Repo.all()
  end

  @spec insert_private_message(map()) :: {:ok, PrivateMessage.t()} | {:error, Ecto.Changeset.t()}
  def insert_private_message(attrs) do
    %PrivateMessage{}
    |> PrivateMessage.changeset(attrs)
    |> Repo.insert()
  end

  @spec list_private_messages(String.t(), String.t(), keyword()) :: [PrivateMessage.t()]
  def list_private_messages(nick_a, nick_b, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    before_id = Keyword.get(opts, :before_id)

    PrivateMessage
    |> where(
      [pm],
      fragment("least(?, ?)", pm.sender_nickname, pm.recipient_nickname) ==
        ^Enum.min([nick_a, nick_b])
    )
    |> where(
      [pm],
      fragment("greatest(?, ?)", pm.sender_nickname, pm.recipient_nickname) ==
        ^Enum.max([nick_a, nick_b])
    )
    |> maybe_before(before_id)
    |> order_by([pm], desc: pm.id)
    |> limit(^limit)
    |> Repo.all()
  end

  defp maybe_before(query, nil), do: query

  defp maybe_before(query, before_id) do
    where(query, [m], m.id < ^before_id)
  end
end
