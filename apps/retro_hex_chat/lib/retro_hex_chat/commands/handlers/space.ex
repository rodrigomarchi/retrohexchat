defmodule RetroHexChat.Commands.Handlers.Space do
  @moduledoc """
  Handler for `/space [#channel] [name] [ttl=2h]` — create a virtual space
  linked to a channel and publish its invite card there.
  """
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Duration
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.VirtualSpace

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(args, context) do
    with :ok <- validate_identified(context),
         :ok <- validate_channel_origin(context),
         {:ok, parsed} <- parse_args(args),
         {:ok, creator_id} <- resolve_registered_nick(context.nickname),
         {:ok, result} <-
           create_session(context, creator_id, parsed) do
      {:ok, :ui_action, :space_invite,
       %{
         target: parsed.target || context.active_channel,
         token: result.token,
         title: result.session.title,
         creator_id: creator_id
       }}
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
      name: "space",
      syntax: dgettext("commands", "/space [#channel] [name] [ttl=2h]"),
      description:
        dgettext(
          "commands",
          "Create a virtual space: a multiplayer 8-bit office linked to a channel, where up to 20 people walk around, sit and chat. Posts an invite card in the channel.\nRequires: you must be registered and identified (/ns identify)."
        ),
      examples: [
        dgettext("commands", "/space"),
        dgettext("commands", "/space #general"),
        dgettext("commands", "/space #general Guild Tavern ttl=4h")
      ]
    }
  end

  @impl true
  def category, do: :user

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "space",
      syntax: dgettext("commands", "/space [#channel] [name] [ttl=2h]"),
      description:
        dgettext(
          "commands",
          "Create a multiplayer virtual space linked to a channel and post its invite card there.\nRequires: you must be registered and identified (/ns identify)."
        ),
      category: :user,
      parameters: [
        %Parameter{
          name: "channel",
          required: false,
          type: :channel,
          position: 0,
          description: dgettext("commands", "Target channel (defaults to the active channel)")
        },
        %Parameter{
          name: "name",
          required: false,
          type: :text,
          position: 1,
          description: dgettext("commands", "Space name")
        },
        %Parameter{
          name: "ttl",
          required: false,
          type: :text,
          position: 2,
          description: dgettext("commands", "Lifetime, e.g. ttl=2h (max 8h)")
        }
      ],
      examples: [
        dgettext("commands", "/space"),
        dgettext("commands", "/space #general Guild Tavern ttl=4h")
      ]
    }
  end

  # --- Private helpers ---

  defp validate_identified(%{identified: true}), do: :ok

  defp validate_identified(_),
    do: {:error, dgettext("commands", "You must be identified to use /space.")}

  defp validate_channel_origin(%{active_channel: "#" <> _}), do: :ok

  defp validate_channel_origin(_) do
    {:error,
     dgettext("commands", "/space only works from a channel, not from PMs or the Status window.")}
  end

  defp parse_args(args) do
    {target, rest} =
      case args do
        ["#" <> _ = channel | rest] -> {channel, rest}
        rest -> {nil, rest}
      end

    {ttl_tokens, title_words} = Enum.split_with(rest, &String.starts_with?(&1, "ttl="))
    title = if title_words == [], do: nil, else: Enum.join(title_words, " ")

    with {:ok, ttl_ms} <- parse_ttl(ttl_tokens) do
      {:ok, %{target: target, title: title, ttl_ms: ttl_ms}}
    end
  end

  defp parse_ttl([]), do: {:ok, nil}

  defp parse_ttl(["ttl=" <> value]) do
    case Duration.parse(value) do
      seconds when is_integer(seconds) and seconds > 0 -> {:ok, seconds * 1000}
      _ -> {:error, ttl_usage_error()}
    end
  end

  defp parse_ttl(_), do: {:error, ttl_usage_error()}

  defp ttl_usage_error do
    dgettext("commands", "Invalid ttl. Use ttl=<duration>, e.g. ttl=2h (max 8h).")
  end

  defp resolve_registered_nick(nickname) do
    case RetroHexChat.Repo.get_by(RegisteredNick, nickname: nickname) do
      nil -> {:error, dgettext("commands", "You must be registered to use /space.")}
      nick -> {:ok, nick.id}
    end
  end

  defp create_session(context, creator_id, parsed) do
    actor = %{
      user_id: creator_id,
      nickname: context.nickname,
      identified: context.identified,
      is_admin: context.is_admin,
      is_server_operator: context.is_server_operator
    }

    channel = parsed.target || context.active_channel
    opts = %{title: parsed.title, ttl_ms: parsed.ttl_ms}

    case VirtualSpace.create_session(actor, channel, opts) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, error_message(reason, channel)}
    end
  end

  defp error_message({:rate_limited, seconds}, _channel) do
    dgettext("commands", "Too many spaces created. Try again in %{seconds} seconds.",
      seconds: seconds
    )
  end

  defp error_message(:ttl_too_long, _channel),
    do: dgettext("commands", "ttl exceeds the maximum lifetime of 8h.")

  defp error_message(:cannot_post, channel),
    do:
      dgettext("commands", "You need permission to post in %{channel} to create a space there.",
        channel: channel
      )

  defp error_message(:invalid_origin, _channel),
    do: dgettext("commands", "/space only works from a channel.")

  defp error_message(:registration_required, _channel),
    do: dgettext("commands", "You must be registered to use /space.")

  defp error_message(:not_identified, _channel),
    do: dgettext("commands", "You must be identified to use /space.")

  defp error_message(_other, _channel),
    do: dgettext("commands", "Could not create the space. Try again.")
end
