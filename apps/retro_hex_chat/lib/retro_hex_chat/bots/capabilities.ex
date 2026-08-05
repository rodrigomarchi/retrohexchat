defmodule RetroHexChat.Bots.Capabilities do
  @moduledoc """
  The catalog of capability modules, keyed by the name stored on a bot.

  One map for every reader. The dispatcher resolves a stored key to the module
  that answers messages; the management window resolves the same key to the
  module's own name and description. Kept apart, the two drift — the window ends
  up captioning capabilities the runtime no longer has, or naming them
  differently.
  """

  alias RetroHexChat.Bots.Capabilities.{CustomCommands, Dice, Game, Greeter, Help, LLM}
  alias RetroHexChat.Bots.Capabilities.{Mention, Moderation, RSS, Scheduler, Script, Trivia}

  @modules %{
    mention: Mention,
    greeter: Greeter,
    custom_commands: CustomCommands,
    help: Help,
    llm: LLM,
    script: Script,
    game: Game,
    scheduler: Scheduler,
    moderation: Moderation,
    rss: RSS,
    trivia: Trivia,
    dice: Dice
  }

  # `game`, `llm` and `script` are declared but unwritten: `handle_message`
  # returns `:ignore` and `commands` returns `[]`. They resolve like any other
  # capability, and the UI says so rather than presenting them as working.
  @stubs [:game, :llm, :script]

  @spec modules() :: %{atom() => module()}
  def modules, do: @modules

  @doc """
  The module implementing `name`, or `nil` for a name nothing implements.

  Accepts the stored string form as well as the atom, and never creates an atom
  from it — an unknown capability name in the database resolves to `nil`.
  """
  @spec module_for(atom() | String.t()) :: module() | nil
  def module_for(name) when is_atom(name), do: Map.get(@modules, name)

  def module_for(name) when is_binary(name) do
    case Enum.find(@modules, fn {key, _module} -> Atom.to_string(key) == name end) do
      {_key, module} -> module
      nil -> nil
    end
  end

  @doc "The capability's own one-line description, or `nil` if nothing implements it."
  @spec describe(atom() | String.t()) :: String.t() | nil
  def describe(name) do
    case module_for(name) do
      nil -> nil
      module -> module.description()
    end
  end

  @doc "Whether the capability is a declared stub rather than a working one."
  @spec stub?(atom() | String.t()) :: boolean()
  def stub?(name) when is_atom(name), do: name in @stubs

  def stub?(name) when is_binary(name) do
    Enum.any?(@stubs, &(Atom.to_string(&1) == name))
  end
end
