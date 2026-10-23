defmodule RetroHexChat.Commands.Handler do
  @moduledoc """
  Behaviour that all "/" command handlers must implement.

  A handler declares its command once and writes only `execute/2` (and
  `validate/1` when it checks raw arguments):

      use RetroHexChat.Commands.Handler,
        name: "op",
        category: :channel,
        syntax: dgettext("commands", "/op <nickname>"),
        summary: dgettext("commands", "Give channel operator status to a user."),
        description: dgettext("commands", "Give channel operator status ..."),
        examples: [dgettext("commands", "/op alice")],
        parameters: [%Parameter{name: "nickname", required: true, type: :nick, position: 0,
                                description: dgettext("commands", "User to give operator status")}]

  From that it answers `help/0` (the `/help` page: `description` is the long
  text), `category/0` and `syntax_definition/0` (the tooltip: `summary` is the
  short text), and `validate/1` accepts anything unless the handler defines
  its own. Every text is an expression evaluated when asked for, so it is
  translated into the reader's language at that moment. Optional:
  `parameters` (default `[]`), `sub_options`, `subcommands`, and
  `tooltip_examples` when the tooltip shows fewer examples than `/help`.
  """

  @doc false
  defmacro __using__(opts) do
    name = Keyword.fetch!(opts, :name)
    category = Keyword.fetch!(opts, :category)
    syntax = Keyword.fetch!(opts, :syntax)
    summary = Keyword.fetch!(opts, :summary)
    description = Keyword.fetch!(opts, :description)
    examples = Keyword.fetch!(opts, :examples)
    parameters = Keyword.get(opts, :parameters, [])
    sub_options = Keyword.get(opts, :sub_options)
    subcommands = Keyword.get(opts, :subcommands)
    tooltip_examples = Keyword.get(opts, :tooltip_examples, examples)

    quote do
      @behaviour RetroHexChat.Commands.Handler

      @impl true
      @spec validate(String.t()) :: :ok | {:error, String.t()}
      def validate(_raw_args), do: :ok
      defoverridable validate: 1

      @impl true
      def help do
        %{
          name: unquote(name),
          syntax: unquote(syntax),
          description: unquote(description),
          examples: unquote(examples)
        }
      end

      @impl true
      def category, do: unquote(category)

      @impl true
      @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
      def syntax_definition do
        %RetroHexChat.Commands.CommandSyntax{
          command: unquote(name),
          syntax: unquote(syntax),
          description: unquote(summary),
          category: unquote(category),
          parameters: unquote(parameters),
          examples: unquote(tooltip_examples),
          sub_options: unquote(sub_options),
          subcommands: unquote(subcommands)
        }
      end
    end
  end

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
          optional(:show_status_tab) => boolean(),
          optional(:session_id) => String.t() | nil,
          optional(:active_pm) => String.t() | nil
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
