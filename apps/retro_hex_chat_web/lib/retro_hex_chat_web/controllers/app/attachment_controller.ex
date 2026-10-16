defmodule RetroHexChatWeb.App.AttachmentController do
  @moduledoc """
  Authorizes chat attachment downloads and redirects to short-lived storage URLs.

  A visitor without an account sees the inline previews in the channels they
  may watch — the picture is part of the conversation they are reading — but
  downloading a file is a thing to do, and it sends them to sign in.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Chat.Attachments
  alias RetroHexChatWeb.App.Paths

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    nickname = get_session(conn, :chat_nickname)

    cond do
      not is_binary(nickname) or nickname == "" ->
        redirect(conn, to: Paths.visitor_sign_in_path(:links, Paths.chat_path()))

      attachment = Attachments.get_attachment(id) ->
        authorize_and_redirect(conn, attachment, nickname)

      true ->
        send_resp(conn, :not_found, "")
    end
  end

  @spec preview(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def preview(conn, %{"id" => id}) do
    case Attachments.get_attachment(id) do
      nil -> send_resp(conn, :not_found, "")
      attachment -> authorize_and_preview(conn, attachment, get_session(conn, :chat_nickname))
    end
  end

  defp authorize_and_redirect(conn, attachment, nickname) do
    with true <- Attachments.visible_to?(attachment, nickname),
         {:ok, url} <- Attachments.download_url(attachment, expires_in: 300) do
      redirect(conn, external: url)
    else
      _ -> send_resp(conn, :not_found, "")
    end
  end

  defp authorize_and_preview(conn, attachment, nickname) do
    with true <- previewable_by?(attachment, nickname),
         true <- Attachments.inline_preview?(attachment),
         {:ok, url} <- Attachments.download_url(attachment, expires_in: 300) do
      conn
      |> put_resp_header("cache-control", "private, max-age=60")
      |> redirect(external: url)
    else
      _ -> send_resp(conn, :not_found, "")
    end
  end

  defp previewable_by?(attachment, nickname) when is_binary(nickname) and nickname != "",
    do: Attachments.visible_to?(attachment, nickname)

  defp previewable_by?(attachment, _visitor), do: Attachments.visible_to_visitor?(attachment)
end
