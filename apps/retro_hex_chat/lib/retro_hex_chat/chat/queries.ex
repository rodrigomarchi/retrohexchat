defmodule RetroHexChat.Chat.Queries do
  @moduledoc """
  Database queries for chat messages with cursor-based pagination.
  """

  import Ecto.Query

  alias RetroHexChat.Chat.{Attachment, Message, PrivateMessage, UploadedFile}
  alias RetroHexChat.Page
  alias RetroHexChat.Repo

  @default_limit 50

  # See `list_pm_partners/2` — a bound, not a page size.
  @max_pm_partners 500

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

  @doc """
  One page of a channel's history, newest first.

  Options: `:limit` (page size) and `:cursor` (the `next_cursor` of the previous
  page). Returns a `Page`, whose `has_more` is decided by the database — apply
  presentation filters with `Page.filter/2` so they cannot truncate pagination.
  """
  @spec list_messages(String.t(), keyword()) :: Page.t()
  def list_messages(channel_name, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)

    Message
    |> where([m], m.channel_name == ^channel_name)
    |> maybe_before(Keyword.get(opts, :cursor))
    |> order_by([m], desc: m.id)
    |> preload([m], attachments: :file)
    |> limit(^Page.limit_with_lookahead(limit))
    |> Repo.all()
    |> Page.new(limit, & &1.id)
  end

  @spec get_message(integer()) :: Message.t() | nil
  def get_message(id), do: Message |> Repo.get(id) |> preload_attachments()

  @spec update_message_content(Message.t(), String.t(), DateTime.t(), keyword()) ::
          {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
  def update_message_content(message, new_content, edited_at, opts \\ []) do
    attrs =
      %{content: new_content, edited_at: edited_at}
      |> maybe_put_content_format(opts)

    message
    |> Message.edit_changeset(attrs)
    |> Repo.update()
  end

  @spec soft_delete_message(Message.t(), DateTime.t()) ::
          {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
  def soft_delete_message(message, deleted_at) do
    message
    |> Message.delete_changeset(%{deleted_at: deleted_at})
    |> Repo.update()
  end

  @spec update_reply_previews(integer(), String.t() | nil) :: {non_neg_integer(), nil}
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

  # ── PM Partners ──

  @doc """
  A nick's conversation partners, most recently active first.

  Bounded rather than paginated, and not by choice: the sort key is the time of
  the last message, so **every incoming PM reorders the list**. A keyset cursor
  over it would let a conversation slide across the page boundary between
  requests and be skipped entirely.

  The bound is high enough that reaching it means something unusual, so the page
  it returns carries `has_more` and no cursor: enough for the sidebar to say the
  list is not whole, and nothing to page with, which is the honest shape for a
  list that cannot be paged.
  """
  @spec list_pm_partners(String.t(), keyword()) :: Page.t()
  def list_pm_partners(nickname, opts \\ []) do
    limit = Keyword.get(opts, :limit, @max_pm_partners)

    sent_query =
      from pm in PrivateMessage,
        where:
          pm.sender_nickname == ^nickname and
            pm.recipient_nickname != ^nickname and
            is_nil(pm.deleted_at),
        group_by: pm.recipient_nickname,
        select: %{
          nickname: pm.recipient_nickname,
          last_message_at: max(pm.inserted_at)
        }

    received_query =
      from pm in PrivateMessage,
        where:
          pm.recipient_nickname == ^nickname and
            pm.sender_nickname != ^nickname and
            is_nil(pm.deleted_at),
        group_by: pm.sender_nickname,
        select: %{
          nickname: pm.sender_nickname,
          last_message_at: max(pm.inserted_at)
        }

    union_query =
      from s in subquery(union_all(sent_query, ^received_query)),
        group_by: s.nickname,
        select: %{
          nickname: s.nickname,
          last_message_at: max(s.last_message_at)
        },
        order_by: [desc: max(s.last_message_at)],
        limit: ^Page.limit_with_lookahead(limit)

    union_query
    |> Repo.all()
    |> Page.new(limit, fn _partner -> nil end)
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

  @doc """
  The most recent P2P invite message between the pair referencing the given
  session token — the transcript row refreshed when the session state changes.
  """
  @spec get_p2p_invite_between(String.t(), String.t(), String.t()) :: PrivateMessage.t() | nil
  def get_p2p_invite_between(nick_a, nick_b, token) do
    PrivateMessage
    |> where(
      [pm],
      (pm.sender_nickname == ^nick_a and pm.recipient_nickname == ^nick_b) or
        (pm.sender_nickname == ^nick_b and pm.recipient_nickname == ^nick_a)
    )
    |> where([pm], pm.type == "p2p_invite")
    |> where([pm], like(pm.content, ^"%#{token}%"))
    |> order_by([pm], desc: pm.id)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  One page of a conversation, newest first. Same contract as `list_messages/2`.
  """
  @spec list_private_messages(String.t(), String.t(), keyword()) :: Page.t()
  def list_private_messages(nick_a, nick_b, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)

    PrivateMessage
    |> where(
      [pm],
      (pm.sender_nickname == ^nick_a and pm.recipient_nickname == ^nick_b) or
        (pm.sender_nickname == ^nick_b and pm.recipient_nickname == ^nick_a)
    )
    |> maybe_before(Keyword.get(opts, :cursor))
    |> order_by([pm], desc: pm.id)
    |> preload([pm], attachments: :file)
    |> limit(^Page.limit_with_lookahead(limit))
    |> Repo.all()
    |> Page.new(limit, & &1.id)
  end

  @spec get_private_message(integer()) :: PrivateMessage.t() | nil
  def get_private_message(id), do: PrivateMessage |> Repo.get(id) |> preload_attachments()

  @spec update_pm_content(PrivateMessage.t(), String.t(), DateTime.t(), keyword()) ::
          {:ok, PrivateMessage.t()} | {:error, Ecto.Changeset.t()}
  def update_pm_content(pm, new_content, edited_at, opts \\ []) do
    attrs =
      %{content: new_content, edited_at: edited_at}
      |> maybe_put_content_format(opts)

    pm
    |> PrivateMessage.edit_changeset(attrs)
    |> Repo.update()
  end

  @spec soft_delete_pm(PrivateMessage.t(), DateTime.t()) ::
          {:ok, PrivateMessage.t()} | {:error, Ecto.Changeset.t()}
  def soft_delete_pm(pm, deleted_at) do
    pm
    |> PrivateMessage.delete_changeset(%{deleted_at: deleted_at})
    |> Repo.update()
  end

  @spec update_pm_reply_previews(integer(), String.t() | nil) :: {non_neg_integer(), nil}
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

  # ── Attachments ──

  @spec insert_uploaded_file(map()) :: {:ok, UploadedFile.t()} | {:error, Ecto.Changeset.t()}
  def insert_uploaded_file(attrs) do
    %UploadedFile{}
    |> UploadedFile.changeset(attrs)
    |> Repo.insert()
  end

  @spec list_orphan_uploaded_files(DateTime.t(), pos_integer()) :: [UploadedFile.t()]
  def list_orphan_uploaded_files(%DateTime{} = cutoff, limit) when limit > 0 do
    UploadedFile
    |> orphan_uploaded_files_query(cutoff)
    |> order_by([file], asc: file.inserted_at, asc: file.id)
    |> limit(^limit)
    |> Repo.all()
  end

  @spec orphan_uploaded_file_count(DateTime.t()) :: non_neg_integer()
  def orphan_uploaded_file_count(%DateTime{} = cutoff) do
    UploadedFile
    |> orphan_uploaded_files_query(cutoff)
    |> Repo.aggregate(:count, :id)
  end

  @spec lock_orphan_uploaded_file(integer(), DateTime.t()) :: UploadedFile.t() | nil
  def lock_orphan_uploaded_file(id, %DateTime{} = cutoff) when is_integer(id) do
    file =
      UploadedFile
      |> where([file], file.status in ["reserved", "uploaded"])
      |> where([file], file.inserted_at <= ^cutoff)
      |> where([file], file.id == ^id)
      |> lock("FOR UPDATE")
      |> Repo.one()

    cond do
      is_nil(file) -> nil
      attachment_exists?(file.id) -> nil
      true -> file
    end
  end

  @spec mark_uploaded_file_deleted(UploadedFile.t()) ::
          {:ok, UploadedFile.t()} | {:error, Ecto.Changeset.t()}
  def mark_uploaded_file_deleted(%UploadedFile{} = file) do
    file
    |> UploadedFile.changeset(%{status: "deleted"})
    |> Repo.update()
  end

  @spec mark_uploaded_files([integer() | String.t()], String.t()) ::
          {:ok, [UploadedFile.t()]} | {:error, :attachment_not_found}
  def mark_uploaded_files(ids, owner_nickname) do
    ids = ids |> Enum.map(&normalize_id/1) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    if ids == [] do
      {:ok, []}
    else
      now = DateTime.utc_now()

      {updated_count, _} =
        UploadedFile
        |> where([file], file.id in ^ids)
        |> where([file], file.owner_nickname == ^owner_nickname)
        |> where([file], file.status in ["reserved", "uploaded"])
        |> Repo.update_all(set: [status: "uploaded", updated_at: now])

      if updated_count == length(ids) do
        {:ok, uploaded_files_by_id(ids)}
      else
        {:error, :attachment_not_found}
      end
    end
  end

  @spec insert_attachment(map()) :: {:ok, Attachment.t()} | {:error, Ecto.Changeset.t()}
  def insert_attachment(attrs) do
    %Attachment{}
    |> Attachment.changeset(attrs)
    |> Repo.insert()
  end

  @spec get_attachment(integer() | String.t()) :: Attachment.t() | nil
  def get_attachment(id) do
    id
    |> normalize_id()
    |> case do
      nil ->
        nil

      id ->
        Attachment
        |> Repo.get(id)
        |> preload_attachment()
    end
  end

  @spec attach_to_message([integer()], String.t(), integer()) ::
          {:ok, [Attachment.t()]} | {:error, :attachment_not_found}
  def attach_to_message(ids, owner_nickname, message_id) do
    claim_attachments(ids, owner_nickname, :message_id, message_id)
  end

  @spec attach_to_private_message([integer()], String.t(), integer()) ::
          {:ok, [Attachment.t()]} | {:error, :attachment_not_found}
  def attach_to_private_message(ids, owner_nickname, private_message_id) do
    claim_attachments(ids, owner_nickname, :private_message_id, private_message_id)
  end

  @spec preload_attachments(Message.t() | PrivateMessage.t() | nil) ::
          Message.t() | PrivateMessage.t() | nil
  def preload_attachments(nil), do: nil
  def preload_attachments(message), do: Repo.preload(message, attachments: :file)

  defp claim_attachments([], _owner_nickname, _field, _id), do: {:ok, []}

  defp claim_attachments(ids, owner_nickname, field, id) do
    ids = ids |> Enum.map(&normalize_id/1) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    if ids == [] do
      {:error, :attachment_not_found}
    else
      now = DateTime.utc_now()

      {updated_count, _} =
        UploadedFile
        |> where([file], file.id in ^ids)
        |> where([file], file.owner_nickname == ^owner_nickname)
        |> where([file], file.status == "uploaded")
        |> Repo.update_all(set: [status: "attached", updated_at: now])

      if updated_count == length(ids) do
        ids
        |> uploaded_files_by_id()
        |> insert_attachment_links(field, id)
      else
        {:error, :attachment_not_found}
      end
    end
  end

  defp uploaded_files_by_id(ids) do
    files =
      UploadedFile
      |> where([file], file.id in ^ids)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    Enum.map(ids, &Map.fetch!(files, &1))
  end

  defp insert_attachment_links(files, field, id) do
    files
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {file, position}, {:ok, attachments} ->
      attrs =
        %{
          file_id: file.id,
          display_filename: file.original_filename,
          position: position
        }
        |> Map.put(field, id)

      case insert_attachment(attrs) do
        {:ok, attachment} ->
          {:cont, {:ok, [Repo.preload(attachment, :file) | attachments]}}

        {:error, _changeset} ->
          {:halt, {:error, :attachment_not_found}}
      end
    end)
    |> case do
      {:ok, attachments} -> {:ok, Enum.reverse(attachments)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp orphan_uploaded_files_query(queryable, cutoff) do
    queryable
    |> where([file], file.status in ["reserved", "uploaded"])
    |> where([file], file.inserted_at <= ^cutoff)
    |> join(:left, [file], attachment in Attachment, on: attachment.file_id == file.id)
    |> where([_file, attachment], is_nil(attachment.id))
  end

  defp attachment_exists?(file_id) do
    Attachment
    |> where([attachment], attachment.file_id == ^file_id)
    |> Repo.exists?()
  end

  defp preload_attachment(nil), do: nil

  defp preload_attachment(attachment) do
    Repo.preload(attachment, [:file, :message, :private_message])
  end

  defp normalize_id(id) when is_integer(id), do: id

  defp normalize_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp normalize_id(_id), do: nil

  @spec bulk_delete_messages(String.t()) :: non_neg_integer()
  def bulk_delete_messages(channel_name) do
    {count, _} =
      from(m in Message, where: m.channel_name == ^channel_name)
      |> Repo.delete_all()

    count
  end

  @spec bulk_delete_messages(String.t(), String.t()) :: non_neg_integer()
  def bulk_delete_messages(channel_name, author_nickname) do
    {count, _} =
      from(m in Message,
        where: m.channel_name == ^channel_name and m.author_nickname == ^author_nickname
      )
      |> Repo.delete_all()

    count
  end

  defp maybe_before(query, nil), do: query

  defp maybe_before(query, before_id) do
    where(query, [m], m.id < ^before_id)
  end

  defp maybe_put_content_format(attrs, opts) do
    case Keyword.fetch(opts, :content_format) do
      {:ok, content_format} -> Map.put(attrs, :content_format, content_format)
      :error -> attrs
    end
  end
end
