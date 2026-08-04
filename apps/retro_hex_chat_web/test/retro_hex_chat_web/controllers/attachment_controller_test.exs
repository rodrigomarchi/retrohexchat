defmodule RetroHexChatWeb.AttachmentControllerTest do
  use RetroHexChatWeb.ConnCase

  @moduletag :integration

  alias RetroHexChat.Chat.{Attachments, Service}

  defp uploaded_file(owner, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          filename: "download.txt",
          content_type: "text/plain",
          byte_size: 18
        },
        attrs
      )

    {:ok, file, _meta} = Attachments.prepare_direct_upload(owner, attrs)
    {:ok, [file]} = Attachments.confirm_uploaded_files([file.id], owner)
    file
  end

  test "redirects anonymous users to connect", %{conn: conn} do
    conn = get(conn, ~p"/chat/attachments/123")
    assert redirected_to(conn) == "/connect"
  end

  test "redirects channel attachment downloads to a signed storage URL", %{conn: conn} do
    file = uploaded_file("Alice")

    {:ok, message} =
      Service.send_message("#docs", "Alice", "file", "message", attachment_ids: [file.id])

    attachment = hd(message.attachments)

    conn =
      conn
      |> chat_conn("Alice")
      |> get(~p"/chat/attachments/#{attachment.id}")

    assert redirected_to(conn) == "http://storage.test/#{file.storage_bucket}/#{file.storage_key}"
  end

  test "redirects safe inline previews to a signed storage URL", %{conn: conn} do
    file = uploaded_file("Alice", %{filename: "screen.png", content_type: "image/png"})

    {:ok, message} =
      Service.send_message("#docs", "Alice", "file", "message", attachment_ids: [file.id])

    attachment = hd(message.attachments)

    conn =
      conn
      |> chat_conn("Alice")
      |> get(~p"/chat/attachments/#{attachment.id}/preview")

    assert redirected_to(conn) == "http://storage.test/#{file.storage_bucket}/#{file.storage_key}"
    assert get_resp_header(conn, "cache-control") == ["private, max-age=60"]
  end

  test "does not preview unsafe or non-inline attachments", %{conn: conn} do
    file = uploaded_file("Alice", %{filename: "icon.svg", content_type: "image/svg+xml"})

    {:ok, message} =
      Service.send_message("#docs", "Alice", "file", "message", attachment_ids: [file.id])

    attachment = hd(message.attachments)

    conn =
      conn
      |> chat_conn("Alice")
      |> get(~p"/chat/attachments/#{attachment.id}/preview")

    assert response(conn, 404) == ""
  end

  test "hides private attachments from non-participants", %{conn: conn} do
    file = uploaded_file("Alice")

    {:ok, message} =
      Service.send_private_message("Alice", "Bob", "file", "message", attachment_ids: [file.id])

    attachment = hd(message.attachments)

    conn =
      conn
      |> chat_conn("Eve")
      |> get(~p"/chat/attachments/#{attachment.id}")

    assert response(conn, 404) == ""
  end
end
