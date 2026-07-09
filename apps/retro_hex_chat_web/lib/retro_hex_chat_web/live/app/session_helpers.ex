defmodule RetroHexChatWeb.App.SessionHelpers do
  @moduledoc """
  Shared session helpers for app LiveViews: registered-nick resolution (used to
  gate the in-chat arcade) and client-info parsing.
  """

  alias RetroHexChat.Services.RegisteredNick

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
