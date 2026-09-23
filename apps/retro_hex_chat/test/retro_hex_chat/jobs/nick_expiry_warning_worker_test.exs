defmodule RetroHexChat.Jobs.NickExpiryWarningWorkerTest do
  @moduledoc """
  The warning that closes the loop on nickname expiry.

  Nicknames are released after a long silence. Releasing one without ever
  telling its owner is the version of this feature that loses people, so anybody
  who confirmed an address hears about it while there is still time to do
  something.

  Warned once, and once only — not by remembering who was warned, but because
  the window is one day wide on `last_seen_at` and the job runs daily. A person
  who comes back leaves the window by coming back, which is the whole point.
  """
  use RetroHexChat.DataCase, async: false

  import Ecto.Query

  import Swoosh.TestAssertions

  @moduletag :integration

  alias RetroHexChat.Jobs.NickExpiryWarningWorker
  alias RetroHexChat.Services.NickEmail
  alias RetroHexChat.Services.NickExpiry
  alias RetroHexChat.Services.Queries
  alias RetroHexChat.Services.RegisteredNick

  describe "perform/1" do
    test "warns somebody whose silence is about to cost them the nickname" do
      nick = confirmed_nick(days_silent: warning_day())

      assert {:ok, %{warned: 1}} = perform()

      assert_email_sent(fn email ->
        assert {_name, address} = hd(email.to)
        assert address == "#{nick}@example.com"
        assert email.subject =~ "nickname"
      end)
    end

    test "says nothing the day before the window" do
      confirmed_nick(days_silent: warning_day() - 1)

      assert {:ok, %{warned: 0}} = perform()
      refute_email_sent()
    end

    test "does not warn the same person again the next day" do
      confirmed_nick(days_silent: warning_day() + 1)

      assert {:ok, %{warned: 0}} = perform()
      refute_email_sent()
    end

    # An address nobody proved they own is an address the server must not send
    # to: that is what confirmation is for.
    test "ignores an address that was never confirmed" do
      nick = "unconf#{uid()}" |> String.slice(0, 16)
      {:ok, _} = Queries.insert_registered_nick(nick, "password123")
      :ok = NickEmail.set_email(nick, "#{nick}@example.com", &link/1)
      silence(nick, warning_day())

      assert {:ok, %{warned: 0}} = perform()
      refute_email_sent()
    end

    test "ignores somebody with no address at all" do
      nick = "noaddr#{uid()}" |> String.slice(0, 16)
      {:ok, _} = Queries.insert_registered_nick(nick, "password123")
      silence(nick, warning_day())

      assert {:ok, %{warned: 0}} = perform()
      refute_email_sent()
    end
  end

  defp perform, do: NickExpiryWarningWorker.perform(%Oban.Job{args: %{}})

  defp warning_day, do: NickExpiry.configured_expiration_days() - 14

  defp confirmed_nick(days_silent: days) do
    nick = "warn#{uid()}" |> String.slice(0, 16)
    {:ok, _} = Queries.insert_registered_nick(nick, "password123")
    :ok = NickEmail.set_email(nick, "#{nick}@example.com", &link/1)
    token = capture_token()
    {:ok, ^nick} = NickEmail.verify_email(token)
    silence(nick, days)
    nick
  end

  defp silence(nickname, days) do
    at = DateTime.add(DateTime.utc_now(), -days * 24 * 60 * 60, :second)

    RegisteredNick
    |> Repo.get_by(nickname: nickname)
    |> Ecto.Changeset.change(last_seen_at: at)
    |> Repo.update!()
  end

  defp uid, do: System.unique_integer([:positive])

  defp link(token), do: "https://example.test/account/" <> token

  # The confirmation goes through the queue, so its link is read from the job.
  # The warning itself does not: this worker is already background, and sending
  # from here is the whole thing being tested.
  defp capture_token do
    job = Repo.one!(from j in Oban.Job, order_by: [desc: j.id], limit: 1)
    [_whole, token] = Regex.run(~r{account/([A-Za-z0-9_\-\.]+)}, job.args["body"])
    token
  end
end
