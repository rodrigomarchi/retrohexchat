defmodule RetroHexChat.Jobs.EventReminderWorker do
  @moduledoc """
  Tells a channel that something it agreed to do is about to start.

  It sweeps rather than scheduling a job per event on purpose. An event can be
  cancelled or moved, and a job already sitting in the queue for a row that has
  since changed is the classic way a reminder arrives for something that is not
  happening. Reading the rows at the moment of reminding means the database is
  always the answer.

  Two deliveries, both of which already existed: the room hears it as a line,
  because everybody in it may want to know; and each person who said they would
  be there gets a push, because they are the ones who asked to be told. Nothing
  here is a notification channel of its own.

  `reminded_at` is what stops the next sweep finding the same event. It is
  written after the deliveries rather than before, so a crash mid-sweep repeats
  a reminder instead of silently eating it — the same trade every at-least-once
  worker here makes.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    tags: ["maintenance", "events"],
    unique: [
      fields: [:worker, :queue],
      states: :incomplete,
      period: 60
    ]

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.minutes(1),
    cap_seconds: 15 * 60,
    step_seconds: 60

  alias RetroHexChat.Channels.ScheduledEvents
  alias RetroHexChat.Jobs.ResultMetadata
  alias RetroHexChat.Jobs.WorkerArgs
  alias RetroHexChat.Notifications
  alias RetroHexChat.Observability
  alias RetroHexChat.Topics

  use Gettext, backend: RetroHexChat.Gettext

  require Logger

  # Long enough to be worth interrupting somebody for, short enough that they
  # can still get there.
  @default_window_seconds 900

  @pubsub RetroHexChat.PubSub

  @type summary :: %{reminded: non_neg_integer(), notified: non_neg_integer()}

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: {:ok, summary()} | {:error, term()}
  def perform(%Oban.Job{args: args}) do
    window = WorkerArgs.positive_integer(args, "window_seconds", @default_window_seconds)

    Observability.span(
      [:retro_hex_chat, :channels, :events, :remind],
      %{window_seconds: window},
      fn -> remind(DateTime.utc_now(), window) end,
      &remind_result_metadata/1
    )
  end

  @doc """
  The sweep itself, so a test can drive it at an instant of its choosing.

  Returns how many events were announced and how many people were pushed.
  """
  @spec remind(DateTime.t(), pos_integer()) :: {:ok, summary()}
  def remind(%DateTime{} = now, window_seconds) do
    events = ScheduledEvents.due_for_reminder(now, window_seconds)

    notified = Enum.reduce(events, 0, fn event, acc -> acc + announce(event) end)

    ScheduledEvents.mark_reminded(Enum.map(events, & &1.id), now)

    if events != [] do
      Logger.info("event_reminder_sweep events=#{length(events)} notified=#{notified}")
    end

    {:ok, %{reminded: length(events), notified: notified}}
  end

  @spec announce(ScheduledEvents.card() | struct()) :: non_neg_integer()
  defp announce(event) do
    attendees = ScheduledEvents.attendees(event.id)

    Phoenix.PubSub.broadcast(
      @pubsub,
      Topics.channel(event.channel_name),
      {:event_reminder, ScheduledEvents.card(event)}
    )

    Notifications.notify_event_reminder(%{
      channel: event.channel_name,
      attendees: attendees,
      body: dgettext("chat", "%{title} is about to start.", title: event.title)
    })

    length(attendees)
  end

  @spec remind_result_metadata({:ok, summary()} | {:error, term()}) :: map()
  defp remind_result_metadata({:ok, summary}) do
    %{result: "ok", reminded_count: summary.reminded, notified_count: summary.notified}
  end

  defp remind_result_metadata({:error, reason}), do: ResultMetadata.error(reason)
end
