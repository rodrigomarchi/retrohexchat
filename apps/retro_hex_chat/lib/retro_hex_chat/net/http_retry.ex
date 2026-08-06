defmodule RetroHexChat.Net.HTTPRetry do
  @moduledoc """
  Shared retry policy for server-side HTTP work scheduled through Oban.
  """

  @type reason :: atom() | {:http_status, pos_integer()} | term()

  @spec retryable?(reason()) :: boolean()
  def retryable?({:http_status, status}) when status in [408, 425, 429], do: true
  def retryable?({:http_status, status}) when status in 500..599, do: true
  def retryable?(:fetch_failed), do: true
  def retryable?(:server_error), do: true
  def retryable?(:timeout), do: true
  def retryable?(_reason), do: false
end
