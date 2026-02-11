defmodule RetroHexChat.Chat.Policy do
  @moduledoc """
  Content validation and authorization for chat messages.
  """

  alias RetroHexChat.Chat.Formatter
  alias RetroHexChat.RateLimit.Limiter

  @max_content_length 1000

  @spec validate_content(String.t()) :: :ok | {:error, String.t()}
  def validate_content(content) when is_binary(content) do
    cond do
      byte_size(content) == 0 ->
        {:error, "Message cannot be empty"}

      String.length(content) > @max_content_length ->
        {:error, "Message exceeds maximum length of #{@max_content_length} characters"}

      not Formatter.has_visible_text?(content) ->
        {:error, "Message cannot be empty"}

      true ->
        :ok
    end
  end

  @spec check_rate_limit(atom() | :ets.tid(), String.t()) :: :ok | {:error, :rate_limited}
  def check_rate_limit(table, nickname) do
    Limiter.check_rate(table, nickname, :message)
  end
end
