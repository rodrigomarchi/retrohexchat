defmodule RetroHexChat.Accounts.Policy do
  @moduledoc """
  Identity and authorization checks for the Accounts context.
  """

  alias RetroHexChat.Accounts.Session

  @spec identified?(Session.t()) :: boolean()
  def identified?(%Session{identified: identified}), do: identified

  @spec in_channel?(Session.t(), String.t()) :: boolean()
  def in_channel?(%Session{channels: channels}, channel_name) do
    channel_name in channels
  end
end
