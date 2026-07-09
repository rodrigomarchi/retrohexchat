defmodule RetroHexChatWeb.ChatLive.Helpers.SessionCard do
  @moduledoc """
  Resolves P2P-lobby chat messages into rich session cards.

  A `:p2p_invite` PM carries only a link in its `content`. This helper extracts
  the session token from that link, asks the domain (`Lobby.session_summary/1`)
  for a resolved, presentation-ready summary, and attaches it to the stream item
  under `:session_card`. `MessageRow` renders the rich card when the key is
  present and falls back to the plain link card when the session can't be
  resolved (unknown token, purged session).

  Resolution is a DB read, so it runs here — while building the stream item in
  the LiveView process — never inside the pure render components. Because the
  summary is queried at build time, a historical (terminal) session naturally
  renders its final state, and a live session renders its current one.
  """

  alias RetroHexChat.Lobby
  alias RetroHexChatWeb.App.ChatHelpers

  # Matches the token in a lobby/legacy-p2p link (`/lobby/<token>`,
  # `/p2p/<token>`, `/game/<token>`), anywhere inside the content.
  @lobby_token_regex ~r{/(?:lobby|p2p|game)/([^\s/?#]+)}

  @doc """
  Attaches a `:session_card` summary to a stream item when it is a resolvable
  P2P-invite message. All other items pass through untouched.
  """
  @spec enrich(map()) :: map()
  def enrich(%{type: :p2p_invite, content: content} = item) when is_binary(content) do
    with token when is_binary(token) <- extract_token(@lobby_token_regex, content),
         {:ok, summary} <- Lobby.session_summary(token) do
      Map.put(item, :session_card, Map.put(summary, :href, ChatHelpers.extract_p2p_link(content)))
    else
      _ -> item
    end
  end

  def enrich(item), do: item

  @spec extract_token(Regex.t(), String.t()) :: String.t() | nil
  defp extract_token(regex, content) do
    case Regex.run(regex, content) do
      [_, token] -> token
      _ -> nil
    end
  end
end
