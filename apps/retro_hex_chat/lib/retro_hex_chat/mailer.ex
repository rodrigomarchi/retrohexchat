defmodule RetroHexChat.Mailer do
  @moduledoc """
  The one way anything leaves this server by e-mail.

  SMTP rather than a transactional-mail API, because the product is one you host
  yourself: requiring an account with a third party to let somebody recover a
  password would contradict the page that sells it.

  A server with no SMTP configured does not have the feature at all — no reset
  link on the connect screen, no e-mail field in the account window, no expiry
  warning job. `configured?/0` is what every one of those asks, and it is the
  same discipline as TURN and VAPID: a missing secret removes the control rather
  than producing one that fails when pressed.
  """
  use Swoosh.Mailer, otp_app: :retro_hex_chat

  @doc """
  Whether this server can send mail at all.

  True when the adapter is one that needs no credentials (the local preview
  mailbox in dev, the collector in tests) or when SMTP has a relay to talk to.
  """
  @spec configured?() :: boolean()
  def configured? do
    config = Application.get_env(:retro_hex_chat, __MODULE__, [])

    case Keyword.get(config, :adapter) do
      nil -> false
      Swoosh.Adapters.SMTP -> present?(Keyword.get(config, :relay))
      _adapter -> true
    end
  end

  @doc "The address mail from this server is sent from, or `nil` when unset."
  @spec from() :: {String.t(), String.t()} | nil
  def from do
    config = Application.get_env(:retro_hex_chat, __MODULE__, [])
    address = Keyword.get(config, :from_address)
    name = Keyword.get(config, :from_name) || "RetroHexChat"

    if present?(address), do: {name, address}
  end

  defp present?(value), do: is_binary(value) and String.trim(value) != ""
end
