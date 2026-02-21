defmodule RetroHexChat.Commands.CommandSyntax.Parameter do
  @moduledoc """
  Single parameter within a command's syntax definition.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          required: boolean(),
          type: :nick | :channel | :text | :mode_flags | :number | :command,
          position: non_neg_integer(),
          description: String.t() | nil
        }

  @enforce_keys [:name, :required, :type, :position]
  defstruct [:name, :required, :type, :position, :description]
end

defmodule RetroHexChat.Commands.CommandSyntax.SubOption do
  @moduledoc """
  Enumerated option within a command (e.g., mode flags for `/mode`).
  """

  @type t :: %__MODULE__{
          flag: String.t(),
          label: String.t(),
          description: String.t(),
          requires_param: boolean()
        }

  @enforce_keys [:flag, :label, :description, :requires_param]
  defstruct [:flag, :label, :description, :requires_param]
end

defmodule RetroHexChat.Commands.CommandSyntax do
  @moduledoc """
  Structured definition of a command's expected parameters.

  Used by the syntax tooltip to show parameter guidance as users type commands.
  Compiled at module load time from handler metadata.
  """

  alias __MODULE__.{Parameter, SubOption}

  @type t :: %__MODULE__{
          command: String.t(),
          syntax: String.t(),
          description: String.t(),
          category: :basics | :channel | :user | :config | :advanced,
          parameters: [Parameter.t()],
          examples: [String.t()],
          sub_options: [SubOption.t()] | nil,
          subcommands: [%{name: String.t(), description: String.t()}] | nil
        }

  @enforce_keys [:command, :syntax, :description, :category, :parameters, :examples]
  defstruct [
    :command,
    :syntax,
    :description,
    :category,
    :parameters,
    :examples,
    :sub_options,
    :subcommands
  ]

  @doc """
  Converts a CommandSyntax struct to a map suitable for `push_event`.
  Atom keys and nested structs are converted to plain maps with string type values.
  """
  @spec to_client_payload(t()) :: map()
  def to_client_payload(%__MODULE__{} = syntax) do
    %{
      command: syntax.command,
      syntax: syntax.syntax,
      description: syntax.description,
      parameters: Enum.map(syntax.parameters, &parameter_to_map/1),
      examples: syntax.examples,
      sub_options: sub_options_to_maps(syntax.sub_options)
    }
  end

  @doc """
  Computes the 0-indexed position of the next expected parameter
  based on the arguments typed so far.
  """
  @spec compute_current_param_index([Parameter.t()], String.t()) :: non_neg_integer() | nil
  def compute_current_param_index([], _args_string), do: nil

  def compute_current_param_index(parameters, args_string) do
    arg_count =
      args_string
      |> String.trim()
      |> case do
        "" -> 0
        trimmed -> trimmed |> String.split(~r/\s+/) |> length()
      end

    last_is_text = List.last(parameters).type == :text
    max_index = length(parameters) - 1

    cond do
      last_is_text and arg_count >= max_index -> max_index
      arg_count > max_index -> max_index
      true -> arg_count
    end
  end

  defp parameter_to_map(%Parameter{} = param) do
    %{
      name: param.name,
      required: param.required,
      type: Atom.to_string(param.type),
      position: param.position,
      description: param.description
    }
  end

  defp sub_options_to_maps(nil), do: nil

  defp sub_options_to_maps(sub_options) do
    Enum.map(sub_options, fn %SubOption{} = opt ->
      %{
        flag: opt.flag,
        label: opt.label,
        description: opt.description,
        requires_param: opt.requires_param
      }
    end)
  end
end
