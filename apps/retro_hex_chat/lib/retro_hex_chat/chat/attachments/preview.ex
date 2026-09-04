defmodule RetroHexChat.Chat.Attachments.Preview do
  @moduledoc """
  Classifies uploaded files into durable preview families.

  The classifier is intentionally conservative: unsafe browser-rendered formats
  such as SVG and HTML never become inline previews just because they carry an
  image/text-ish MIME type.
  """

  alias RetroHexChat.Chat.UploadedFile

  @type kind ::
          :image | :video | :audio | :pdf | :text | :code | :archive | :office | :download

  @preview_kinds ~w(image video audio pdf text code archive office download)
  @preview_statuses ~w(none pending ready failed blocked)
  @inline_kinds ~w(image video audio pdf)

  @safe_image_types ~w(image/png image/jpeg image/gif image/webp image/avif image/bmp)
  @video_types ~w(video/mp4 video/webm video/quicktime video/ogg)
  @audio_types ~w(audio/mpeg audio/mp3 audio/wav audio/x-wav audio/ogg audio/webm audio/mp4)
  @pdf_types ~w(application/pdf)
  @text_types ~w(text/plain text/markdown text/csv text/tab-separated-values)

  @archive_types ~w(
    application/zip
    application/gzip
    application/x-gzip
    application/x-tar
    application/x-7z-compressed
    application/vnd.rar
  )

  @office_type_prefixes [
    "application/vnd.openxmlformats-officedocument.",
    "application/vnd.ms-",
    "application/msword",
    "application/vnd.oasis.opendocument."
  ]

  @image_extensions ~w(.png .jpg .jpeg .gif .webp .avif .bmp)
  @video_extensions ~w(.mp4 .webm .mov .ogv)
  @audio_extensions ~w(.mp3 .wav .ogg .oga .m4a .aac)
  @pdf_extensions ~w(.pdf)
  @text_extensions ~w(.txt .md .markdown .log .csv .tsv .ini .conf .env)

  @code_extensions ~w(
    .ex .exs .heex .eex .js .jsx .ts .tsx .css .html .htm .json .xml .yml .yaml
    .toml .sql .sh .bash .zsh .py .rb .go .rs .java .c .cc .cpp .h .hpp .php .erl .hrl
  )

  @archive_extensions ~w(.zip .gz .tgz .tar .7z .rar)
  @office_extensions ~w(.doc .docx .xls .xlsx .ppt .pptx .odt .ods .odp)
  @unsafe_inline_extensions ~w(.svg .svgz)
  @unsafe_code_types ~w(text/html application/xhtml+xml application/xml text/xml)
  @unsafe_inline_types ~w(image/svg+xml text/html application/xhtml+xml application/xml text/xml)

  @spec kinds() :: [String.t()]
  def kinds, do: @preview_kinds

  @spec statuses() :: [String.t()]
  def statuses, do: @preview_statuses

  @spec classify(String.t() | nil, String.t() | nil) :: String.t()
  def classify(filename, content_type) do
    ext = extension(filename)
    type = normalize_content_type(content_type)

    if unsafe_inline?(ext, type) do
      classify_unsafe(ext, type)
    else
      classify_safe(ext, type)
    end
  end

  @spec initial_status(String.t(), String.t() | nil) :: String.t()
  def initial_status(kind, content_type) when kind in @inline_kinds do
    if safe_inline_content_type?(kind, content_type), do: "ready", else: "none"
  end

  def initial_status(_kind, _content_type), do: "none"

  @spec inline?(UploadedFile.t() | map()) :: boolean()
  def inline?(%UploadedFile{} = file) do
    inline?(%{
      preview_kind: file.preview_kind,
      preview_status: file.preview_status,
      content_type: file.content_type
    })
  end

  def inline?(%{preview_kind: kind, preview_status: "ready", content_type: content_type})
      when kind in @inline_kinds do
    safe_inline_content_type?(kind, content_type)
  end

  def inline?(_file), do: false

  defp classify_safe(ext, type) do
    Enum.find_value(classifiers(), fn classifier -> classifier.(ext, type) end) || "download"
  end

  defp classifiers do
    [
      &classify_image/2,
      &classify_video/2,
      &classify_audio/2,
      &classify_pdf/2,
      &classify_office/2,
      &classify_archive/2,
      &classify_code/2,
      &classify_text/2
    ]
  end

  defp classify_image(_ext, type) when type in @safe_image_types, do: "image"
  defp classify_image(ext, _type) when ext in @image_extensions, do: "image"
  defp classify_image(_ext, _type), do: nil

  defp classify_video(_ext, type) when type in @video_types, do: "video"
  defp classify_video(ext, _type) when ext in @video_extensions, do: "video"
  defp classify_video(_ext, _type), do: nil

  defp classify_audio(_ext, type) when type in @audio_types, do: "audio"
  defp classify_audio(ext, _type) when ext in @audio_extensions, do: "audio"
  defp classify_audio(_ext, _type), do: nil

  defp classify_pdf(_ext, type) when type in @pdf_types, do: "pdf"
  defp classify_pdf(ext, _type) when ext in @pdf_extensions, do: "pdf"
  defp classify_pdf(_ext, _type), do: nil

  defp classify_office(ext, type) do
    if office_type?(type) or ext in @office_extensions, do: "office"
  end

  defp classify_archive(_ext, type) when type in @archive_types, do: "archive"
  defp classify_archive(ext, _type) when ext in @archive_extensions, do: "archive"
  defp classify_archive(_ext, _type), do: nil

  defp classify_code(ext, type) do
    if code_type?(type) or ext in @code_extensions, do: "code"
  end

  defp classify_text(_ext, type) when type in @text_types, do: "text"
  defp classify_text(ext, _type) when ext in @text_extensions, do: "text"
  defp classify_text(_ext, _type), do: nil

  defp classify_unsafe(ext, type) when ext in ~w(.html .htm .xml) or type in @unsafe_code_types,
    do: "code"

  defp classify_unsafe(_ext, _type), do: "download"

  defp unsafe_inline?(ext, type) do
    ext in @unsafe_inline_extensions or type in @unsafe_inline_types
  end

  defp safe_inline_content_type?("image", content_type),
    do: normalize_content_type(content_type) in @safe_image_types

  defp safe_inline_content_type?("video", content_type),
    do: normalize_content_type(content_type) in @video_types

  defp safe_inline_content_type?("audio", content_type),
    do: normalize_content_type(content_type) in @audio_types

  defp safe_inline_content_type?("pdf", content_type),
    do: normalize_content_type(content_type) in @pdf_types

  defp safe_inline_content_type?(_kind, _content_type), do: false

  defp code_type?(type) do
    type in ~w(application/json application/javascript text/javascript text/css) or
      String.ends_with?(type, "+json") or String.ends_with?(type, "+xml")
  end

  defp office_type?(type) do
    Enum.any?(@office_type_prefixes, &String.starts_with?(type, &1))
  end

  defp extension(filename) when is_binary(filename) do
    filename
    |> Path.extname()
    |> String.downcase()
  end

  defp extension(_filename), do: ""

  defp normalize_content_type(content_type) when is_binary(content_type) do
    content_type
    |> String.split(";", parts: 2)
    |> hd()
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_content_type(_content_type), do: ""
end
