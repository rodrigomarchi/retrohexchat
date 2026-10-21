defmodule RetroHexChat.Bots.Capabilities.Game do
  use Gettext, backend: RetroHexChat.Gettext

  @moduledoc """
  Makes a bot the voice of the Retro Games in its rooms.

  Nothing in a channel triggers it: a finished match does. `Games.Announcer`
  asks which bot in a room carries this capability and says the match — the
  weekly challenge and the daily digest too — under that bot's name. A room
  with no such bot hears nothing about its games, which is how an operator
  turns the announcements off: `/bot set <bot> game_announce off`, or
  `/bot part`.
  """
  @behaviour RetroHexChat.Bots.Capability

  @impl true
  @spec name() :: atom()
  def name, do: :game

  @impl true
  @spec description() :: String.t()
  def description,
    do: dgettext("bots", "Announces Retro Games matches, rankings and the weekly challenge")

  @impl true
  @spec handle_message(String.t(), String.t(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_message(_content, _author, _ctx), do: :ignore

  @impl true
  @spec handle_event(atom(), map(), RetroHexChat.Bots.Capability.bot_context()) ::
          RetroHexChat.Bots.Capability.capability_result()
  def handle_event(_event, _payload, _ctx), do: :ignore

  @impl true
  @spec default_config() :: map()
  def default_config, do: %{"enabled" => true}

  @impl true
  @spec validate_config(map()) :: :ok | {:error, String.t()}
  def validate_config(_config), do: :ok

  @impl true
  @spec commands() :: [%{trigger: String.t(), description: String.t()}]
  def commands, do: []
end
