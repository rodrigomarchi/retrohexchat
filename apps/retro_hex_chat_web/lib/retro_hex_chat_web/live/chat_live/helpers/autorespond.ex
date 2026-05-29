defmodule RetroHexChatWeb.ChatLive.Helpers.Autorespond do
  @moduledoc """
  Auto-respond rule execution with cooldown management.
  """

  import Phoenix.Component, only: [assign: 2]

  alias RetroHexChat.Chat.{AliasExpander, AutoRespondRules}

  @spec maybe_fire_autorespond(
          Phoenix.LiveView.Socket.t(),
          atom(),
          String.t() | nil,
          String.t() | nil,
          function()
        ) :: Phoenix.LiveView.Socket.t()
  def maybe_fire_autorespond(socket, _event_type, _channel, nil, _dispatch_fn), do: socket

  def maybe_fire_autorespond(socket, event_type, channel, triggering_nick, dispatch_fn) do
    session = socket.assigns.session

    if triggering_nick == session.nickname do
      socket
    else
      rules = AutoRespondRules.matching_rules(session.autorespond_rules, event_type, channel)
      now = System.monotonic_time(:second)

      Enum.reduce(rules, socket, fn rule, acc ->
        fire_rule(rule, acc, triggering_nick, channel, now, dispatch_fn)
      end)
    end
  end

  @spec fire_rule(
          map(),
          Phoenix.LiveView.Socket.t(),
          String.t(),
          String.t() | nil,
          integer(),
          function()
        ) :: Phoenix.LiveView.Socket.t()
  def fire_rule(rule, socket, triggering_nick, channel, now, dispatch_fn) do
    cooldown_key = {rule.id, triggering_nick}
    cooldowns = socket.assigns.autorespond_cooldowns
    last_fired = Map.get(cooldowns, cooldown_key)

    if last_fired && now - last_fired < 60 do
      socket
    else
      execute_autorespond(socket, rule, triggering_nick, channel, cooldown_key, now, dispatch_fn)
    end
  end

  @doc """
  Execute an auto-respond rule. Requires `dispatch_command_fn` — a function
  `(socket, session, cmd_name, args) -> socket` — to avoid circular deps
  with the command dispatch module. ChatLive passes its own `dispatch_command/4`.
  """
  @spec execute_autorespond(
          Phoenix.LiveView.Socket.t(),
          map(),
          String.t(),
          String.t() | nil,
          term(),
          integer(),
          function()
        ) :: Phoenix.LiveView.Socket.t()
  def execute_autorespond(
        socket,
        rule,
        triggering_nick,
        channel,
        cooldown_key,
        now,
        dispatch_command_fn
      ) do
    context = %{nick: triggering_nick, chan: channel || ""}
    expanded = AliasExpander.expand(rule.command, [], context)

    alias RetroHexChat.Commands.Parser

    case Parser.parse(expanded) do
      {:command, cmd_name, args} ->
        socket
        |> assign(
          autorespond_cooldowns: Map.put(socket.assigns.autorespond_cooldowns, cooldown_key, now)
        )
        |> dispatch_command_fn.(socket.assigns.session, cmd_name, args)

      _ ->
        socket
    end
  end
end
