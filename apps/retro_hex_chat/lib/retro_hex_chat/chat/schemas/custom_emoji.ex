defmodule RetroHexChat.Chat.Schemas.CustomEmoji do
  @moduledoc """
  A picture this server answers to by name.

  The name is the whole interface: people type `:shrug:` and expect the picture,
  so it is restricted to what somebody can type between two colons without
  thinking — lower-case letters, digits and underscores. Anything else would be
  a name that renders in the picker and cannot be written by hand.

  The picture itself is an ordinary uploaded file, which is what gives this
  feature a size limit, orphan cleanup and a storage backend without any of them
  being written twice.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias RetroHexChat.Chat.UploadedFile

  @type t :: %__MODULE__{}

  @name_format ~r/\A[a-z0-9_]{2,32}\z/

  schema "custom_emojis" do
    field :name, :string
    field :added_by, :string

    belongs_to :file, UploadedFile, foreign_key: :uploaded_file_id

    timestamps(type: :utc_datetime_usec)
  end

  @doc "The shape a name has to have to be typeable between two colons."
  @spec name_format() :: Regex.t()
  def name_format, do: @name_format

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(emoji, attrs) do
    emoji
    |> cast(attrs, [:name, :uploaded_file_id, :added_by])
    |> update_change(:name, &normalize_name/1)
    |> validate_required([:name, :uploaded_file_id, :added_by])
    |> validate_format(:name, @name_format)
    |> validate_length(:added_by, max: 16)
    |> unique_constraint(:name, name: :custom_emojis_lower_name_index)
    |> foreign_key_constraint(:uploaded_file_id)
  end

  # Typed with colons around it, or shouted — all the same word.
  defp normalize_name(name) when is_binary(name) do
    name |> String.trim() |> String.trim(":") |> String.downcase()
  end

  defp normalize_name(name), do: name
end
