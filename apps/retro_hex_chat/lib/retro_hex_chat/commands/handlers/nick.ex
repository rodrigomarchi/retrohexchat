defmodule RetroHexChat.Commands.Handlers.Nick do
  @moduledoc "Handler for /nick <newnick>"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  # IRC-style allowed first characters: letters + [\]^_{|}
  @first_char_pattern ~r/^[a-zA-Z\[\]\\^_\{|\}]/
  # Allowed characters: alphanumeric + [\]^_`{|}-
  @valid_nick_pattern ~r/^[a-zA-Z\[\]\\^_\{|\}][a-zA-Z0-9\[\]\\^_`\{|\}\-]*$/

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, "Usage: /nick <newnick>"}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, "Usage: /nick <newnick>"}

  def execute([_ | rest], _context) when rest != [] do
    {:error, "Nickname cannot contain spaces"}
  end

  def execute([new_nick], context) do
    cond do
      new_nick == context.nickname ->
        {:error, "You are already using that nickname"}

      String.length(new_nick) > 16 ->
        {:error, "Nickname too long (max 16 characters)"}

      not Regex.match?(@first_char_pattern, new_nick) ->
        {:error, "Nickname must start with a letter or special character ([\\]^_{|})"}

      not Regex.match?(@valid_nick_pattern, new_nick) ->
        {:error, "Nickname contains invalid characters"}

      true ->
        {:ok, :nick_change, new_nick}
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
      name: "nick",
      syntax: "/nick <newnick>",
      description: "Change your nickname.",
      examples: ["/nick NewNick", "/nick [Bot]"]
    }
  end

  @impl true
  def category, do: :basics

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "nick",
      syntax: "/nick <newnick>",
      description: "Change your nickname.",
      category: :basics,
      parameters: [
        %Parameter{
          name: "newnick",
          required: true,
          type: :nick,
          position: 0,
          description: "Novo nickname (máx 16 caracteres)"
        }
      ],
      examples: ["/nick NewNick", "/nick [Bot]"]
    }
  end
end
