defmodule RetroHexChat.Commands.Handler do
  @moduledoc """
  Behaviour that all "/" command handlers must implement.
  """

  @type context :: %{
          nickname: String.t(),
          active_channel: String.t() | nil,
          channels: [String.t()],
          identified: boolean(),
          operator_in: [String.t()],
          half_operator_in: [String.t()]
        }

  @type result ::
          {:ok, :noop}
          | {:ok, :message, map()}
          | {:ok, :action, map()}
          | {:ok, :system, map()}
          | {:ok, :notice, map()}
          | {:ok, :ctcp, map()}
          | {:ok, :join, String.t()}
          | {:ok, :join, String.t(), String.t() | nil}
          | {:ok, :part, String.t(), String.t() | nil}
          | {:ok, :nick_change, String.t()}
          | {:ok, :quit, String.t() | nil}
          | {:ok, :ui_action, atom(), map()}
          | {:error, String.t()}

  @callback execute(args :: [String.t()], context :: context()) :: result()
  @callback validate(raw_args :: String.t()) :: :ok | {:error, String.t()}
  @callback help() :: %{
              name: String.t(),
              syntax: String.t(),
              description: String.t(),
              examples: [String.t()]
            }
end
