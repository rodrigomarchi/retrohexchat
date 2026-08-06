defmodule RetroHexChat.Chat.AttachmentsTest do
  use RetroHexChat.DataCase, async: true

  @moduletag :unit

  alias RetroHexChat.Chat.{Attachments, UploadedFile}
  alias RetroHexChat.Chat.Attachments.Preview

  test "prepare_direct_upload creates a reserved file with logical path metadata" do
    directory_path = Attachments.directory_path_for(:channel, "#lobby", "Alice", ~D[2026-08-04])

    assert {:ok, file, meta} =
             Attachments.prepare_direct_upload("Alice", %{
               filename: "../report.pdf",
               content_type: "application/pdf",
               byte_size: 123,
               directory_path: directory_path
             })

    assert file.owner_nickname == "Alice"
    assert file.original_filename == "report.pdf"
    assert file.content_type == "application/pdf"
    assert file.byte_size == 123
    assert file.status == "reserved"
    assert file.preview_kind == "pdf"
    assert file.preview_status == "ready"
    assert file.directory_path == "/chat/channels/lobby/2026/08/04/Alice"
    assert file.logical_path =~ ~r{^/chat/channels/lobby/2026/08/04/Alice/.+-report.pdf$}

    assert meta.uploader == "S3Direct"
    assert meta.file_id == file.id
    assert meta.method == "PUT"
    assert meta.headers == [["content-type", "application/pdf"]]
    assert meta.url =~ file.storage_key
  end

  test "confirm_uploaded_files moves reserved files to uploaded for the owner" do
    assert {:ok, file, _meta} =
             Attachments.prepare_direct_upload("Alice", %{
               filename: "notes.txt",
               content_type: "text/plain",
               byte_size: 12
             })

    assert {:ok, [confirmed]} = Attachments.confirm_uploaded_files([file.id], "Alice")
    assert confirmed.id == file.id
    assert confirmed.status == "uploaded"

    assert {:error, :attachment_not_found} =
             Attachments.confirm_uploaded_files([file.id], "Mallory")
  end

  test "cleanup_orphan_uploads marks old reserved uploads as deleted" do
    assert {:ok, file, _meta} =
             Attachments.prepare_direct_upload("Alice", %{
               filename: "orphan.txt",
               content_type: "text/plain",
               byte_size: 12
             })

    make_old(file.id)

    assert {:ok, summary} =
             Attachments.cleanup_orphan_uploads(limit: 10, orphan_age_seconds: 3_600)

    assert summary.candidates == 1
    assert summary.deleted == 1
    assert summary.skipped == 0
    assert summary.bytes_deleted == 12

    assert Repo.get(UploadedFile, file.id).status == "deleted"
  end

  test "cleanup_orphan_uploads ignores fresh and attached uploads" do
    assert {:ok, fresh, _meta} =
             Attachments.prepare_direct_upload("Alice", %{
               filename: "fresh.txt",
               content_type: "text/plain",
               byte_size: 12
             })

    assert {:ok, attached, _meta} =
             Attachments.prepare_direct_upload("Alice", %{
               filename: "attached.txt",
               content_type: "text/plain",
               byte_size: 13
             })

    make_old(attached.id)

    from(file in UploadedFile, where: file.id == ^attached.id)
    |> Repo.update_all(set: [status: "attached"])

    assert {:ok, summary} =
             Attachments.cleanup_orphan_uploads(limit: 10, orphan_age_seconds: 3_600)

    assert summary.candidates == 0
    assert summary.deleted == 0
    assert Repo.get(UploadedFile, fresh.id).status == "reserved"
    assert Repo.get(UploadedFile, attached.id).status == "attached"
  end

  test "classifies preview families conservatively" do
    assert Preview.classify("photo.png", "image/png") == "image"
    assert Preview.classify("clip.webm", "video/webm") == "video"
    assert Preview.classify("voice.mp3", "audio/mpeg") == "audio"
    assert Preview.classify("manual.pdf", "application/pdf") == "pdf"
    assert Preview.classify("notes.txt", "text/plain") == "text"
    assert Preview.classify("payload.json", "application/json") == "code"
    assert Preview.classify("bundle.zip", "application/zip") == "archive"

    assert Preview.classify(
             "sheet.xlsx",
             "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
           ) == "office"

    assert Preview.classify("icon.svg", "image/svg+xml") == "download"
    assert Preview.classify("page.html", "text/html") == "code"
    assert Preview.classify("unknown.bin", "application/octet-stream") == "download"
  end

  test "only safe browser-rendered content is inline preview ready" do
    assert Preview.initial_status("image", "image/png") == "ready"
    assert Preview.initial_status("image", "application/octet-stream") == "none"
    assert Preview.initial_status("pdf", "application/pdf") == "ready"
    assert Preview.initial_status("text", "text/plain") == "none"
    assert Preview.initial_status("download", "application/octet-stream") == "none"
  end

  defp make_old(file_id) do
    old = DateTime.utc_now() |> DateTime.add(-7_200, :second)

    from(file in UploadedFile, where: file.id == ^file_id)
    |> Repo.update_all(set: [inserted_at: old, updated_at: old])
  end
end
