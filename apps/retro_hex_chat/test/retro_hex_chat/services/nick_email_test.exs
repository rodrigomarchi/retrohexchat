defmodule RetroHexChat.Services.NickEmailTest do
  @moduledoc """
  An optional address, and the only way back into an account whose password is
  gone.

  Three rules decide almost everything here. The address is optional, so two
  nicknames without one must not collide. It is private, so nothing about a
  reset may reveal whether a nickname exists. And a token opens exactly one
  door: the link that confirms an address must not also change a password.

  The token is never read out of the database — only its hash is stored. Every
  test here takes it out of the message that was queued, which is also the only
  way to prove the link in that message works. Whether the queued message then
  reaches a relay is `RetroHexChat.Jobs.MailWorkerTest`.
  """
  use RetroHexChat.DataCase, async: false

  import Ecto.Query

  @moduletag :integration

  alias RetroHexChat.Jobs.MailWorker
  alias RetroHexChat.Services.NickEmail
  alias RetroHexChat.Services.Queries
  alias RetroHexChat.Services.RegisteredNick

  # The domain has no routes, so the caller says what a link looks like. In the
  # app that is the web layer; here it is the shortest thing that round-trips.
  @link_prefix "https://example.test/account/"

  setup do
    nick = register("mail#{uid()}")
    %{nick: nick}
  end

  describe "set_email/3" do
    test "takes a valid address, leaves it unverified, and sends the link", %{nick: nick} do
      assert :ok = NickEmail.set_email(nick, "someone@example.com", &link/1)

      row = reload(nick)
      assert row.email == "someone@example.com"
      assert row.email_verified_at == nil
      assert row.email_token_hash != nil

      assert %{args: %{"to" => "someone@example.com"} = args} = queued()
      assert token_from(args)
    end

    test "refuses something that is not an address", %{nick: nick} do
      assert {:error, _reason} = NickEmail.set_email(nick, "not an address", &link/1)

      assert reload(nick).email == nil
      refute_enqueued(worker: MailWorker)
    end

    test "refuses an address another nickname already has", %{nick: nick} do
      other = register("other#{uid()}")
      assert :ok = NickEmail.set_email(other, "taken@example.com", &link/1)

      assert {:error, _reason} = NickEmail.set_email(nick, "TAKEN@example.com", &link/1)
      assert reload(nick).email == nil
    end

    # The partial index earns its keep here: a plain unique index would make the
    # second address-less registration collide with the first.
    test "two nicknames with no address at all do not collide" do
      first = register("none1#{uid()}")
      second = register("none2#{uid()}")

      assert reload(first).email == nil
      assert reload(second).email == nil
    end

    test "removing the address clears the token with it", %{nick: nick} do
      assert :ok = NickEmail.set_email(nick, "someone@example.com", &link/1)
      assert :ok = NickEmail.remove_email(nick)

      row = reload(nick)
      assert row.email == nil
      assert row.email_verified_at == nil
      assert row.email_token_hash == nil
    end
  end

  describe "verify_email/2" do
    test "confirms the address the token was minted for", %{nick: nick} do
      token = set_email_and_capture(nick, "someone@example.com")

      assert {:ok, ^nick} = NickEmail.verify_email(token)
      assert reload(nick).email_verified_at != nil
    end

    test "a token cannot be spent twice", %{nick: nick} do
      token = set_email_and_capture(nick, "someone@example.com")

      assert {:ok, ^nick} = NickEmail.verify_email(token)
      assert {:error, :invalid} = NickEmail.verify_email(token)
    end

    test "a token older than its window is refused", %{nick: nick} do
      token = set_email_and_capture(nick, "someone@example.com")

      assert {:error, :expired} = NickEmail.verify_email(token, max_age: -1)
      assert reload(nick).email_verified_at == nil
    end

    # The salt is what separates the two doors. Without it, the link that
    # confirms an address would also change a password.
    test "a reset token does not confirm an address", %{nick: nick} do
      verify_and_capture(nick, "someone@example.com")
      reset = request_reset_and_capture(nick)

      assert {:error, :invalid} = NickEmail.verify_email(reset)
    end
  end

  describe "reset_password/3" do
    test "changes the password and spends the token", %{nick: nick} do
      verify_and_capture(nick, "reset@example.com")
      token = request_reset_and_capture(nick)

      assert :ok = NickEmail.reset_password(token, "a-brand-new-password")
      assert {:error, :invalid} = NickEmail.reset_password(token, "another-one")

      assert RegisteredNick.verify_password(reload(nick), "a-brand-new-password")
    end

    test "a confirmation token does not change a password", %{nick: nick} do
      confirm = set_email_and_capture(nick, "again@example.com")

      assert {:error, :invalid} = NickEmail.reset_password(confirm, "sneaky-password")
    end

    test "refuses a password the registration rules would refuse", %{nick: nick} do
      verify_and_capture(nick, "short@example.com")
      token = request_reset_and_capture(nick)

      assert {:error, _reason} = NickEmail.reset_password(token, "tiny")
      assert RegisteredNick.verify_password(reload(nick), "password123")
    end
  end

  describe "request_reset/2" do
    # The whole point. A reset form that answered differently for a nickname
    # that exists would be a way to enumerate the register, so the two answers
    # are compared with each other rather than merely both succeeding.
    test "answers a nickname that does not exist exactly as one that does", %{nick: nick} do
      verify_and_capture(nick, "known@example.com")

      known = NickEmail.request_reset(nick, &link/1)
      unknown = NickEmail.request_reset("nobody#{uid()}", &link/1)

      assert known == unknown
      assert known == :ok
    end

    test "a nickname with no address gets the same answer and no message", %{nick: nick} do
      assert NickEmail.request_reset(nick, &link/1) == :ok
      refute_enqueued(worker: MailWorker)
    end

    test "a nickname whose address is unverified gets the same answer and no message", %{
      nick: nick
    } do
      set_email_and_capture(nick, "unverified@example.com")
      before = queued_count()

      assert NickEmail.request_reset(nick, &link/1) == :ok
      assert queued_count() == before
    end

    test "a second request inside the debounce window sends nothing new", %{nick: nick} do
      verify_and_capture(nick, "debounce@example.com")

      before = queued_count()
      assert :ok = NickEmail.request_reset(nick, &link/1)
      assert queued_count() == before + 1
      first = reload(nick).email_token_hash

      assert :ok = NickEmail.request_reset(nick, &link/1)
      assert queued_count() == before + 1
      assert reload(nick).email_token_hash == first
    end
  end

  defp register(nickname) do
    nickname = String.slice(nickname, 0, 16)
    {:ok, _} = Queries.insert_registered_nick(nickname, "password123")
    nickname
  end

  defp reload(nickname), do: Repo.get_by(RegisteredNick, nickname: nickname)

  defp uid, do: System.unique_integer([:positive])

  defp link(token), do: @link_prefix <> token

  defp set_email_and_capture(nickname, address) do
    :ok = NickEmail.set_email(nickname, address, &link/1)
    capture_token()
  end

  defp request_reset_and_capture(nickname) do
    :ok = NickEmail.request_reset(nickname, &link/1)
    capture_token()
  end

  defp verify_and_capture(nickname, address) do
    token = set_email_and_capture(nickname, address)
    {:ok, ^nickname} = NickEmail.verify_email(token)
    token
  end

  # The queued job carries the whole message, so the link can be read from it
  # without the job having run — and without the hash in the row, which is all
  # the database ever holds.
  defp queued do
    assert_enqueued(worker: MailWorker)
    Repo.one!(from job in Oban.Job, order_by: [desc: job.id], limit: 1)
  end

  defp capture_token, do: token_from(queued().args)

  defp queued_count, do: Repo.aggregate(from(job in Oban.Job), :count)

  defp token_from(%{"body" => body}) do
    [_whole, token] = Regex.run(~r{#{@link_prefix}([A-Za-z0-9_\-\.]+)}, body)
    token
  end
end
