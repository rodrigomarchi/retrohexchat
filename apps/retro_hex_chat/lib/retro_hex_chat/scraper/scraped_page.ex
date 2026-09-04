defmodule RetroHexChat.Scraper.ScrapedPage do
  @moduledoc """
  One page the server has fetched from the open internet, and everything it
  learned doing so.

  A row is keyed by the normalised URL, not by whoever asked for it: the chat's
  URL Catcher, an RSS bot and anything else that wants a page's metadata all read
  the same row, so a page is fetched once and served to every consumer.

  The preview fields (`title`, `description`, `image_url`, …) are stored as the
  publisher wrote them — **unescaped**. Escaping belongs to whoever renders:
  HTML for the chat, Markdown for a bot message. Storing an escaped title meant
  every consumer escaped it a second time, and `Q&A` reached the screen as
  `Q&amp;A`.

  The HTTP fields are not diagnostics for their own sake. `etag` and
  `last_modified` are what let an expired row be revalidated with a conditional
  request instead of a full download, and `scraper_version` is what lets rows
  extracted by an older parser be reprocessed without discarding the table.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @statuses ~w(pending ready failed)
  @image_thumbnail_statuses ~w(missing pending ready failed)

  @doc "Every status a row may carry."
  @spec statuses() :: [String.t()]
  def statuses, do: @statuses

  schema "scraped_pages" do
    field :url, :string
    field :url_hash, :string
    field :status, :string, default: "pending"

    field :title, :string
    field :description, :string
    field :excerpt, :string
    field :image_url, :string
    field :image_alt, :string
    field :image_thumbnail_status, :string, default: "missing"
    field :image_thumbnail_source_url, :string
    field :image_thumbnail_storage_bucket, :string
    field :image_thumbnail_storage_key, :string
    field :image_thumbnail_content_type, :string
    field :image_thumbnail_byte_size, :integer
    field :image_thumbnail_width, :integer
    field :image_thumbnail_height, :integer
    field :image_thumbnail_fetched_at, :utc_datetime_usec
    field :image_thumbnail_attempted_at, :utc_datetime_usec
    field :image_thumbnail_error_reason, :string
    field :image_thumbnail_error_detail, :map, default: %{}
    field :site_name, :string
    field :canonical_url, :string
    field :author, :string
    field :published_at, :utc_datetime_usec
    field :modified_at, :utc_datetime_usec
    field :lang, :string
    field :section, :string
    field :tags, {:array, :string}, default: []
    field :content_text, :string
    field :content_text_truncated, :boolean, default: false
    field :content_word_count, :integer

    field :final_url, :string
    field :http_status, :integer
    field :content_type, :string
    field :etag, :string
    field :last_modified, :string
    field :scraper_version, :integer, default: 1
    field :raw_metadata, :map, default: %{}

    field :error_reason, :string
    field :error_detail, :map, default: %{}
    field :attempts, :integer, default: 0
    field :last_attempted_at, :utc_datetime_usec

    field :fetched_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec
    field :last_accessed_at, :utc_datetime_usec
    field :revalidating_since, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @castable ~w(
    url url_hash status
    title description excerpt image_url image_alt
    image_thumbnail_status image_thumbnail_source_url
    image_thumbnail_storage_bucket image_thumbnail_storage_key image_thumbnail_content_type
    image_thumbnail_byte_size image_thumbnail_width image_thumbnail_height
    image_thumbnail_fetched_at image_thumbnail_attempted_at
    image_thumbnail_error_reason image_thumbnail_error_detail
    site_name canonical_url author
    published_at modified_at lang section tags
    content_text content_text_truncated content_word_count
    final_url http_status content_type etag last_modified scraper_version raw_metadata
    error_reason error_detail attempts last_attempted_at
    fetched_at expires_at last_accessed_at revalidating_since
  )a

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(page, attrs) do
    page
    |> cast(attrs, @castable)
    |> validate_required([
      :url,
      :url_hash,
      :status,
      :raw_metadata,
      :error_detail,
      :image_thumbnail_status,
      :image_thumbnail_error_detail,
      :attempts,
      :scraper_version,
      :expires_at
    ])
    |> validate_length(:url_hash, is: 64)
    |> validate_number(:attempts, greater_than_or_equal_to: 0)
    |> validate_number(:scraper_version, greater_than: 0)
    |> validate_number(:content_word_count, greater_than_or_equal_to: 0)
    |> validate_number(:image_thumbnail_byte_size, greater_than: 0)
    |> validate_number(:image_thumbnail_width, greater_than: 0)
    |> validate_number(:image_thumbnail_height, greater_than: 0)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:image_thumbnail_status, @image_thumbnail_statuses)
    |> validate_required_for_status()
    |> validate_required_for_image_thumbnail_status()
    |> unique_constraint(:url_hash)
    |> check_constraint(:status, name: :scraped_pages_status_check)
    |> check_constraint(:image_thumbnail_status,
      name: :scraped_pages_image_thumbnail_status_check
    )
    |> check_constraint(:attempts, name: :scraped_pages_attempts_non_negative)
    |> check_constraint(:image_thumbnail_byte_size,
      name: :scraped_pages_image_thumbnail_byte_size_positive
    )
    |> check_constraint(:image_thumbnail_width,
      name: :scraped_pages_image_thumbnail_width_positive
    )
    |> check_constraint(:image_thumbnail_height,
      name: :scraped_pages_image_thumbnail_height_positive
    )
  end

  # A `ready` row with no `fetched_at` cannot be revalidated — there is no
  # instant to measure staleness from — and a `failed` row with no reason cannot
  # be explained to an operator. Neither is worth storing.
  @spec validate_required_for_status(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_required_for_status(changeset) do
    case get_field(changeset, :status) do
      "ready" -> validate_required(changeset, [:fetched_at])
      "failed" -> validate_required(changeset, [:error_reason, :fetched_at])
      _status -> changeset
    end
  end

  @spec validate_required_for_image_thumbnail_status(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_required_for_image_thumbnail_status(changeset) do
    case get_field(changeset, :image_thumbnail_status) do
      "ready" ->
        validate_required(changeset, [
          :image_thumbnail_source_url,
          :image_thumbnail_storage_bucket,
          :image_thumbnail_storage_key,
          :image_thumbnail_content_type,
          :image_thumbnail_byte_size,
          :image_thumbnail_width,
          :image_thumbnail_height,
          :image_thumbnail_fetched_at,
          :image_thumbnail_attempted_at
        ])

      "failed" ->
        validate_required(changeset, [
          :image_thumbnail_source_url,
          :image_thumbnail_error_reason,
          :image_thumbnail_attempted_at
        ])

      "pending" ->
        validate_required(changeset, [
          :image_thumbnail_source_url,
          :image_thumbnail_attempted_at
        ])

      _status ->
        changeset
    end
  end
end
