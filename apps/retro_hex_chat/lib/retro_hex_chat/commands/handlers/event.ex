defmodule RetroHexChat.Commands.Handlers.Event do
  @moduledoc "Handler for /event — scheduling something the channel will do together"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Duration
  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_args), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  # Bare `/event` opens the list, because "what is coming up" is the question
  # people have most often and it needs no arguments to ask.
  def execute([], _context), do: {:ok, :ui_action, :open_events_dialog, %{}}

  def execute(["cancel"], _context) do
    {:error, dgettext("commands", "Which one? Use /event cancel <id>.")}
  end

  def execute(["cancel", raw_id | _rest], context) do
    with :ok <- in_channel(context),
         {:ok, id} <- parse_id(raw_id) do
      {:ok, :ui_action, :cancel_event, %{channel: context.active_channel, event_id: id}}
    end
  end

  # The time is an offset, never a clock reading. "In two hours" is the same
  # instant for everybody who can read it; "at 20:00" is a different instant for
  # each of them, and a command has no way to ask which one was meant.
  def execute([raw_when | rest], context) do
    with :ok <- in_channel(context),
         {:ok, seconds} <- parse_offset(raw_when),
         {:ok, title} <- parse_title(rest) do
      {:ok, :ui_action, :create_event,
       %{
         channel: context.active_channel,
         starts_in_seconds: seconds,
         title: title
       }}
    end
  end

  defp in_channel(%{active_channel: channel}) when is_binary(channel) and channel != "", do: :ok

  defp in_channel(_context),
    do: {:error, dgettext("commands", "You are not in any channel")}

  defp parse_offset(raw) do
    case Duration.parse(String.trim(raw)) do
      :permanent ->
        {:error, dgettext("commands", "When? Give it as a delay from now, like 2h, 30m or 3d.")}

      seconds when seconds > 0 ->
        {:ok, seconds}

      _zero ->
        {:error, dgettext("commands", "An event has to start later than now.")}
    end
  end

  defp parse_title(parts) do
    case parts |> Enum.join(" ") |> String.trim() do
      "" -> {:error, dgettext("commands", "What is it called? Use /event <when> <title>.")}
      title -> {:ok, title}
    end
  end

  defp parse_id(raw) do
    case Integer.parse(String.trim(raw)) do
      {id, ""} when id > 0 -> {:ok, id}
      _other -> {:error, dgettext("commands", "That is not an event id")}
    end
  end

  @impl true
  @spec help() :: %{
          name: String.t(),
          syntax: String.t(),
          description: String.t(),
          examples: [String.t()]
        }
  def help do
    %{
      name: "event",
      syntax: dgettext("commands", "/event [<when> <title> | cancel <id>]"),
      description:
        dgettext(
          "commands",
          "Schedule something the channel will do together, and announce it in the room.\nThe time is a delay from now — 2h, 30m, 3d — so it means the same instant for everybody reading it.\nEveryone sees the card and can say they are going; whoever said so is reminded shortly before it starts.\nOperators only. With no arguments it opens the Events window."
        ),
      examples: [
        "/event",
        "/event 2h Tuesday tournament",
        "/event 3d Film night in the space",
        "/event cancel 12"
      ]
    }
  end

  @impl true
  def category, do: :channel

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "event",
      syntax: dgettext("commands", "/event [<when> <title> | cancel <id>]"),
      description: dgettext("commands", "Schedule something the channel will do together."),
      category: :channel,
      parameters: [
        %Parameter{
          name: "when",
          required: false,
          type: :text,
          position: 0,
          description: dgettext("commands", "How long from now it starts: 2h, 30m, 3d")
        },
        %Parameter{
          name: "title",
          required: false,
          type: :text,
          position: 1,
          description: dgettext("commands", "What the channel is going to do")
        }
      ],
      examples: ["/event", "/event 2h Tuesday tournament", "/event cancel 12"]
    }
  end
end
