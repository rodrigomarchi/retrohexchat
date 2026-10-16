defmodule RetroHexChatWeb.App.SessionNickname do
  @moduledoc """
  Who the Plug session says somebody is, asked the same way by every entry.

  The chat, every surface and the arcade's address all start from the
  `chat_nickname` the session carries, and all refuse the same two things: no
  usable nickname (a visitor) and a banned one. Answering it in one place is
  what keeps a third entry from forgetting the ban check.
  """

  alias RetroHexChat.Accounts.NicknameValidator
  alias RetroHexChat.Admin.ServerBans
  alias RetroHexChat.Services.NickServ

  @doc "The session's nickname, `:visitor` when it has none worth the name, `:banned`."
  @spec resolve(map()) :: {:ok, String.t()} | :visitor | :banned
  def resolve(session) when is_map(session) do
    nickname = session["chat_nickname"]

    cond do
      not is_binary(nickname) or NicknameValidator.validate(nickname) != :ok -> :visitor
      ServerBans.banned?(nickname) -> :banned
      true -> {:ok, nickname}
    end
  end

  @doc """
  Whether this browser session has proved `nickname` — a short-token or
  trusted-device sign-in, or an identification made in this session.
  """
  @spec identified?(map(), String.t()) :: boolean()
  def identified?(session, nickname) when is_map(session) and is_binary(nickname) do
    session["chat_pre_identified"] == true or
      NickServ.identified_in_session?(nickname, session["chat_session_id"])
  end
end
