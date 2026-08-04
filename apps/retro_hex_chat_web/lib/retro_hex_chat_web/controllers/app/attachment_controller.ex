defmodule RetroHexChatWeb.App.AttachmentController do
  @moduledoc """
  Authorizes chat attachment downloads and redirects to short-lived storage URLs.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Chat.Attachments

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    nickname = get_session(conn, :chat_nickname)

    cond do
      not is_binary(nickname) or nickname == "" ->
        redirect(conn, to: ~p"/connect")

      attachment = Attachments.get_attachment(id) ->
        authorize_and_redirect(conn, attachment, nickname)

      true ->
        send_resp(conn, :not_found, "")
    end
  end

  @spec preview(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def preview(conn, %{"id" => id}) do
    nickname = get_session(conn, :chat_nickname)

    cond do
      not is_binary(nickname) or nickname == "" ->
        redirect(conn, to: ~p"/connect")

      attachment = Attachments.get_attachment(id) ->
        authorize_and_preview(conn, attachment, nickname)

      true ->
        send_resp(conn, :not_found, "")
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
    with true <- Attachments.visible_to?(attachment, nickname),
         true <- Attachments.inline_preview?(attachment),
         {:ok, url} <- Attachments.download_url(attachment, expires_in: 300) do
      conn
      |> put_resp_header("cache-control", "private, max-age=60")
      |> redirect(external: url)
    else
      _ -> send_resp(conn, :not_found, "")
    end
  end
end
