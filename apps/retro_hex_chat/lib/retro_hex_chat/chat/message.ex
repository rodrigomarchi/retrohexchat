defmodule RetroHexChat.Chat.Message do
  @moduledoc """
  Ecto schema for channel messages.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias RetroHexChat.Chat.Attachment
  alias RetroHexChat.Chat.Content

  @type t :: %__MODULE__{}

  @type_values ~w(message action system service error notice)
  @content_formats ~w(irc markdown plain)

  schema "messages" do
    field :channel_name, :string
    field :author_nickname, :string
    field :content, :string
    field :content_format, :string, default: "irc"
    field :plain_content, :string
    field :type, :string, default: "message"
    field :allow_blank_content, :boolean, virtual: true, default: false

    field :reply_to_id, :integer
    field :reply_to_author, :string
    field :reply_to_preview, :string
    field :edited_at, :utc_datetime_usec
    field :deleted_at, :utc_datetime_usec

    has_many :attachments, Attachment

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(message, attrs) do
    message
    |> cast(
      attrs,
      [
        :channel_name,
        :author_nickname,
        :content,
        :content_format,
        :type,
        :allow_blank_content
      ],
      empty_values: []
    )
    |> validate_required([:channel_name, :author_nickname, :content_format])
    |> validate_content_required()
    |> validate_length(:channel_name, max: 50)
    |> validate_length(:author_nickname, max: 16)
    |> validate_inclusion(:content_format, @content_formats)
    |> validate_inclusion(:type, @type_values)
    |> put_plain_content()
    |> check_constraint(:content_format, name: :messages_content_format_check)
  end

  @spec reply_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def reply_changeset(message, attrs) do
    message
    |> cast(
      attrs,
      [
        :channel_name,
        :author_nickname,
        :content,
        :content_format,
        :type,
        :allow_blank_content,
        :reply_to_id,
        :reply_to_author,
        :reply_to_preview
      ],
      empty_values: []
    )
    |> validate_required([:channel_name, :author_nickname, :content_format])
    |> validate_content_required()
    |> validate_length(:channel_name, max: 50)
    |> validate_length(:author_nickname, max: 16)
    |> validate_inclusion(:content_format, @content_formats)
    |> validate_inclusion(:type, @type_values)
    |> put_plain_content()
    |> check_constraint(:content_format, name: :messages_content_format_check)
    |> validate_reply_fields()
  end

  @spec edit_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def edit_changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :content_format, :edited_at])
    |> validate_required([:content, :content_format, :edited_at])
    |> validate_inclusion(:content_format, @content_formats)
    |> put_plain_content()
    |> check_constraint(:content_format, name: :messages_content_format_check)
  end

  @spec delete_changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def delete_changeset(message, attrs) do
    message
    |> cast(attrs, [:deleted_at])
    |> validate_required([:deleted_at])
  end

  defp validate_reply_fields(changeset) do
    reply_to_id = get_change(changeset, :reply_to_id)

    if reply_to_id do
      changeset
      |> validate_required([:reply_to_author, :reply_to_preview])
      |> validate_length(:reply_to_author, max: 16)
      |> validate_length(:reply_to_preview, max: 100)
    else
      changeset
    end
  end

  defp validate_content_required(changeset) do
    if get_field(changeset, :allow_blank_content) do
      case get_field(changeset, :content) do
        content when is_binary(content) -> changeset
        _ -> add_error(changeset, :content, "can't be blank")
      end
    else
      validate_required(changeset, [:content])
    end
  end

  defp put_plain_content(changeset) do
    content = get_field(changeset, :content)
    content_format = get_field(changeset, :content_format)

    case {content, Content.normalize_format(content_format)} do
      {content, {:ok, _format}} when is_binary(content) ->
        put_change(changeset, :plain_content, Content.plain_text(content, content_format))

      _ ->
        changeset
    end
  end
end
