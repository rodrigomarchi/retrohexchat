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

  @spec insert_reply_message(map()) :: {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
  def insert_reply_message(attrs) do
    %Message{}
    |> Message.reply_changeset(attrs)
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

  @spec get_message(integer()) :: Message.t() | nil
  def get_message(id), do: Repo.get(Message, id)

  @spec update_message_content(Message.t(), String.t(), DateTime.t()) ::
          {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
  def update_message_content(message, new_content, edited_at) do
    message
    |> Message.edit_changeset(%{content: new_content, edited_at: edited_at})
    |> Repo.update()
  end

  @spec soft_delete_message(Message.t(), DateTime.t()) ::
          {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
  def soft_delete_message(message, deleted_at) do
    message
    |> Message.delete_changeset(%{deleted_at: deleted_at})
    |> Repo.update()
  end

  @spec update_reply_previews(integer(), String.t()) :: {non_neg_integer(), nil}
  def update_reply_previews(parent_id, new_preview) do
    Message
    |> where([m], m.reply_to_id == ^parent_id)
    |> Repo.update_all(set: [reply_to_preview: new_preview])
  end

  @spec get_reply_ids(integer()) :: [integer()]
  def get_reply_ids(parent_id) do
    Message
    |> where([m], m.reply_to_id == ^parent_id)
    |> select([m], m.id)
    |> Repo.all()
  end

  # ── Private Messages ──

  @spec insert_private_message(map()) :: {:ok, PrivateMessage.t()} | {:error, Ecto.Changeset.t()}
  def insert_private_message(attrs) do
    %PrivateMessage{}
    |> PrivateMessage.changeset(attrs)
    |> Repo.insert()
  end

  @spec insert_reply_pm(map()) :: {:ok, PrivateMessage.t()} | {:error, Ecto.Changeset.t()}
  def insert_reply_pm(attrs) do
    %PrivateMessage{}
    |> PrivateMessage.reply_changeset(attrs)
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

  @spec get_private_message(integer()) :: PrivateMessage.t() | nil
  def get_private_message(id), do: Repo.get(PrivateMessage, id)

  @spec update_pm_content(PrivateMessage.t(), String.t(), DateTime.t()) ::
          {:ok, PrivateMessage.t()} | {:error, Ecto.Changeset.t()}
  def update_pm_content(pm, new_content, edited_at) do
    pm
    |> PrivateMessage.edit_changeset(%{content: new_content, edited_at: edited_at})
    |> Repo.update()
  end

  @spec soft_delete_pm(PrivateMessage.t(), DateTime.t()) ::
          {:ok, PrivateMessage.t()} | {:error, Ecto.Changeset.t()}
  def soft_delete_pm(pm, deleted_at) do
    pm
    |> PrivateMessage.delete_changeset(%{deleted_at: deleted_at})
    |> Repo.update()
  end

  @spec update_pm_reply_previews(integer(), String.t()) :: {non_neg_integer(), nil}
  def update_pm_reply_previews(parent_id, new_preview) do
    PrivateMessage
    |> where([pm], pm.reply_to_id == ^parent_id)
    |> Repo.update_all(set: [reply_to_preview: new_preview])
  end

  @spec get_pm_reply_ids(integer()) :: [integer()]
  def get_pm_reply_ids(parent_id) do
    PrivateMessage
    |> where([pm], pm.reply_to_id == ^parent_id)
    |> select([pm], pm.id)
    |> Repo.all()
  end

  @spec last_own_message(String.t(), String.t()) :: Message.t() | nil
  def last_own_message(nickname, channel_name) do
    Message
    |> where([m], m.author_nickname == ^nickname and m.channel_name == ^channel_name)
    |> where([m], is_nil(m.deleted_at))
    |> where([m], m.type == "message")
    |> order_by([m], desc: m.id)
    |> limit(1)
    |> Repo.one()
  end

  @spec last_own_pm(String.t(), String.t()) :: PrivateMessage.t() | nil
  def last_own_pm(nickname, other_nick) do
    PrivateMessage
    |> where([pm], pm.sender_nickname == ^nickname)
    |> where(
      [pm],
      (pm.sender_nickname == ^nickname and pm.recipient_nickname == ^other_nick) or
        (pm.sender_nickname == ^other_nick and pm.recipient_nickname == ^nickname)
    )
    |> where([pm], is_nil(pm.deleted_at))
    |> where([pm], pm.type == "message")
    |> order_by([pm], desc: pm.id)
    |> limit(1)
    |> Repo.one()
  end

  defp maybe_before(query, nil), do: query

  defp maybe_before(query, before_id) do
    where(query, [m], m.id < ^before_id)
  end
end
