defmodule RetroHexChatWeb.Components.UI.Variants do
  @moduledoc """
  Choosing a component's classes from the words a caller used.

  A badge is `default` or `success` or `destructive`; a toggle is that and also
  `sm` or `lg`. Each of those words names one set of Tailwind classes, and a
  component declares its axes once as a table.

  A word the table does not know falls back to that axis's default. It used to
  contribute nothing at all — `%{"success" => "..."}["typo"]` is `nil`, which
  joins as an empty string — so a badge given a variant from a variable rather
  than a literal rendered with no background and no colour, and looked like a
  bug in the CSS. `attr :variant, values: ...` catches a literal at compile
  time and cannot catch anything computed.

  Every axis must offer `"default"`, which is checked when the table is
  declared rather than when somebody renders the component.

  Only the declared axes are read. A component passes its whole assigns here,
  and those carry `:class`, `:rest` and LiveView's own bookkeeping alongside
  the two or three words this is about.
  """

  @typedoc "A component's axes, in the order it declared them."
  @type t :: %__MODULE__{axes: [{atom(), %{String.t() => String.t()}}]}

  @enforce_keys [:axes]
  defstruct [:axes]

  @default "default"

  @doc """
  Declares the axes a component varies on. Belongs in a module attribute.

  Raises while compiling if an axis has no `"default"`, because that is the
  value everything falls back to and a table without one has no answer for a
  word it does not know.
  """
  @spec new(keyword(%{String.t() => String.t()})) :: t()
  def new(axes) when is_list(axes) do
    Enum.each(axes, fn {name, values} ->
      unless is_map_key(values, @default) do
        raise ArgumentError,
              "variant axis #{inspect(name)} has no #{inspect(@default)} to fall back to"
      end
    end)

    %__MODULE__{axes: axes}
  end

  @doc "The classes for the words in `props`, falling back per axis."
  @spec classes(t(), map()) :: String.t()
  def classes(%__MODULE__{axes: axes}, props) when is_map(props) do
    Enum.map_join(axes, " ", fn {name, values} ->
      Map.get(values, Map.get(props, name)) || Map.fetch!(values, @default)
    end)
  end
end
