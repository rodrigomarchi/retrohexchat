defmodule RetroHexChat.Jobs.MailWorkerTest do
  @moduledoc """
  The other half of every mail test in this suite.

  Everywhere else asserts on what was *queued*, because that is what the code
  asking for a message decided. This asserts that a queued message is then
  actually sent — without it, every one of those tests would pass on a server
  that never delivered anything.
  """
  use RetroHexChat.DataCase, async: false

  import Swoosh.TestAssertions

  @moduletag :integration

  alias RetroHexChat.Jobs.MailWorker

  test "sends what the job carries" do
    job = %Oban.Job{
      args: %{"to" => "reader@example.com", "subject" => "A subject", "body" => "A body"}
    }

    assert :ok = MailWorker.perform(job)

    assert_email_sent(fn email ->
      assert {_name, "reader@example.com"} = hd(email.to)
      assert email.subject == "A subject"
      assert email.text_body == "A body"
    end)
  end

  test "says so when the server has nowhere to send" do
    original = Application.get_env(:retro_hex_chat, RetroHexChat.Mailer)
    Application.put_env(:retro_hex_chat, RetroHexChat.Mailer, adapter: Swoosh.Adapters.Test)
    on_exit(fn -> Application.put_env(:retro_hex_chat, RetroHexChat.Mailer, original) end)

    job = %Oban.Job{args: %{"to" => "reader@example.com", "subject" => "s", "body" => "b"}}

    assert {:error, _reason} = MailWorker.perform(job)
    refute_email_sent()
  end
end
