defmodule RetroHexChat.Chat.Queries do
  @moduledoc """
  Database queries for chat messages with cursor-based pagination.
  """

  import Ecto.Query
  import RetroHexChat.Nickname, only: [matches: 2]

  alias RetroHexChat.Chat.{Attachment, Message, PrivateMessage, UploadedFile}
  alias RetroHexChat.Nickname
  alias RetroHexChat.Page
  alias RetroHexChat.Repo

  # What a public preview is allowed to show: people talking, and nothing the
  # room said about itself.
  @preview_types ~w(message action)
  @default_preview_limit 5
  @max_preview_limit 20
  @preview_line_length 140

  @default_limit 50

  # A thread is a handful of lines, not a channel's history.
  @default_thread_limit 25

  # See `list_pm_partners/2` — a bound, not a page size.
  @max_pm_partners 500

  @typedoc "A message somebody wrote, in whichever kind of conversation."
  @type message :: Message.t() | PrivateMessage.t()

  @typedoc "Where a conversation's lines live: a channel, or the pair in a PM."
  @type conversation :: {:channel, String.t()} | {:pm, String.t(), String.t()}

  # ── Any message ──
  #
  # Written once because the two tables answer these identically: what changes
  # is the schema the row belongs to, and the row itself says which that is.

  @doc "Rewrites a message's body, keeping or replacing its format."
  @spec update_content(message(), String.t(), DateTime.t(), keyword()) ::
          {:ok, message()} | {:error, Ecto.Changeset.t()}
  def update_content(message, new_content, edited_at, opts \\ []) do
    attrs =
      %{content: new_content, edited_at: edited_at}
      |> maybe_put_content_format(opts)

    message
    |> edit_changeset(attrs)
    |> Repo.update()
  end

  @doc "Marks a message deleted without removing it."
  @spec soft_delete(message(), DateTime.t()) :: {:ok, message()} | {:error, Ecto.Changeset.t()}
  def soft_delete(message, deleted_at) do
    message
    |> delete_changeset(%{deleted_at: deleted_at})
    |> Repo.update()
  end

  @doc "The ids of the messages quoting this one."
  @spec reply_ids(message()) :: [integer()]
  def reply_ids(parent) do
    parent
    |> replies_to()
    |> select([r], r.id)
    |> Repo.all()
  end

  @doc """
  One page of the thread hanging off `root`, oldest first.

  A thread is read forwards — it is a conversation, and the line that started
  it is already on screen above. So the cursor walks the other way from every
  other list here (`id > cursor`), which `Page` does not care about: the cursor
  is whatever the last row of the page was.

  Every reply points straight at its root (`Chat.Replies`), so this stays one
  flat query however deep the disagreement went.
  """
  @spec thread_for(message(), keyword()) :: Page.t()
  def thread_for(root, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_thread_limit)

    root
    |> replies_to()
    |> maybe_after(Keyword.get(opts, :cursor))
    |> order_by(asc: :id)
    |> preload(attachments: :file)
    |> limit(^Page.limit_with_lookahead(limit))
    |> Repo.all()
    |> Page.new(limit, & &1.id)
  end

  @doc """
  How many replies each of these messages has, in one query.

  Asked for a whole page of rows at once for the same reason the reactions are:
  a page is fifty lines, and a counter that costs a query per line costs fifty.
  A message nobody answered is absent rather than zero — the row draws nothing
  at all for it, which is not the same as drawing a nought.

  A reply is never a root, so an id that answers something answers nothing here.
  """
  @spec thread_counts_for_many(:message | :private_message, [integer()]) ::
          %{integer() => non_neg_integer()}
  def thread_counts_for_many(_kind, []), do: %{}

  def thread_counts_for_many(kind, ids) do
    kind
    |> thread_schema()
    |> where([m], m.reply_to_id in ^ids)
    |> group_by([m], m.reply_to_id)
    |> select([m], {m.reply_to_id, count(m.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc "Rewrites the quote every reply to this message carries."
  @spec update_reply_previews(message(), String.t() | nil) :: {non_neg_integer(), nil}
  def update_reply_previews(parent, new_preview) do
    parent
    |> replies_to()
    |> Repo.update_all(set: [reply_to_preview: new_preview])
  end

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
    Message
    |> where([m], m.channel_name == ^channel_name)
    |> page(opts)
  end

  @doc """
  The last few things people said in a channel, oldest first.

  Written for the public card a shared link resolves to, which is read by
  somebody who is not in the channel and may not be in the product. That is why
  it is not `list_messages/2` with a small limit: it carries the **visible**
  text rather than the source, truncated, and it leaves out everything that is
  not a person talking. A join notice, a service reply and a message its author
  deleted are all things the room said about itself, and none of them belong on
  a page the room cannot see.

  Not paginated, on purpose. A preview has a size and there is no next page of
  it.
  """
  @spec preview_messages(String.t(), keyword()) :: [
          %{author: String.t(), content: String.t(), at: DateTime.t()}
        ]
  def preview_messages(channel_name, opts \\ []) do
    limit = opts |> Keyword.get(:limit, @default_preview_limit) |> min(@max_preview_limit)

    Message
    |> where([m], m.channel_name == ^channel_name)
    |> where([m], m.type in ^@preview_types)
    |> where([m], is_nil(m.deleted_at))
    |> order_by([m], desc: m.id)
    |> limit(^limit)
    |> select([m], %{
      author: m.author_nickname,
      content: fragment("coalesce(?, ?)", m.plain_content, m.content),
      at: m.inserted_at
    })
    |> Repo.all()
    |> Enum.reverse()
    |> Enum.map(&truncate_preview/1)
  end

  defp truncate_preview(%{content: content} = line) do
    if String.length(content) > @preview_line_length do
      %{line | content: String.slice(content, 0, @preview_line_length - 1) <> "…"}
    else
      line
    end
  end

  @spec get_message(integer()) :: Message.t() | nil
  def get_message(id), do: Message |> Repo.get(id) |> preload_attachments()

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
          matches(pm.sender_nickname, nickname) and
            not matches(pm.recipient_nickname, nickname) and
            is_nil(pm.deleted_at),
        group_by: pm.recipient_nickname,
        select: %{
          nickname: pm.recipient_nickname,
          last_message_at: max(pm.inserted_at)
        }

    received_query =
      from pm in PrivateMessage,
        where:
          matches(pm.recipient_nickname, nickname) and
            not matches(pm.sender_nickname, nickname) and
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
        }

    # One partner per person: spellings of one nickname are folded together,
    # and the partner is shown as they spelled it most recently.
    union_query
    |> Repo.all()
    |> Enum.group_by(&Nickname.key(&1.nickname))
    |> Enum.map(fn {_key, spellings} ->
      Enum.max_by(spellings, & &1.last_message_at, DateTime)
    end)
    |> Enum.sort_by(& &1.last_message_at, {:desc, DateTime})
    |> Enum.take(Page.limit_with_lookahead(limit))
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
    |> between(nick_a, nick_b)
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
    PrivateMessage
    |> between(nick_a, nick_b)
    |> page(opts)
  end

  @spec get_private_message(integer()) :: PrivateMessage.t() | nil
  def get_private_message(id), do: PrivateMessage |> Repo.get(id) |> preload_attachments()

  @doc """
  Whether the newest line of a conversation already carries `fragment`.

  Asked by the controls that put a room's card into the conversation. Pressing
  one of those always writes the card again, because the reason somebody presses
  it a second time is that they cannot find the first — and being told the card
  exists somewhere above is not an answer to that. The one press that must not
  write is the press where the card is *already* the line at the bottom: there is
  nothing to bring down, and a second identical card is the only thing a double
  click could produce.

  One row, newest first, content only. A message its author deleted is not a
  card anybody can read, so it does not count as one being there.
  """
  @spec newest_line_carries?(conversation(), String.t()) :: boolean()
  def newest_line_carries?(conversation, fragment)
      when is_binary(fragment) and fragment != "" do
    case newest_line(conversation) do
      content when is_binary(content) -> String.contains?(content, fragment)
      _nothing -> false
    end
  end

  def newest_line_carries?(_conversation, _fragment), do: false

  defp newest_line({:channel, channel_name}) do
    Message
    |> where([m], m.channel_name == ^channel_name)
    |> where([m], is_nil(m.deleted_at))
    |> order_by([m], desc: m.id)
    |> limit(1)
    |> select([m], m.content)
    |> Repo.one()
  end

  defp newest_line({:pm, nick_a, nick_b}) do
    PrivateMessage
    |> between(nick_a, nick_b)
    |> where([pm], is_nil(pm.deleted_at))
    |> order_by([pm], desc: pm.id)
    |> limit(1)
    |> select([pm], pm.content)
    |> Repo.one()
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
    |> between(nickname, other_nick)
    |> where([pm], matches(pm.sender_nickname, nickname))
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

  @doc "One uploaded file by id, or nil."
  @spec get_uploaded_file(integer()) :: UploadedFile.t() | nil
  def get_uploaded_file(id), do: Repo.get(UploadedFile, id)

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

  @doc "Claims uploaded files for a message, whichever kind of message it is."
  @spec attach(message(), [integer()], String.t()) ::
          {:ok, [Attachment.t()]} | {:error, :attachment_not_found}
  def attach(%Message{id: id}, ids, owner_nickname) do
    claim_attachments(ids, owner_nickname, :message_id, id)
  end

  def attach(%PrivateMessage{id: id}, ids, owner_nickname) do
    claim_attachments(ids, owner_nickname, :private_message_id, id)
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

  # One page of a conversation, newest first, whichever kind it is: the scope is
  # the caller's `where`, and everything after it — the cursor, the order, the
  # preload, the lookahead that decides `has_more` — is the same question asked
  # of a different table.
  defp page(query, opts) do
    limit = Keyword.get(opts, :limit, @default_limit)

    query
    |> maybe_before(Keyword.get(opts, :cursor))
    |> order_by(desc: :id)
    |> preload(attachments: :file)
    |> limit(^Page.limit_with_lookahead(limit))
    |> Repo.all()
    |> Page.new(limit, & &1.id)
  end

  # A private conversation is an unordered pair, so every query about one asks
  # for both directions.
  defp between(query, nick_a, nick_b) do
    where(
      query,
      [pm],
      (matches(pm.sender_nickname, nick_a) and matches(pm.recipient_nickname, nick_b)) or
        (matches(pm.sender_nickname, nick_b) and matches(pm.recipient_nickname, nick_a))
    )
  end

  defp replies_to(%Message{id: id}), do: where(Message, [m], m.reply_to_id == ^id)
  defp replies_to(%PrivateMessage{id: id}), do: where(PrivateMessage, [pm], pm.reply_to_id == ^id)

  defp thread_schema(:message), do: Message
  defp thread_schema(:private_message), do: PrivateMessage

  defp edit_changeset(%Message{} = message, attrs), do: Message.edit_changeset(message, attrs)
  defp edit_changeset(%PrivateMessage{} = pm, attrs), do: PrivateMessage.edit_changeset(pm, attrs)

  defp delete_changeset(%Message{} = message, attrs), do: Message.delete_changeset(message, attrs)

  defp delete_changeset(%PrivateMessage{} = pm, attrs),
    do: PrivateMessage.delete_changeset(pm, attrs)

  defp maybe_before(query, nil), do: query

  defp maybe_before(query, before_id) do
    where(query, [m], m.id < ^before_id)
  end

  defp maybe_after(query, nil), do: query

  defp maybe_after(query, after_id) do
    where(query, [m], m.id > ^after_id)
  end

  defp maybe_put_content_format(attrs, opts) do
    case Keyword.fetch(opts, :content_format) do
      {:ok, content_format} -> Map.put(attrs, :content_format, content_format)
      :error -> attrs
    end
  end
end
