defmodule RetroHexChatWeb.App.SessionHelpers do
  @moduledoc """
  Shared session helpers for app LiveViews: registered-nick resolution (used to
  gate the in-chat arcade) and client-info parsing.
  """

  alias RetroHexChat.Services.{NickServ, RegisteredNick}
  alias RetroHexChatWeb.App.SessionNickname

  @allowed_client_keys %{
    "browser" => :browser,
    "os" => :os,
    "language" => :language,
    "screen" => :screen,
    "color_depth" => :color_depth,
    "touch" => :touch,
    "cores" => :cores,
    "timezone" => :timezone
  }
  @max_string_length 100

  @spec resolve_user_id(String.t()) :: {:ok, integer()} | {:redirect, nil}
  def resolve_user_id(nickname) do
    case RetroHexChat.Repo.get_by(RegisteredNick, nickname: nickname) do
      nil -> {:redirect, nil}
      nick -> {:ok, nick.id}
    end
  end

  @doc """
  Whether `nickname` may mint a share link. Only a registered nickname can: the
  record carries who made it, and a link nobody is accountable for is one
  nobody can be asked about.
  """
  @spec sharable?(String.t() | nil) :: boolean()
  def sharable?(nickname) when is_binary(nickname) and nickname != "",
    do: match?({:ok, _id}, resolve_user_id(nickname))

  def sharable?(_nickname), do: false

  @doc """
  `:ok` when NickServ holds `nickname` identified, else `{:error, message}`.

  Identification is not the chat's private fact: NickServ keeps the set and a
  chat session's `identified` mirrors it, so every surface (a call, a P2P
  session, a group call started from the chat) asks the same authority.
  """
  @spec require_identified(String.t() | nil, String.t()) :: :ok | {:error, String.t()}
  def require_identified(nickname, message) when is_binary(nickname) do
    if NickServ.identified?(nickname), do: :ok, else: {:error, message}
  end

  def require_identified(_nickname, message), do: {:error, message}

  @doc """
  The account id behind `nickname`, or `{:error, message}` when nobody holds
  it. Asked before identification: a nickname that is not registered can never
  be identified, so asking the other way round makes this refusal unreachable.
  """
  @spec require_registered(String.t() | nil, String.t()) ::
          {:ok, integer()} | {:error, String.t()}
  def require_registered(nickname, message) when is_binary(nickname) do
    case resolve_user_id(nickname) do
      {:ok, user_id} -> {:ok, user_id}
      _unregistered -> {:error, message}
    end
  end

  def require_registered(_nickname, message), do: {:error, message}

  @doc """
  The account behind `nickname` when this browser session has proved it, as the
  player a result is written for — nil for a guest, and for a registered nick
  somebody typed without signing in.
  """
  @spec identified_player(map(), String.t() | nil) :: %{id: integer(), nickname: String.t()} | nil
  def identified_player(session, nickname) when is_binary(nickname) do
    with true <- SessionNickname.identified?(session, nickname),
         {:ok, id} <- resolve_user_id(nickname) do
      %{id: id, nickname: nickname}
    else
      _unproved -> nil
    end
  end

  def identified_player(_session, _nickname), do: nil

  @spec parse_client_info(map() | nil) :: map()
  def parse_client_info(nil), do: %{}

  def parse_client_info(params) do
    case params["client_info"] do
      json when is_binary(json) -> decode_client_json(json)
      _ -> %{}
    end
  end

  # --- Private Helpers ---

  defp decode_client_json(json) do
    case Jason.decode(json) do
      {:ok, data} when is_map(data) ->
        Map.new(@allowed_client_keys, fn {str_key, atom_key} ->
          {atom_key, sanitize_client_value(data[str_key])}
        end)

      _ ->
        %{}
    end
  end

  defp sanitize_client_value(val) when is_binary(val),
    do: String.slice(val, 0, @max_string_length)

  defp sanitize_client_value(val) when is_integer(val), do: val
  defp sanitize_client_value(val) when is_boolean(val), do: val
  defp sanitize_client_value(_), do: nil
end
