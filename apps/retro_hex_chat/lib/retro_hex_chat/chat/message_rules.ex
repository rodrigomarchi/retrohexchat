defmodule RetroHexChat.Chat.MessageRules do
  @moduledoc """
  What makes a written message valid, whichever conversation it was written in.

  A channel message and a private message are the same thing addressed
  differently: the same content, in one of the same formats, edited and deleted
  under the same rules. Only the address differs — a channel names a room, a
  private message names two people — and the set of types that address can carry.

  A schema declares that difference as data and hands it here, so the rules
  themselves exist once. Content that must not be blank, a `plain_content` that
  is derived and never trusted from the caller, a reply that must name what it
  quotes: a change to any of those lands on both kinds or on neither.

  The schemas keep their own `schema` block. Ecto needs it declared literally,
  and the fields of a table are the one thing a reader should be able to see
  without following an indirection.
  """

  import Ecto.Changeset

  alias RetroHexChat.Chat.Content

  @content_formats ~w(irc markdown plain)

  @typedoc """
  A schema's declaration of what it addresses and what it may carry.

  * `:scope` — the addressing columns with their length limits, in cast order
  * `:types` — the message types this kind of conversation can hold
  * `:content_format_constraint` — the database check backing the format column
  """
  @type rules :: %{
          scope: keyword(pos_integer()),
          types: [String.t()],
          content_format_constraint: atom()
        }

  @content_fields [:content, :content_format, :type, :allow_blank_content]

  @doc "A message as first written."
  @spec changeset(Ecto.Schema.t() | Ecto.Changeset.t(), map(), rules()) :: Ecto.Changeset.t()
  def changeset(message, attrs, rules) do
    build(message, attrs, rules, [])
  end

  @doc """
  A message as first written, quoting another.

  The reply columns are cast only here, so a plain write cannot smuggle a quote
  in through unexpected attributes.
  """
  @spec reply_changeset(Ecto.Schema.t() | Ecto.Changeset.t(), map(), rules()) ::
          Ecto.Changeset.t()
  def reply_changeset(message, attrs, rules) do
    message
    |> build(attrs, rules, [:reply_to_id, :reply_to_author, :reply_to_preview])
    |> validate_reply_fields()
  end

  @doc """
  A message being rewritten by its author.

  The address cannot change: editing a message never moves it to another
  conversation, so those columns are not cast at all.
  """
  @spec edit_changeset(Ecto.Schema.t() | Ecto.Changeset.t(), map(), rules()) ::
          Ecto.Changeset.t()
  def edit_changeset(message, attrs, rules) do
    message
    |> cast(attrs, [:content, :content_format, :edited_at])
    |> validate_required([:content, :content_format, :edited_at])
    |> validate_inclusion(:content_format, @content_formats)
    |> put_plain_content()
    |> check_constraint(:content_format, name: rules.content_format_constraint)
  end

  @doc """
  A message being withdrawn.

  Deleting stamps a moment rather than removing the row, so a reply that quotes
  it still has something to point at.
  """
  @spec delete_changeset(Ecto.Schema.t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def delete_changeset(message, attrs) do
    message
    |> cast(attrs, [:deleted_at])
    |> validate_required([:deleted_at])
  end

  defp build(message, attrs, rules, extra_fields) do
    scope_fields = Keyword.keys(rules.scope)

    message
    |> cast(attrs, scope_fields ++ @content_fields ++ extra_fields, empty_values: [])
    |> validate_required(scope_fields ++ [:content_format])
    |> validate_content_required()
    |> validate_scope_lengths(rules.scope)
    |> validate_inclusion(:content_format, @content_formats)
    |> validate_inclusion(:type, rules.types)
    |> put_plain_content()
    |> check_constraint(:content_format, name: rules.content_format_constraint)
  end

  defp validate_scope_lengths(changeset, scope) do
    Enum.reduce(scope, changeset, fn {field, max}, acc ->
      validate_length(acc, field, max: max)
    end)
  end

  defp validate_reply_fields(changeset) do
    if get_change(changeset, :reply_to_id) do
      changeset
      |> validate_required([:reply_to_author, :reply_to_preview])
      |> validate_length(:reply_to_author, max: 16)
      |> validate_length(:reply_to_preview, max: 100)
    else
      changeset
    end
  end

  # A message may be deliberately empty — an attachment carries it instead — but
  # only when the writer said so, and never by omitting the field altogether.
  defp validate_content_required(changeset) do
    if get_field(changeset, :allow_blank_content) do
      case get_field(changeset, :content) do
        content when is_binary(content) -> changeset
        _absent -> add_error(changeset, :content, "can't be blank")
      end
    else
      validate_required(changeset, [:content])
    end
  end

  # Derived here rather than accepted from the caller: `plain_content` is what
  # search, previews and the clipboard read, so a caller able to set it could
  # make a message say one thing and be found as another.
  defp put_plain_content(changeset) do
    content = get_field(changeset, :content)
    content_format = get_field(changeset, :content_format)

    case {content, Content.normalize_format(content_format)} do
      {content, {:ok, _format}} when is_binary(content) ->
        put_change(changeset, :plain_content, Content.plain_text(content, content_format))

      _unusable ->
        changeset
    end
  end
end
