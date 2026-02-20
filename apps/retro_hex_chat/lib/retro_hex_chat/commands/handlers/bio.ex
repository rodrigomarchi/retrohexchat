defmodule RetroHexChat.Commands.Handlers.Bio do
  @moduledoc "Handler for /bio [text|clear]"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @max_bio_graphemes 200

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:ok, :ui_action, :view_bio, %{}}
  end

  def execute(["clear"], _context) do
    {:ok, :ui_action, :clear_bio, %{}}
  end

  def execute(args, _context) do
    text = Enum.join(args, " ")
    grapheme_count = String.length(text)

    if grapheme_count > @max_bio_graphemes do
      truncated = String.slice(text, 0, @max_bio_graphemes)
      {:ok, :ui_action, :set_bio, %{text: truncated, truncated: true}}
    else
      {:ok, :ui_action, :set_bio, %{text: text, truncated: false}}
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
      name: "bio",
      syntax: "/bio [<text>|clear]",
      description:
        "Set a short 'about me' text visible when others look you up with /whois.\nMax 200 characters (text beyond this limit is silently truncated). Use /bio to view, /bio clear to remove.",
      examples: ["/bio Elixir enthusiast from Brazil", "/bio", "/bio clear"]
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
      command: "bio",
      syntax: "/bio [<text>|clear]",
      description: "Set a short 'about me' text visible when others look you up with /whois.",
      category: :basics,
      parameters: [
        %Parameter{
          name: "text",
          required: false,
          type: :text,
          position: 0,
          description: "Bio text (or 'clear' to remove)"
        }
      ],
      examples: ["/bio Elixir enthusiast from Brazil", "/bio", "/bio clear"]
    }
  end
end
