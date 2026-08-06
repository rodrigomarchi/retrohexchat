defmodule RetroHexChat.Net.HTTPRetryTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.Net.HTTPRetry

  @tag :unit
  test "retries transient HTTP statuses and transport-like errors" do
    assert HTTPRetry.retryable?({:http_status, 408})
    assert HTTPRetry.retryable?({:http_status, 425})
    assert HTTPRetry.retryable?({:http_status, 429})
    assert HTTPRetry.retryable?({:http_status, 500})
    assert HTTPRetry.retryable?({:http_status, 503})
    assert HTTPRetry.retryable?({:http_status, 599})
    assert HTTPRetry.retryable?(:fetch_failed)
    assert HTTPRetry.retryable?(:server_error)
    assert HTTPRetry.retryable?(:timeout)
  end

  @tag :unit
  test "does not retry deterministic HTTP statuses" do
    refute HTTPRetry.retryable?({:http_status, 400})
    refute HTTPRetry.retryable?({:http_status, 401})
    refute HTTPRetry.retryable?({:http_status, 403})
    refute HTTPRetry.retryable?({:http_status, 404})
    refute HTTPRetry.retryable?({:http_status, 410})
    refute HTTPRetry.retryable?(:blocked)
    refute HTTPRetry.retryable?(:no_title)
  end
end
