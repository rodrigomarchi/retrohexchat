defmodule RetroHexChat.Notifications do
  @moduledoc """
  Reaching somebody who does not have the product open.

  Everything else that tells a person something happened — the sound, the
  flashing title, the desktop notification — needs a live screen to happen on.
  This is the one path that does not, and that is its whole reason to exist:
  a chat only earns a second visit if it can ask for one.

  The cost of being wrong here is asymmetric and it shapes every decision
  below. A notification that should have arrived and did not is a missed
  message. A notification that should not have arrived is the moment somebody
  turns the feature off, and they never turn it back on. So the rule is narrow
  on purpose — a private message, or your own nickname written in a room you
  were in — and every other line on the server is silent.

  A server with no VAPID key pair does not have this feature at all: nothing is
  enqueued, nothing is queried, and the interface offers no control. That is
  the same discipline as TURN, and it matters for the same reason — this
  product is meant to be self-hosted, and a self-hoster must never meet a
  button that cannot work.
  """

  alias RetroHexChat.Chat.Content
  alias RetroHexChat.Jobs.PushDispatchWorker
  alias RetroHexChat.Notifications.Candidates
  alias RetroHexChat.Notifications.Policy
  alias RetroHexChat.Notifications.Queries
  alias RetroHexChat.Notifications.Schema.PushSubscription
  alias RetroHexChat.Notifications.Service

  require Logger

  # A notification is a doorbell, not a message. Anything past this is read in
  # the app, and carrying more of it through a third party's push service is
  # spending somebody's privacy for nothing.
  @max_body_length 140

  @type subscription_params :: %{
          required(:endpoint) => String.t(),
          required(:p256dh) => String.t(),
          required(:auth) => String.t(),
          optional(:user_agent) => String.t() | nil
        }

  @doc "Whether this server can send a push at all."
  @spec enabled?() :: boolean()
  defdelegate enabled?(), to: Service

  @doc """
  The VAPID public key a browser needs in order to subscribe.

  `nil` when the feature is off, which is what the interface reads to decide
  whether the control exists.
  """
  @spec public_key() :: String.t() | nil
  def public_key do
    if enabled?() do
      :web_push_ex |> Application.get_env(:vapid, []) |> Keyword.get(:public_key)
    end
  end

  @doc "Remember one browser for `nickname`."
  @spec subscribe(String.t(), subscription_params()) ::
          {:ok, PushSubscription.t()} | {:error, Ecto.Changeset.t() | :disabled}
  def subscribe(nickname, params) do
    if enabled?(), do: Queries.subscribe(nickname, params), else: {:error, :disabled}
  end

  @doc "Forget one browser of `nickname`'s."
  @spec unsubscribe(String.t(), String.t()) :: :ok
  defdelegate unsubscribe(nickname, endpoint), to: Queries

  @doc "Every browser currently subscribed for `nickname`."
  @spec list_for(String.t()) :: [PushSubscription.t()]
  defdelegate list_for(nickname), to: Queries

  @doc "The subscriptions a channel line should reach."
  @spec candidates_for_channel_message(String.t(), keyword()) :: [PushSubscription.t()]
  defdelegate candidates_for_channel_message(channel_name, opts), to: Queries

  @doc "Send one notification to one subscribed browser."
  @spec deliver(PushSubscription.t(), map()) :: Service.outcome()
  defdelegate deliver(subscription, payload), to: Service

  @doc """
  Consider a channel message for a push, and enqueue one dispatch if it earns it.

  Called from both paths that broadcast a channel message. Never raises and
  never reports: a message is not worth failing to send because a notification
  could not be queued.
  """
  @spec notify_channel_message(map()) :: :ok
  def notify_channel_message(%{channel: channel, author: author} = payload) do
    with true <- enabled?(),
         true <- Policy.notifiable_type?(Map.get(payload, :type)),
         true <- Policy.notifiable_author?(author),
         tokens when tokens != [] <- tokens_of(payload) do
      enqueue(%{
        "kind" => "channel",
        "conversation" => channel,
        "author" => author,
        "tokens" => tokens,
        "body" => body_of(payload)
      })
    else
      _not_worth_it -> :ok
    end
  end

  def notify_channel_message(_payload), do: :ok

  @doc """
  Consider a private message for a push, and enqueue one dispatch if it earns it.

  A private message needs no mention: it was already addressed to exactly one
  person, and that is the strongest signal this module ever gets.
  """
  @spec notify_private_message(map()) :: :ok
  def notify_private_message(%{sender: sender, recipient: recipient} = payload) do
    with true <- enabled?(),
         true <- Policy.notifiable_type?(Map.get(payload, :type)),
         true <- Policy.notifiable_author?(sender) do
      enqueue(%{
        "kind" => "pm",
        "conversation" => "pm:#{sender}",
        "nickname" => recipient,
        "author" => sender,
        "body" => body_of(payload)
      })
    else
      _not_worth_it -> :ok
    end
  end

  def notify_private_message(_payload), do: :ok

  @doc """
  Tells the people who said they would be there that it is about to start.

  Addressed to a list rather than derived from what was written, which is the
  difference between this and every other push here: nobody typed anything, and
  the only reason a person is on the list is that they asked to be. One job per
  person, so the worker's own uniqueness window still collapses a burst.
  """
  @spec notify_event_reminder(map()) :: :ok
  def notify_event_reminder(%{channel: channel, attendees: attendees, body: body})
      when is_list(attendees) do
    if enabled?() do
      Enum.each(attendees, fn nickname ->
        enqueue(%{
          "kind" => "event",
          "conversation" => channel,
          "nickname" => nickname,
          "body" => body
        })
      end)
    end

    :ok
  end

  def notify_event_reminder(_payload), do: :ok

  @spec enqueue(map()) :: :ok
  defp enqueue(args) do
    args
    |> PushDispatchWorker.new()
    |> Oban.insert()
    |> case do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.warning("Push dispatch could not be enqueued: #{inspect(reason)}")
        :ok
    end
  rescue
    error ->
      Logger.warning("Push dispatch could not be enqueued: #{inspect(error)}")
      :ok
  end

  @spec tokens_of(map()) :: [String.t()]
  defp tokens_of(payload) do
    Candidates.nick_tokens(Map.get(payload, :content) || "", content_format(payload))
  end

  @spec body_of(map()) :: String.t()
  defp body_of(payload) do
    payload
    |> Map.get(:content)
    |> Kernel.||("")
    |> plain_text(content_format(payload))
    |> String.slice(0, @max_body_length)
  end

  @spec plain_text(String.t(), Content.format_input()) :: String.t()
  defp plain_text(content, content_format) do
    case Content.normalize_format(content_format) do
      {:ok, normalized} -> Content.plain_text(content, normalized)
      :error -> Content.plain_text(content, :irc)
    end
  end

  @spec content_format(map()) :: Content.format_input()
  defp content_format(payload), do: Map.get(payload, :content_format) || :irc
end
