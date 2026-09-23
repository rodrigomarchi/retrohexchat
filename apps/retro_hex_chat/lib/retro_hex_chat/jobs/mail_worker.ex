defmodule RetroHexChat.Jobs.MailWorker do
  @moduledoc """
  Sends one message, away from whoever asked for it.

  SMTP is a conversation with another server, and it takes as long as that
  server takes. Doing it inside a LiveView event would hold the socket for the
  whole round trip — somebody pressing "I forgot my password" would watch the
  page do nothing — so the request stores what it decided and hands the sending
  over here.

  Retried, because a relay that is briefly unreachable is the ordinary case and
  the person is waiting on the other side of it.
  """

  use Oban.Worker,
    queue: :mail,
    max_attempts: 5,
    tags: ["mail"]

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.minutes(2),
    cap_seconds: 10 * 60,
    step_seconds: 30

  alias RetroHexChat.Observability
  alias RetroHexChat.Services.NickEmail

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: :ok | {:error, term()}
  def perform(%Oban.Job{args: %{"to" => to, "subject" => subject, "body" => body}}) do
    Observability.span(
      [:retro_hex_chat, :mail, :deliver],
      %{domain: "mail"},
      fn -> NickEmail.deliver(to, subject, body) end
    )
  end
end
