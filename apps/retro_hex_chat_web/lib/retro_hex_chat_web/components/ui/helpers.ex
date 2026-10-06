defmodule RetroHexChatWeb.ComponentHelpers do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import Phoenix.Component

  alias RetroHexChatWeb.Components.UI.Chrome

  @doc """
  Prepare input assigns for use in a form. Extract required attribute from the Form.Field struct and update current assigns.
  """
  def prepare_assign(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns[:id] || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign(
      :name,
      assigns[:name] || if(assigns[:multiple], do: field.name <> "[]", else: field.name)
    )
    |> assign(:value, assigns[:value] || field.value)
    |> prepare_assign()
  end

  # use default value if value is not provided or empty
  def prepare_assign(assigns) do
    value =
      if assigns[:value] in [nil, "", []] do
        assigns[:"default-value"]
      else
        assigns[:value]
      end

    assign(assigns, value: value)
  end

  @doc """
  Reads the first usable text out of a payload, trying each key in turn.

  A dialog is handed a map assembled elsewhere — sometimes with atom keys,
  sometimes with the string keys a JSON round trip leaves behind — and a key
  that is present but blank is as absent as one that is missing. Both spellings
  are tried, whitespace-only text counts as nothing, and a caller lists the keys
  it will accept in the order it prefers them.
  """
  @spec text_value(term(), [atom()], String.t()) :: String.t()
  def text_value(payload, keys, default) when is_map(payload) do
    keys
    |> Enum.find_value(default, fn key ->
      case Map.get(payload, key) || Map.get(payload, to_string(key)) do
        value when is_binary(value) -> non_empty_string(value)
        value when is_atom(value) -> Atom.to_string(value)
        value when is_integer(value) -> Integer.to_string(value)
        _other -> nil
      end
    end)
    |> case do
      "" -> default
      value -> value
    end
  end

  def text_value(_payload, _keys, default), do: default

  defp non_empty_string(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  # normalize_integer
  def normalize_integer(value) when is_integer(value), do: value

  def normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, _} -> integer
      _ -> nil
    end
  end

  def normalize_integer(_), do: nil

  def normalize_boolean(value) do
    case value do
      "true" -> true
      "false" -> false
      true -> true
      false -> false
      _ -> false
    end
  end

  @doc """
  Normalize id to be used in HTML id attribute
  It will replace all non-alphanumeric characters with `-` and downcase the string
  """
  def id(id) do
    id
    |> String.replace(~r/[^a-zA-Z0-9]/, "-")
    |> String.downcase()
  end

  @doc """
  Variant helper for generating classes based on side and align
  """
  @variants %{
    side: %{
      "top" => "bottom-full mb-2",
      "bottom" => "top-full mt-2",
      "left" => "right-full mr-2",
      "right" => "left-full ml-2"
    },
    align: %{
      "start-horizontal" => "left-0",
      "center-horizontal" => "left-1/2 -translate-x-1/2 slide-in-from-left-1/2",
      "end-horizontal" => "right-0",
      "start-vertical" => "top-0",
      "center-vertical" => "top-1/2 -translate-y-1/2 slide-in-from-top-1/2",
      "end-vertical" => "bottom-0"
    }
  }

  @spec side_variant(String.t(), String.t()) :: String.t()
  def side_variant(side, align \\ "center") do
    Enum.map_join(%{side: side, align: align(align, side)}, " ", fn {key, value} ->
      @variants[key][value]
    end)
  end

  # decide align class based on side
  defp align(align, side) do
    cond do
      side in ["top", "bottom"] ->
        "#{align}-horizontal"

      side in ["left", "right"] ->
        "#{align}-vertical"
    end
  end

  @variants %{
    variant: %{
      "default" => Chrome.raised() <> " text-foreground ring-1 ring-black",
      "destructive" => Chrome.raised() <> " text-destructive",
      "outline" => Chrome.raised() <> " text-foreground",
      "secondary" => Chrome.raised() <> " text-foreground",
      "ghost" => Chrome.flat() <> " text-foreground hover:bg-surface",
      "link" => "text-primary underline-offset-4 hover:underline"
    },
    size: %{
      "default" => "h-9 px-4 py-2",
      "sm" => "h-8 px-3 text-xs",
      "lg" => "h-10 px-8"
    }
  }

  @default_variants %{
    variant: "default",
    size: "default"
  }

  @doc """
  Reuseable button variant helper. Support 2 variant
  - size: `default|sm|lg`
  - variant: `default|destructive|outline|secondary|ghost|link`
  """
  def button_variant(props \\ %{}) do
    variants = Map.take(props, ~w(variant size)a)
    variants = Map.merge(@default_variants, variants)

    variation_classes = Enum.map_join(variants, " ", fn {key, value} -> @variants[key][value] end)

    shared_classes =
      "inline-flex items-center justify-center whitespace-nowrap text-sm font-medium disabled:pointer-events-none"

    "#{shared_classes} #{variation_classes}"
  end

  @doc """
  Common function for building variant

  ## Examples

  ```elixir
  config =
  %{
    variants: %{
      variant: %{
        default: "hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
        outline:
          "bg-background shadow-[0_0_0_1px_hsl(var(--sidebar-border))] hover:bg-sidebar-accent hover:text-sidebar-accent-foreground hover:shadow-[0_0_0_1px_hsl(var(--sidebar-accent))]",
      },
      size: %{
        default: "h-8 text-sm",
        sm: "h-7 text-xs",
        lg: "h-12 text-sm group-data-[collapsible=icon]:!p-0",
      },
    },
    default_variants: %{
      variant: "default",
      size: "default",
    },
  }

  class_input = %{variant: "outline", size: "lg"}
  variant_class(config, class_input)
  ```

  """
  def variant_class(config, class_input) do
    variants = Map.get(config, :variants, %{})
    default_variants = Map.get(config, :default_variants, %{})

    variants
    |> Map.keys()
    |> Enum.map(fn variant_key ->
      # Get the variant value from input or use default
      variant_value =
        Map.get(class_input, variant_key) ||
          Map.get(default_variants, variant_key)

      # Get the variant options map
      variant_options = Map.get(variants, variant_key, %{})

      # Get the CSS classes for this variant value
      Map.get(variant_options, String.to_existing_atom(variant_value))
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  @doc """
  This function build css style string from map of css style

  ## Examples

  ```elixir
  css_style = %{
    "background-color": "red",
    "color": "white",
    "font-size": "16px",
  }

  style(css_style)

  # => "background-color: red; color: white; font-size: 16px;"
  ```
  """
  def style(items) when is_list(items) do
    {acc_map, acc_list} =
      Enum.reduce(items, {%{}, []}, fn item, {acc_map, acc_list} ->
        cond do
          is_map(item) ->
            {Map.merge(acc_map, item), acc_list}

          is_binary(item) ->
            {acc_map, [item | acc_list]}

          true ->
            {acc_map, [item | acc_list]}
        end
      end)

    style_text = Enum.map_join(acc_map, "; ", fn {k, v} -> "#{k}: #{v}" end) <> ";"
    Enum.join([style_text | acc_list], "; ")
  end

  @doc """
  This function build js script to invoke JS stored in given attribute.
  Similar to JS.exec/2 but this function target the nearest ancestor element.

  ## Examples

  ```heex
  <button click={exec_closest("phx-hide-sheet", ".ancestor_class")}>
    Close
  </button>
  ```
  """
  def exec_closest(attribute, ancestor_selector) do
    """
    var el = this.closest("#{ancestor_selector}"); liveSocket.execJS(el, el.getAttribute("#{attribute}"));
    """
  end

  @doc """
  This component is used to render dynamic tag based on the `tag` attribute. `tag` attribute can be a string or a function component.

  This is just a wrapper around `dynamic_tag` function from Phoenix LiveView which only support string tag.

  ## Examples

  ```heex
  <.dynamic tag={@tag} class="bg-primary text-primary-foreground">
     Hello World
  </.dynamic>
  ```
  """
  def dynamic(%{tag: name} = assigns) when is_function(name, 1) do
    assigns = Map.delete(assigns, :tag)
    name.(assigns)
  end

  def dynamic(assigns) do
    name = assigns[:tag] || "div"

    assigns =
      assigns
      |> Map.delete(:tag)
      |> assign(:tag_name, name)
      |> assign(:name, name)

    dynamic_tag(assigns)
  end

  defp translate_error({msg, opts}) do
    config_translator = get_translator_from_config() || (&fallback_translate_error/1)

    config_translator.({msg, opts})
  end

  defp fallback_translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      try do
        String.replace(acc, "%{#{key}}", to_string(value))
      rescue
        e ->
          IO.warn(
            """
            the fallback message translator for the form_field_error function cannot handle the given value.

            Hint: you can set up the `error_translator_function` to route all errors to your application helpers:

              config :salad_ui, :error_translator_function, {MyAppWeb.CoreComponents, :translate_error}

            Given value: #{inspect(value)}

            Exception: #{Exception.message(e)}
            """,
            __STACKTRACE__
          )

          dgettext("errors", "invalid value")
      end
    end)
  end

  defp get_translator_from_config do
    case Application.get_env(:salad_ui, :error_translator_function) do
      {module, function} -> &apply(module, function, [&1])
      nil -> nil
    end
  end

  @doc """
  Returns the syntax line a dialog shows as the `/` equivalent of a control.

  The string comes from the command handler itself, so a dialog can never
  advertise a syntax the parser stopped accepting. A command with no syntax
  definition falls back to its bare name.
  """
  @spec command_syntax(String.t()) :: String.t()
  def command_syntax(name) when is_binary(name) do
    case RetroHexChat.Commands.Registry.get_syntax(name) do
      %RetroHexChat.Commands.CommandSyntax{syntax: syntax} when is_binary(syntax) -> syntax
      _ -> "/" <> name
    end
  end
end
