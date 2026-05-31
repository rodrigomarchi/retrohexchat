defmodule RetroHexChat.Commands.Handlers.AutoJoin do
  @moduledoc "Handler for /autojoin [subcommand] [args]"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: :ok
  def validate("list"), do: :ok
  def validate("clear"), do: :ok

  def validate("add " <> rest) do
    case String.trim(rest) do
      "" ->
        {:error, gettext("Usage: /autojoin add #channel [key]")}

      trimmed ->
        channel = trimmed |> String.split(" ", parts: 2) |> List.first()
        validate_channel_name(channel)
    end
  end

  def validate("add"), do: {:error, gettext("Usage: /autojoin add #channel [key]")}

  def validate("remove " <> rest) do
    case String.trim(rest) do
      "" -> {:error, gettext("Usage: /autojoin remove #channel")}
      channel -> validate_channel_name(channel)
    end
  end

  def validate("remove"), do: {:error, gettext("Usage: /autojoin remove #channel")}

  def validate(args) do
    subcmd = args |> String.split(" ", parts: 2) |> List.first()
    {:error, "Unknown autojoin subcommand: #{subcmd}. Use: list, add, remove, clear"}
  end

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:ok, :ui_action, :open_perform_dialog, %{tab: "autojoin"}}
  end

  def execute(["list"], _context) do
    {:ok, :ui_action, :autojoin_list_display, %{}}
  end

  def execute(["add", channel], _context) do
    {:ok, :ui_action, :autojoin_add, %{channel: channel, key: nil}}
  end

  def execute(["add", channel | key_parts], _context) do
    key = Enum.join(key_parts, " ")
    {:ok, :ui_action, :autojoin_add, %{channel: channel, key: key}}
  end

  def execute(["remove", channel], _context) do
    {:ok, :ui_action, :autojoin_remove, %{channel: channel}}
  end

  def execute(["clear"], _context) do
    {:ok, :ui_action, :autojoin_clear, %{}}
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
      name: "autojoin",
      syntax: gettext("/autojoin [list|add|remove|clear]"),
      description:
        gettext(
          "Set channels to join automatically every time you connect.\nSubcommands: list, add <#channel> [key], remove <#channel>, clear. No args opens the Perform dialog.\nChannel names must start with #. Registered users only."
        ),
      examples: [
        "/autojoin",
        gettext("/autojoin list"),
        gettext("/autojoin add #elixir"),
        gettext("/autojoin add #secret mykey"),
        gettext("/autojoin remove #elixir"),
        gettext("/autojoin clear")
      ]
    }
  end

  @spec validate_channel_name(String.t()) :: :ok | {:error, String.t()}
  defp validate_channel_name(channel) do
    if String.starts_with?(channel, "#") do
      :ok
    else
      {:error, gettext("Channel name must start with #")}
    end
  end

  @impl true
  def category, do: :config

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "autojoin",
      syntax: gettext("/autojoin [list|add|remove|clear]"),
      description: gettext("Set channels to join automatically every time you connect."),
      category: :config,
      parameters: [
        %Parameter{
          name: "subcommand",
          required: false,
          type: :text,
          position: 0,
          description: gettext("Subcommand: list, add, remove, clear")
        },
        %Parameter{
          name: "args",
          required: false,
          type: :text,
          position: 1,
          description: gettext("Subcommand arguments")
        }
      ],
      examples: [
        "/autojoin",
        gettext("/autojoin list"),
        gettext("/autojoin add #elixir"),
        gettext("/autojoin add #secret mykey"),
        gettext("/autojoin remove #elixir"),
        gettext("/autojoin clear")
      ],
      subcommands: [
        %{name: "list", description: gettext("Show your autojoin list")},
        %{name: "add", description: gettext("Add a channel to autojoin")},
        %{name: "remove", description: gettext("Remove a channel from autojoin")},
        %{name: "clear", description: gettext("Clear your entire autojoin list")}
      ]
    }
  end
end
