defmodule RetroHexChat.Commands.Handler do
  @moduledoc """
  Behaviour that all "/" command handlers must implement.
  """

  @type context :: %{
          required(:nickname) => String.t(),
          required(:active_channel) => String.t() | nil,
          required(:channels) => [String.t()],
          required(:identified) => boolean(),
          required(:owner_in) => [String.t()],
          required(:operator_in) => [String.t()],
          required(:half_operator_in) => [String.t()],
          required(:is_admin) => boolean(),
          required(:is_server_operator) => boolean(),
          optional(:show_status_tab) => boolean()
        }

  @type result ::
          {:ok, :noop}
          | {:ok, :message, map()}
          | {:ok, :action, map()}
          | {:ok, :system, map()}
          | {:ok, :notice, map()}
          | {:ok, :join, String.t()}
          | {:ok, :join, String.t(), String.t() | nil}
          | {:ok, :part, String.t(), String.t() | nil}
          | {:ok, :nick_change, String.t()}
          | {:ok, :quit, String.t() | nil}
          | {:ok, :ui_action, atom(), map()}
          | {:error, String.t()}

  @type category :: :basics | :channel | :user | :config | :advanced

  @callback execute(args :: [String.t()], context :: context()) :: result()
  @callback validate(raw_args :: String.t()) :: :ok | {:error, String.t()}
  @callback help() :: %{
              name: String.t(),
              syntax: String.t(),
              description: String.t(),
              examples: [String.t()]
            }
  @callback category() :: category()
  @callback syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t() | nil

  @optional_callbacks [category: 0, syntax_definition: 0]
end
