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
        parameters: [
          Parameter.required(:nick, "nickname", dgettext("commands", "User to give operator status"))
        ]

  From that it answers `help/0` (the `/help` page: `description` is the long
  text), `category/0` and `syntax_definition/0` (the tooltip: `summary` is the
  short text), and `validate/1` accepts anything unless the handler defines
  its own. Every text is an expression evaluated when asked for, so it is
  translated into the reader's language at that moment. Optional:
  `parameters` (default `[]`, built with `Parameter.required/3` and
  `Parameter.optional/3` in the order they are typed), `sub_options`, `subcommands`, and
  `tooltip_examples` when the tooltip shows fewer examples than `/help`, and
  `usage` — the message `validate/1` answers when the command is typed bare.

  A command whose whole job is one of the common shapes declares it as
  `execute:` instead of writing `execute/2`:

    * `{:ui_action, action}` — opens or does `action` in the client, whatever
      was typed after it;
    * `{:nick_action, action, usage}` — `action` on the nickname typed, or
      `usage` when none was;
    * `{:channel_target, usage, check, run}` — `Guards.on_channel_target/5`:
      a nickname in the active channel, allowed by `check`, handed to `run`;
    * `{:channel_message, usage, run}` — `Guards.on_channel_message/4`: a
      message id in the active channel, handed to `run`.
  """

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler.Guards

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
    usage = Keyword.get(opts, :usage)
    execute = Keyword.get(opts, :execute)

    quote do
      unquote(execute_shape(execute))

      @behaviour RetroHexChat.Commands.Handler

      @impl true
      @spec validate(String.t()) :: :ok | {:error, String.t()}
      unquote(
        if usage do
          quote do
            def validate(""), do: {:error, unquote(usage)}
            def validate(_raw_args), do: :ok
          end
        else
          quote do
            def validate(_raw_args), do: :ok
          end
        end
      )

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
          parameters: Parameter.positioned(unquote(parameters)),
          examples: unquote(tooltip_examples),
          sub_options: unquote(sub_options),
          subcommands: unquote(subcommands)
        }
      end
    end
  end

  defp execute_shape(nil), do: nil

  # A tuple of three or more arrives quoted as `{:{}, meta, elements}`.
  defp execute_shape({:{}, _meta, elements}), do: execute_shape(List.to_tuple(elements))

  defp execute_shape({:ui_action, action}) do
    quote do
      @impl true
      @spec execute([String.t()], RetroHexChat.Commands.Handler.context()) ::
              RetroHexChat.Commands.Handler.result()
      def execute(_args, _context), do: {:ok, :ui_action, unquote(action), %{}}
    end
  end

  defp execute_shape({:nick_action, action, usage}) do
    quote do
      @impl true
      @spec execute([String.t()], RetroHexChat.Commands.Handler.context()) ::
              RetroHexChat.Commands.Handler.result()
      def execute([], _context), do: {:error, unquote(usage)}

      def execute([target | _rest], _context),
        do: {:ok, :ui_action, unquote(action), %{nickname: target}}
    end
  end

  defp execute_shape({:channel_target, usage, check, run}) do
    quote do
      @impl true
      @spec execute([String.t()], RetroHexChat.Commands.Handler.context()) ::
              RetroHexChat.Commands.Handler.result()
      def execute(args, context) do
        Guards.on_channel_target(
          args,
          context,
          unquote(usage),
          unquote(check),
          unquote(run)
        )
      end
    end
  end

  defp execute_shape({:channel_message, usage, run}) do
    quote do
      @impl true
      @spec execute([String.t()], RetroHexChat.Commands.Handler.context()) ::
              RetroHexChat.Commands.Handler.result()
      def execute(args, context) do
        Guards.on_channel_message(
          args,
          context,
          unquote(usage),
          unquote(run)
        )
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
