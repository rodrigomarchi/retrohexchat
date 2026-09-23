defmodule RetroHexChat.Notifications.Service do
  @moduledoc """
  Encrypts one notification and hands it to a browser's push service.

  Two things are decided here and nowhere else.

  The first is whether the feature exists at all. A server with no VAPID key
  pair cannot sign a push, and rather than letting that surface as a failure per
  message it is read once, up front, by `enabled?/0` — which is also what the
  interface asks before drawing a control. A self-hoster who never generated
  keys gets a product without the feature, not a product with a broken button.

  The second is what a push service's answer means for the row that produced it.
  The answer is an HTTP status and nothing else, so it is the only evidence
  there is: 404 and 410 are the service saying this browser is gone, and the row
  goes with it; anything else is an afternoon, and the row survives a bounded
  number of them. Deleting too eagerly costs somebody their notifications with
  no way to notice; never deleting costs every message a lookup forever.

  What crosses the wire is encrypted end to end for the browser, and the push
  service — Google's, Mozilla's, Apple's — sees only its own endpoint and a
  block of ciphertext.
  """

  alias RetroHexChat.Notifications.Queries
  alias RetroHexChat.Notifications.Schema.PushSubscription
  alias RetroHexChat.Observability

  require Logger

  @gone_statuses [404, 410]

  @type outcome :: :ok | {:error, :gone | :transient | :disabled}

  @doc "Whether this server has the keys to sign a push at all."
  @spec enabled?() :: boolean()
  def enabled? do
    vapid = Application.get_env(:web_push_ex, :vapid, [])

    Enum.all?([:public_key, :private_key, :subject], fn key ->
      present?(Keyword.get(vapid, key))
    end)
  end

  @doc """
  Send `payload` to one subscribed browser, recording what the answer means.
  """
  @spec deliver(PushSubscription.t(), map()) :: outcome()
  def deliver(subscription, payload) do
    if enabled?() do
      Observability.span(
        [:retro_hex_chat, :notifications, :push, :deliver],
        %{"push.host" => endpoint_host(subscription.endpoint)},
        fn -> post(subscription, payload) end,
        &deliver_metadata/1
      )
    else
      {:error, :disabled}
    end
  end

  @spec post(PushSubscription.t(), map()) :: outcome()
  defp post(subscription, payload) do
    case build(subscription, payload) do
      {:ok, request} ->
        [
          url: URI.to_string(request.endpoint),
          headers: request.headers,
          body: request.body,
          receive_timeout: 10_000,
          retry: false
        ]
        |> Keyword.merge(request_overrides())
        |> Req.post()
        |> classify(subscription)

      :error ->
        record_failure(subscription)
    end
  end

  # The browser's own key material is the one input here that this server did
  # not produce, and a row carrying a truncated or re-encoded key makes the
  # encryption raise rather than return. That is this subscription's problem,
  # not the message's, so it is counted against the row like any other failure.
  @spec build(PushSubscription.t(), map()) :: {:ok, WebPushEx.Request.t()} | :error
  defp build(subscription, payload) do
    {:ok, WebPushEx.request(web_push_subscription(subscription), Jason.encode!(payload))}
  rescue
    error ->
      Logger.warning("Web push could not be encrypted: #{inspect(error)}")
      :error
  end

  @spec classify({:ok, Req.Response.t()} | {:error, term()}, PushSubscription.t()) :: outcome()
  defp classify({:ok, %Req.Response{status: status}}, subscription) when status in 200..299 do
    Queries.record_success(subscription)
    :ok
  end

  defp classify({:ok, %Req.Response{status: status}}, subscription)
       when status in @gone_statuses do
    :ok = Queries.drop(subscription)
    {:error, :gone}
  end

  defp classify({:ok, %Req.Response{status: status}}, subscription) do
    Logger.warning("Web push endpoint answered #{status}")
    record_failure(subscription)
  end

  defp classify({:error, reason}, subscription) do
    Logger.warning("Web push endpoint unreachable: #{inspect(reason)}")
    record_failure(subscription)
  end

  @spec record_failure(PushSubscription.t()) :: outcome()
  defp record_failure(subscription) do
    Queries.record_failure(subscription)
    {:error, :transient}
  end

  @spec web_push_subscription(PushSubscription.t()) :: WebPushEx.Subscription.t()
  defp web_push_subscription(subscription) do
    %WebPushEx.Subscription{
      endpoint: URI.parse(subscription.endpoint),
      keys: %{p256dh: subscription.p256dh, auth: subscription.auth}
    }
  end

  @spec deliver_metadata(outcome()) :: map()
  defp deliver_metadata(:ok), do: %{result: "ok"}
  defp deliver_metadata({:error, reason}), do: %{result: "error", reason: Atom.to_string(reason)}

  @spec endpoint_host(String.t()) :: String.t()
  defp endpoint_host(endpoint) do
    case URI.parse(endpoint) do
      %URI{host: host} when is_binary(host) -> host
      _ -> "unknown"
    end
  end

  @spec request_overrides() :: keyword()
  defp request_overrides do
    Application.get_env(:retro_hex_chat, :push_req_options, [])
  end

  @spec present?(term()) :: boolean()
  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end
