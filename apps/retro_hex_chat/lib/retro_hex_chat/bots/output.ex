defmodule RetroHexChat.Bots.Output do
  @moduledoc """
  Delivery boundary for bot-produced messages.

  Bot capabilities and background workers both produce the same output maps.
  Keeping delivery here prevents job workers from duplicating chat/channel
  details that belong to the bot platform.
  """

  alias RetroHexChat.Bots.Pace
  alias RetroHexChat.Channels

  require Logger

  @pubsub RetroHexChat.PubSub

  @doc "Deliver one output map to its target channel or private notice target."
  @spec send(String.t(), String.t(), map()) :: :ok | {:error, term()}
  def send(channel, nickname, %{delivery: delivery, content: content} = output) do
    opts = output_message_opts(output)

    case normalize_delivery(delivery) do
      :public ->
        send_message(channel, nickname, content, output_message_type(output, :message), opts)

      :channel_notice ->
        send_message(channel, nickname, content, output_message_type(output, :notice), opts)

      :private_notice ->
        send_private_notice(channel, nickname, Map.get(output, :target), content)

      :silent ->
        :ok
    end
  end

  def send(_channel, _nickname, _output), do: :ok

  @doc """
  Deliver many output maps to the same channel, at a pace a reader tolerates.

  Sending them in a tight loop is what auto-ignored the wire bots: flood
  protection runs in each reader's session and silences a nickname that sends
  more than its threshold inside the window. `Pace` decides the gap, keyed by
  nickname so a bot's feeds cannot each be polite and still add up to a flood.

  The sleep happens here, in the caller — an Oban worker — which is what makes
  it backpressure rather than bookkeeping: while a bot is drip-feeding a batch,
  it holds one slot, and every other bot keeps its own.
  """
  @spec send_many(String.t(), String.t(), [map()]) :: :ok | {:error, term()}
  def send_many(channel, nickname, outputs) do
    Enum.reduce_while(outputs, :ok, fn output, :ok ->
      # The first message of a batch waits too. A bot that just published on
      # another feed has a slot pending, and skipping the reservation here is
      # exactly the case that trips the reader's counter.
      Process.sleep(Pace.reserve(nickname))

      case send(channel, nickname, output) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @spec normalize_delivery(atom() | String.t()) ::
          :public | :channel_notice | :private_notice | :silent
  defp normalize_delivery(:channel_notice), do: :channel_notice
  defp normalize_delivery(:private_notice), do: :private_notice
  defp normalize_delivery(:silent), do: :silent
  defp normalize_delivery(delivery) when is_atom(delivery), do: :public

  defp normalize_delivery(delivery) when is_binary(delivery) do
    case delivery do
      "channel_notice" -> :channel_notice
      "private_notice" -> :private_notice
      "silent" -> :silent
      _ -> :public
    end
  end

  defp normalize_delivery(_delivery), do: :public

  @spec output_message_opts(map()) :: keyword()
  defp output_message_opts(output) do
    case Map.get(output, :content_format) || Map.get(output, "content_format") do
      format when format in ~w(irc markdown plain) -> [content_format: format]
      _ -> []
    end
  end

  @spec output_message_type(map(), atom()) :: atom()
  defp output_message_type(output, default) do
    case Map.get(output, :type) || Map.get(output, "type") do
      type when type in [nil, "", :""] -> default
      type when is_atom(type) -> type
      type when is_binary(type) -> binary_message_type(type, default)
      _ -> default
    end
  rescue
    ArgumentError -> default
  end

  @spec binary_message_type(String.t(), atom()) :: atom()
  defp binary_message_type(type, default) do
    case String.trim(type) do
      "" -> default
      normalized -> String.to_existing_atom(normalized)
    end
  end

  @spec send_message(String.t(), String.t(), String.t(), atom(), keyword()) ::
          :ok | {:error, term()}
  defp send_message(channel, nickname, content, type, opts) do
    case Channels.Server.send_message(channel, nickname, content, type, opts) do
      {:ok, _id} ->
        :ok

      {:error, reason} ->
        Logger.warning("Bot #{nickname} failed to send: #{inspect(reason)}")
        {:error, reason}
    end
  catch
    :exit, reason ->
      Logger.warning("Bot #{nickname} failed to send (channel unavailable): #{inspect(reason)}")
      {:error, reason}
  end

  @spec send_private_notice(String.t(), String.t(), String.t() | nil, String.t()) ::
          :ok | {:error, term()}
  defp send_private_notice(_channel, _nickname, nil, _content), do: :ok

  defp send_private_notice(channel, nickname, target, content) do
    case Phoenix.PubSub.broadcast(@pubsub, "user:#{target}", %{
           event: "new_notice",
           payload: %{author: nickname, content: content, channel: channel}
         }) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Bot #{nickname} failed to send private notice: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
