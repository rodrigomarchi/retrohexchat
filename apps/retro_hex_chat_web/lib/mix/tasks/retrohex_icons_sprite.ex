defmodule Mix.Tasks.Retrohex.Icons.Sprite do
  @shortdoc "Builds the SVG sprite the icon components point their <use> at"

  @moduledoc """
  Renders every icon in `RetroHexChatWeb.Icons.Registry` into one `<symbol>` and
  writes them as a single sprite document.

  The art stays where it is authored — a `~H` sigil in a subject submodule under
  `components/icons/`. This task renders it once at build time so a page can ship
  `<use href="…#icon_folder">` instead of the drawing itself. On `/connect` that
  was 169 copies of 94 drawings; the sprite carries each drawing once and the
  browser caches it across every page in the session.

  Run as the first step of `assets.build` and `assets.deploy`, before
  `phx.digest` fingerprints it.

      mix retrohex.icons.sprite           # write the sprite
      mix retrohex.icons.sprite --check   # fail if what is on disk is stale

  """

  use Mix.Task

  @dialyzer [:no_undefined_callbacks]

  alias Phoenix.HTML.Safe
  alias RetroHexChatWeb.Icons.Registry

  @output "priv/static/assets/icons/sprite.svg"

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    {opts, _rest, _invalid} = OptionParser.parse(args, strict: [check: :boolean])
    path = output_path()

    if opts[:check] do
      if stale?(path) do
        raise "#{@output} is out of sync with the icon modules. Run: mix retrohex.icons.sprite"
      end

      IO.puts("Icon sprite is up to date (#{length(Registry.all())} icons).")
    else
      sprite = build()
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, sprite)

      IO.puts("Wrote #{@output} — #{length(Registry.all())} icons, #{byte_size(sprite)} bytes.")
    end

    :ok
  end

  @doc """
  The absolute path the sprite is written to.
  """
  @spec output_path() :: Path.t()
  def output_path do
    Application.load(:retro_hex_chat_web)

    Path.join(Application.app_dir(:retro_hex_chat_web), @output)
  end

  @doc """
  Whether the file at `path` differs from what the icon modules currently draw.
  """
  @spec stale?(Path.t()) :: boolean()
  def stale?(path) do
    case File.read(path) do
      {:ok, contents} -> contents != build()
      {:error, _reason} -> true
    end
  end

  @doc """
  The sprite document: one `<symbol>` per registered icon, in catalog order.
  """
  @spec build() :: String.t()
  def build do
    symbols = Enum.map_join(Registry.all(), "\n", &symbol/1)

    """
    <svg xmlns="http://www.w3.org/2000/svg" style="display:none" aria-hidden="true">
    #{symbols}
    </svg>
    """
  end

  @doc """
  One `<symbol>` from one rendered icon.

  Takes the raw render rather than the module so the dev-only decorations —
  `debug_heex_annotations` wraps the art in HTML comments, `debug_attributes`
  stamps `data-phx-loc` on every tag — can be exercised directly. The sprite is
  built by `assets.build`, which runs in dev, so neither may reach the file.
  """
  @spec symbol_from_svg(atom(), String.t()) :: String.t()
  def symbol_from_svg(name, rendered) do
    id = Registry.sprite_id(name)
    {attrs, body} = split_root(strip_comments(rendered), id)

    ~s(<symbol id="#{id}"#{attrs}>#{body}</symbol>)
  end

  defp symbol({name, module}) do
    Code.ensure_loaded!(module)

    symbol_from_svg(name, render(module, name))
  end

  defp render(module, name) do
    apply(module, name, [%{class: nil, __changed__: nil}])
    |> Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp strip_comments(html), do: String.replace(html, ~r/<!--.*?-->/s, "")

  # An icon is authored as a whole `<svg>` document. Its root attributes carry
  # the geometry (`viewBox`) and the pixel-art rendering hints that have to
  # survive the move, while `class` and `aria-hidden` belong to the `<svg>` the
  # component still emits at the call site.
  @dropped_root_attrs ~w(class aria-hidden xmlns)

  defp split_root(svg, id) do
    case Regex.run(~r{<svg\b([^>]*)>(.*)</svg>}s, String.trim(svg)) do
      [_, attrs, body] ->
        {drop_attrs(attrs, @dropped_root_attrs), minify(body, id)}

      nil ->
        raise("icon #{id} did not render as a single <svg> element")
    end
  end

  defp drop_attrs(attrs, dropped) do
    ~r/([a-zA-Z-]+)="([^"]*)"/
    |> Regex.scan(attrs)
    |> Enum.reject(fn [_, name, value] ->
      name in dropped or String.starts_with?(name, "data-phx-") or value == ""
    end)
    |> Enum.map_join(fn [_, name, value] -> ~s( #{name}="#{value}") end)
  end

  defp minify(body, id) do
    minified =
      body
      |> String.replace(~r{<([a-zA-Z][a-zA-Z0-9-]*)\b([^>]*?)(/?)>}s, fn tag ->
        [_, name, attrs, self_close] =
          Regex.run(~r{<([a-zA-Z][a-zA-Z0-9-]*)\b([^>]*?)(/?)>}s, tag)

        ~s(<#{name}#{drop_attrs(attrs, [])}#{self_close}>)
      end)
      |> String.replace(~r/>\s+</s, "><")
      |> String.replace(~r/\s+/s, " ")
      |> String.trim()

    if minified =~ "<svg" do
      raise("icon #{id} nests an <svg> inside its own; flatten it before spriting")
    end

    minified
  end
end
