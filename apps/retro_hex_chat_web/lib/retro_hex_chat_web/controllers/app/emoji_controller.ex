defmodule RetroHexChatWeb.App.EmojiController do
  @moduledoc """
  Serves a server emoji by redirecting to a short-lived storage URL.

  Addressed by id rather than by name so the address is stable for as long as
  the picture is: a name freed by a removal and taken again would otherwise hand
  back whatever the browser cached under it.

  The redirect, rather than the signed URL itself, is what lets a message keep
  one address forever. A signed URL rendered into the conversation would expire
  while the line was still on screen, and re-signing it on every render would
  make every message cost a signature.
  """
  use RetroHexChatWeb, :controller

  alias RetroHexChat.Chat.Attachments
  alias RetroHexChat.Chat.CustomEmojis
  alias RetroHexChat.Chat.Queries

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    nickname = get_session(conn, :chat_nickname)

    cond do
      not is_binary(nickname) or nickname == "" ->
        redirect(conn, to: ~p"/connect")

      entry = find(id) ->
        redirect_to_storage(conn, entry)

      true ->
        send_resp(conn, :not_found, "")
    end
  end

  @spec find(String.t()) :: CustomEmojis.entry() | nil
  defp find(id) do
    case Integer.parse(id) do
      {parsed, ""} -> Enum.find(CustomEmojis.all(), &(&1.id == parsed))
      _not_an_id -> nil
    end
  end

  defp redirect_to_storage(conn, entry) do
    with %{} = file <- Queries.get_uploaded_file(entry.uploaded_file_id),
         {:ok, url} <- Attachments.file_url(file, expires_in: 900) do
      conn
      # Everybody on this server sees the same picture under the same address,
      # and it never changes while it exists.
      |> put_resp_header("cache-control", "private, max-age=900")
      |> redirect(external: url)
    else
      _nothing_to_serve -> send_resp(conn, :not_found, "")
    end
  end
end
