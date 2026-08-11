defmodule RetroHexChat.Jobs.RetryTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Jobs.Retry

  describe "wait_seconds/3" do
    test "grows with the square of the attempt" do
      assert Retry.wait_seconds(1, 900, 30) == 30
      assert Retry.wait_seconds(2, 900, 30) == 120
      assert Retry.wait_seconds(3, 900, 30) == 270
    end

    # Without the ceiling the fifth attempt of a job with a one-minute step
    # would wait twenty-five minutes, and the tenth an hour and a half.
    test "stops at the ceiling" do
      assert Retry.wait_seconds(6, 900, 30) == 900
      assert Retry.wait_seconds(100, 900, 30) == 900
    end
  end

  # Sixteen workers had these two callbacks written out; this is what each one
  # answered before they were shared, read out of the tree as it was. It is the
  # only thing standing between a mechanical rewrite and a mistyped number that
  # nothing else would notice — a job's retry pace is invisible until a queue
  # misbehaves in production.
  @policies [
    {RetroHexChat.Jobs.AttachmentOrphanCleanupWorker, 120_000, 15 * 60, 60},
    {RetroHexChat.Jobs.BotEventLogWorker, 30_000, 30 * 60, 30},
    {RetroHexChat.Jobs.BotScheduledMessageWorker, 60_000, 30 * 60, 60},
    {RetroHexChat.Jobs.ChannelMuteExpiryWorker, 30_000, 15 * 60, 30},
    {RetroHexChat.Jobs.ChatDeviceSessionCleanupWorker, 60_000, 15 * 60, 60},
    {RetroHexChat.Jobs.GlobalMuteExpiryWorker, 30_000, 15 * 60, 30},
    {RetroHexChat.Jobs.IgnoreExpiredCleanupWorker, 60_000, 15 * 60, 60},
    {RetroHexChat.Jobs.PageScrapeWorker, 20_000, 5 * 60, 15},
    {RetroHexChat.Jobs.PreferenceSaveWorker, 30_000, 10 * 60, 15},
    {RetroHexChat.Jobs.RegisteredChannelExpiryWorker, 120_000, 900, 30},
    {RetroHexChat.Jobs.RegisteredNickExpiryWorker, 120_000, 900, 30},
    {RetroHexChat.Jobs.RSSPollWorker, 300_000, 30 * 60, 60},
    {RetroHexChat.Jobs.RuntimeStaleCleanupWorker, 120_000, 15 * 60, 60},
    {RetroHexChat.Jobs.ScrapedPagePruneWorker, 60_000, 15 * 60, 60},
    {RetroHexChat.Jobs.ServerBanExpiryWorker, 60_000, 900, 30},
    {RetroHexChat.Jobs.TrustedDeviceExpiryWorker, 60_000, 15 * 60, 60}
  ]

  for {worker, timeout_ms, cap_seconds, step_seconds} <- @policies do
    test "#{inspect(worker)} keeps the policy it was written with" do
      assert unquote(worker).timeout(%Oban.Job{}) == unquote(timeout_ms)

      assert unquote(worker).backoff(%Oban.Job{attempt: 1}) == unquote(step_seconds)

      assert unquote(worker).backoff(%Oban.Job{attempt: 2}) == unquote(4 * step_seconds)

      assert unquote(worker).backoff(%Oban.Job{attempt: 1000}) == unquote(cap_seconds)
    end
  end

  test "every worker in the tree uses the shared policy" do
    without =
      "apps/retro_hex_chat/lib/retro_hex_chat/jobs/*_worker.ex"
      |> Path.wildcard()
      |> Enum.reject(&(File.read!(&1) =~ "use RetroHexChat.Jobs.Retry"))

    assert without == []
  end
end
