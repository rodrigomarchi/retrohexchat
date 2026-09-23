defmodule RetroHexChat.Jobs.NickExpiryWarningWorker do
  @moduledoc """
  Tells somebody their nickname is about to be released, while there is still
  time to keep it.

  Releasing a nickname after a long silence is the right rule and a cruel one to
  apply without warning. Anybody who confirmed an address hears about it two
  weeks out.

  Nobody is warned twice, and nothing records who was warned. The window is one
  day wide on `last_seen_at` and this runs daily, so each nickname passes
  through it exactly once — and somebody who comes back leaves the window by
  coming back, which is the outcome the message is asking for.

  A server with no SMTP does not run this at all: `RetroHexChat.Mailer` has
  nowhere to send, so there is nothing to do rather than something to fail at.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["maintenance", "nicks"],
    unique: [
      fields: [:worker, :queue],
      states: :incomplete,
      period: :infinity
    ]

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.minutes(2),
    cap_seconds: 15 * 60,
    step_seconds: 30

  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  alias RetroHexChat.Observability
  alias RetroHexChat.Services.NickEmail
  alias RetroHexChat.Services.NickExpiry

  # Two weeks is long enough to act on and short enough to still be about this
  # nickname rather than about nicknames in general.
  @warning_days 14

  @doc "How long before release the warning goes out."
  @spec warning_days() :: pos_integer()
  def warning_days, do: @warning_days

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, map()}
  def perform(%Oban.Job{}) do
    Observability.span(
      [:retro_hex_chat, :services, :nicks, :expiry_warning],
      %{domain: "maintenance"},
      fn -> warn() end,
      &result_metadata/1
    )
  end

  defp warn do
    if NickEmail.enabled?() do
      {:ok, %{warned: deliver_all(), skipped: false}}
    else
      {:ok, %{warned: 0, skipped: true}}
    end
  end

  defp deliver_all do
    {from, to} = window()

    from
    |> NickEmail.confirmed_between(to)
    |> Enum.count(&warn_one/1)
  end

  # The cohort whose silence puts them exactly `@warning_days` from release: a
  # single day of `last_seen_at`, so a daily run sees each nickname once.
  defp window do
    days = NickExpiry.configured_expiration_days() - @warning_days
    now = DateTime.utc_now()

    {DateTime.add(now, -(days + 1) * 24 * 60 * 60, :second),
     DateTime.add(now, -days * 24 * 60 * 60, :second)}
  end

  defp warn_one(nick) do
    days = @warning_days

    result =
      NickEmail.deliver(
        nick.email,
        dgettext("services", "Your RetroHexChat nickname is about to be released"),
        dgettext(
          "services",
          "The nickname %{nickname} has not been used for a while, and nicknames left unused are released so somebody else can take them.\n\nSigning in once keeps it — nothing else is needed, and you have about %{days} days.\n\nIf you would rather let it go, ignore this message.",
          nickname: nick.nickname,
          days: days
        )
      )

    case result do
      :ok ->
        true

      {:error, reason} ->
        Logger.warning("Could not warn #{nick.nickname} about expiry: #{inspect(reason)}")
        false
    end
  end

  defp result_metadata({:ok, result}) do
    %{result: "ok", warned: result.warned, skipped: result.skipped}
  end
end
