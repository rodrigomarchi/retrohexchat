defmodule RetroHexChat.Jobs.PushDispatchWorker do
  @moduledoc """
  Turns one message into the notifications it actually earned.

  The job is enqueued on the message path, which knows what was written; it is
  performed here, which knows who can still be reached. Those are two different
  moments on purpose: whether somebody has a screen open is a fact with a
  lifetime of seconds, and reading it when the message was written would push
  to a person who was looking at the room at the time.

  Uniqueness carries the other half of the restraint. A room where three people
  are talking at once is one thing happening, and the window collapses it into
  one notification instead of one per line.
  """

  use Oban.Worker,
    queue: :push,
    max_attempts: 3,
    tags: ["push"],
    unique: [
      period: 60,
      keys: [:nickname, :conversation]
    ]

  use RetroHexChat.Jobs.Retry,
    timeout: :timer.seconds(30),
    cap_seconds: 5 * 60,
    step_seconds: 10

  alias RetroHexChat.Notifications
  alias RetroHexChat.Notifications.Schema.PushSubscription
  alias RetroHexChat.Observability
  alias RetroHexChat.Surfaces

  @type outcome ::
          {:ok, %{sent: non_neg_integer(), skipped: non_neg_integer()}}
          | {:cancel, String.t()}

  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: outcome()
  def perform(%Oban.Job{args: args}) do
    Observability.span(
      [:retro_hex_chat, :notifications, :push, :dispatch],
      %{kind: Map.get(args, "kind", "unknown")},
      fn -> dispatch(args) end,
      &dispatch_metadata/1
    )
  end

  @spec dispatch(map()) :: outcome()
  defp dispatch(args) do
    if Notifications.enabled?() do
      args |> recipients() |> deliver_to(args)
    else
      {:cancel, "push_disabled"}
    end
  end

  @spec recipients(map()) :: [PushSubscription.t()]
  defp recipients(%{"kind" => "channel", "conversation" => channel} = args) do
    Notifications.candidates_for_channel_message(channel,
      tokens: Map.get(args, "tokens", []),
      except: Map.get(args, "author", "")
    )
  end

  defp recipients(%{"kind" => "pm", "nickname" => nickname}) do
    Notifications.list_for(nickname)
  end

  defp recipients(_args), do: []

  # The one check that has to happen here and not earlier: somebody who has the
  # product open in any tab has already been told, by sound, by the title, or by
  # a desktop notification. A push on top of that is the product shouting.
  @spec deliver_to([PushSubscription.t()], map()) :: outcome()
  defp deliver_to(subscriptions, args) do
    {reachable, on_screen} =
      Enum.split_with(subscriptions, &(Surfaces.count(&1.owner_nickname) == 0))

    sent =
      Enum.count(reachable, fn subscription ->
        Notifications.deliver(subscription, payload(args, subscription)) == :ok
      end)

    {:ok, %{sent: sent, skipped: length(on_screen)}}
  end

  @spec payload(map(), PushSubscription.t()) :: map()
  defp payload(args, _subscription) do
    conversation = Map.get(args, "conversation", "")

    %{
      title: title(args, conversation),
      body: body(args),
      conversation: conversation
    }
  end

  # A channel notification names the room, because the room is what you would
  # open. A private one names the person, because there is no room.
  @spec title(map(), String.t()) :: String.t()
  defp title(%{"kind" => "channel"}, conversation), do: conversation
  defp title(%{"author" => author}, _conversation), do: author
  defp title(_args, conversation), do: conversation

  @spec body(map()) :: String.t()
  defp body(%{"kind" => "channel", "author" => author} = args) do
    "#{author}: #{Map.get(args, "body", "")}"
  end

  defp body(args), do: Map.get(args, "body", "")

  @spec dispatch_metadata(outcome()) :: map()
  defp dispatch_metadata({:ok, %{sent: sent, skipped: skipped}}) do
    %{result: result_for(sent, skipped), sent_count: sent, skipped_count: skipped}
  end

  defp dispatch_metadata({:cancel, reason}), do: %{result: "cancel", reason: reason}

  @spec result_for(non_neg_integer(), non_neg_integer()) :: String.t()
  defp result_for(0, 0), do: "nobody"
  defp result_for(0, _skipped), do: "on_screen"
  defp result_for(_sent, _skipped), do: "ok"
end
