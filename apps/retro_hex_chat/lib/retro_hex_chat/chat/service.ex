defmodule RetroHexChat.Chat.Service do
  @moduledoc """
  Orchestrates message sending: policy check -> persist -> PubSub broadcast.
  """

  alias RetroHexChat.Chat.{Policy, Queries}

  @spec send_message(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, RetroHexChat.Chat.Message.t()} | {:error, String.t()}
  def send_message(channel_name, nickname, content, type \\ "message") do
    with :ok <- Policy.validate_content(content),
         {:ok, message} <-
           Queries.insert_message(%{
             channel_name: channel_name,
             author_nickname: nickname,
             content: content,
             type: type
           }) do
      broadcast_message(channel_name, message)
      {:ok, message}
    end
  end

  @spec send_system_message(String.t(), String.t()) ::
          {:ok, RetroHexChat.Chat.Message.t()} | {:error, any()}
  def send_system_message(channel_name, content) do
    case Queries.insert_message(%{
           channel_name: channel_name,
           author_nickname: "System",
           content: content,
           type: "system"
         }) do
      {:ok, message} ->
        broadcast_message(channel_name, message)
        {:ok, message}

      {:error, _} = err ->
        err
    end
  end

  @spec send_private_message(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, RetroHexChat.Chat.PrivateMessage.t()} | {:error, String.t()}
  def send_private_message(sender, recipient, content, type \\ "message") do
    with :ok <- Policy.validate_content(content),
         {:ok, pm} <-
           Queries.insert_private_message(%{
             sender_nickname: sender,
             recipient_nickname: recipient,
             content: content,
             type: type
           }) do
      broadcast_private_message(sender, recipient, pm)
      {:ok, pm}
    end
  end

  defp broadcast_private_message(sender, recipient, pm) do
    topic = "pm:#{pm_topic(sender, recipient)}"

    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      topic,
      %{
        event: "new_pm",
        payload: %{
          sender: pm.sender_nickname,
          recipient: pm.recipient_nickname,
          content: pm.content,
          type: String.to_existing_atom(pm.type),
          timestamp: pm.inserted_at,
          id: pm.id
        }
      }
    )
  end

  defp pm_topic(nick_a, nick_b) do
    [nick_a, nick_b] |> Enum.sort() |> Enum.join(":")
  end

  defp broadcast_message(channel_name, message) do
    Phoenix.PubSub.broadcast(
      RetroHexChat.PubSub,
      "channel:#{channel_name}",
      %{
        event: "new_message",
        payload: %{
          channel: channel_name,
          author: message.author_nickname,
          content: message.content,
          type: String.to_existing_atom(message.type),
          timestamp: message.inserted_at,
          id: message.id
        }
      }
    )
  end
end
