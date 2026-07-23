defmodule RetroHexChatWeb.Icons.Flags do
  @moduledoc """
  National flag icons for the language menu (14×14).

  Each supported locale maps to the flag conventionally associated with the
  language: en → US, pt_BR → Brazil, pt_PT → Portugal, es → Spain, fr → France,
  de → Germany, ja → Japan, zh_hans → China, zh_hant → Taiwan, id → Indonesia,
  ar → Saudi Arabia, ru → Russia, hi → India, ko → South Korea, tr → Turkey,
  vi → Vietnam, bn → Bangladesh, ur → Pakistan, it → Italy, pl → Poland,
  nl → Netherlands.

  Flags render as a 12×9 field inside a 1px black outline, vertically centered
  in the 14×14 viewBox — the same footprint as the other 14×14 menu icons.
  `flag_icon/1` dispatches by `locale` and falls back to the globe for unknown
  codes.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons.Communication

  attr :locale, :string, required: true
  attr :class, :string, default: nil

  @spec flag_icon(map()) :: Phoenix.LiveView.Rendered.t()
  def flag_icon(%{locale: "en"} = assigns), do: icon_flag_en(assigns)
  def flag_icon(%{locale: "pt_BR"} = assigns), do: icon_flag_pt_br(assigns)
  def flag_icon(%{locale: "pt_PT"} = assigns), do: icon_flag_pt_pt(assigns)
  def flag_icon(%{locale: "es"} = assigns), do: icon_flag_es(assigns)
  def flag_icon(%{locale: "fr"} = assigns), do: icon_flag_fr(assigns)
  def flag_icon(%{locale: "de"} = assigns), do: icon_flag_de(assigns)
  def flag_icon(%{locale: "ja"} = assigns), do: icon_flag_ja(assigns)
  def flag_icon(%{locale: "zh_hans"} = assigns), do: icon_flag_zh_hans(assigns)
  def flag_icon(%{locale: "zh_hant"} = assigns), do: icon_flag_zh_hant(assigns)
  def flag_icon(%{locale: "id"} = assigns), do: icon_flag_id(assigns)
  def flag_icon(%{locale: "ar"} = assigns), do: icon_flag_ar(assigns)
  def flag_icon(%{locale: "ru"} = assigns), do: icon_flag_ru(assigns)
  def flag_icon(%{locale: "hi"} = assigns), do: icon_flag_hi(assigns)
  def flag_icon(%{locale: "ko"} = assigns), do: icon_flag_ko(assigns)
  def flag_icon(%{locale: "tr"} = assigns), do: icon_flag_tr(assigns)
  def flag_icon(%{locale: "vi"} = assigns), do: icon_flag_vi(assigns)
  def flag_icon(%{locale: "bn"} = assigns), do: icon_flag_bn(assigns)
  def flag_icon(%{locale: "ur"} = assigns), do: icon_flag_ur(assigns)
  def flag_icon(%{locale: "it"} = assigns), do: icon_flag_it(assigns)
  def flag_icon(%{locale: "pl"} = assigns), do: icon_flag_pl(assigns)
  def flag_icon(%{locale: "nl"} = assigns), do: icon_flag_nl(assigns)
  def flag_icon(assigns), do: Communication.icon_globe(assigns)

  attr :class, :string, default: nil

  @spec icon_flag_en(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_en(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#fff" />
      <rect x="1" y="3" width="12" height="1" fill="#B22234" />
      <rect x="1" y="5" width="12" height="1" fill="#B22234" />
      <rect x="1" y="7" width="12" height="1" fill="#B22234" />
      <rect x="1" y="9" width="12" height="1" fill="#B22234" />
      <rect x="1" y="11" width="12" height="1" fill="#B22234" />
      <rect x="1" y="3" width="5" height="4" fill="#3C3B6E" />
      <rect x="2" y="4" width="1" height="1" fill="#fff" />
      <rect x="4" y="4" width="1" height="1" fill="#fff" />
      <rect x="3" y="5" width="1" height="1" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_pt_br(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_pt_br(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#009C3B" />
      <polygon points="7,4 11.5,7.5 7,11 2.5,7.5" fill="#FFDF00" />
      <circle cx="7" cy="7.5" r="1.6" fill="#002776" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_pt_pt(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_pt_pt(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="5" height="9" fill="#046A38" />
      <rect x="6" y="3" width="7" height="9" fill="#DA291C" />
      <circle cx="6" cy="7.5" r="1.8" fill="#FFE900" />
      <circle cx="6" cy="7.5" r="0.9" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_es(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_es(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="2" fill="#AA151B" />
      <rect x="1" y="5" width="12" height="5" fill="#F1BF00" />
      <rect x="1" y="10" width="12" height="2" fill="#AA151B" />
      <rect x="3" y="6" width="2" height="3" fill="#AA151B" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_fr(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_fr(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="4" height="9" fill="#0055A4" />
      <rect x="5" y="3" width="4" height="9" fill="#fff" />
      <rect x="9" y="3" width="4" height="9" fill="#EF4135" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_de(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_de(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="3" fill="#1a1a1a" />
      <rect x="1" y="6" width="12" height="3" fill="#DD0000" />
      <rect x="1" y="9" width="12" height="3" fill="#FFCE00" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_ja(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_ja(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#fff" />
      <circle cx="7" cy="7.5" r="2.4" fill="#BC002D" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_zh_hans(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_zh_hans(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#EE1C25" />
      <polygon
        points="3.5,3.6 3.9,4.75 5.12,4.77 4.15,5.51 4.5,6.68 3.5,5.98 2.5,6.68 2.85,5.51 1.88,4.77 3.1,4.75"
        fill="#FFFF00"
      />
      <rect x="5.6" y="4" width="0.8" height="0.8" fill="#FFFF00" />
      <rect x="6.4" y="5.6" width="0.8" height="0.8" fill="#FFFF00" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_zh_hant(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_zh_hant(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#FE0000" />
      <rect x="1" y="3" width="6" height="4.5" fill="#000095" />
      <circle cx="4" cy="5.2" r="1.3" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_id(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_id(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="4.5" fill="#CE1126" />
      <rect x="1" y="7.5" width="12" height="4.5" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_ar(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_ar(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#006C35" />
      <rect x="3" y="5" width="8" height="1.2" fill="#fff" />
      <rect x="3" y="8.2" width="7" height="0.8" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_ru(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_ru(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="3" fill="#fff" />
      <rect x="1" y="6" width="12" height="3" fill="#0039A6" />
      <rect x="1" y="9" width="12" height="3" fill="#D52B1E" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_hi(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_hi(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="3" fill="#FF9933" />
      <rect x="1" y="6" width="12" height="3" fill="#fff" />
      <rect x="1" y="9" width="12" height="3" fill="#138808" />
      <circle cx="7" cy="7.5" r="1.1" fill="none" stroke="#000080" stroke-width="0.5" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_ko(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_ko(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#fff" />
      <path d="M4.6 7.5 a2.4 2.4 0 0 1 4.8 0 z" fill="#CD2E3A" />
      <path d="M4.6 7.5 a2.4 2.4 0 0 0 4.8 0 z" fill="#0047A0" />
      <rect x="1.8" y="4" width="1.4" height="0.4" fill="#1a1a1a" />
      <rect x="10.8" y="4" width="1.4" height="0.4" fill="#1a1a1a" />
      <rect x="1.8" y="10.6" width="1.4" height="0.4" fill="#1a1a1a" />
      <rect x="10.8" y="10.6" width="1.4" height="0.4" fill="#1a1a1a" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_tr(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_tr(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#E30A17" />
      <circle cx="5.8" cy="7.5" r="2.2" fill="#fff" />
      <circle cx="6.5" cy="7.5" r="1.8" fill="#E30A17" />
      <polygon
        points="9.3,6.6 9.51,7.21 10.16,7.22 9.64,7.61 9.83,8.23 9.3,7.86 8.77,8.23 8.96,7.61 8.44,7.22 9.09,7.21"
        fill="#fff"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_vi(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_vi(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#DA251D" />
      <polygon
        points="7,5.3 7.52,6.79 9.09,6.82 7.84,7.77 8.29,9.28 7,8.38 5.71,9.28 6.16,7.77 4.91,6.82 6.48,6.79"
        fill="#FFFF00"
      />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_bn(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_bn(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="9" fill="#006A4E" />
      <circle cx="6.4" cy="7.5" r="2.3" fill="#F42A41" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_ur(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_ur(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="3" height="9" fill="#fff" />
      <rect x="4" y="3" width="9" height="9" fill="#01411C" />
      <circle cx="8.7" cy="7.7" r="2" fill="#fff" />
      <circle cx="9.4" cy="7.4" r="1.7" fill="#01411C" />
      <rect x="10.2" y="4.9" width="0.9" height="0.9" fill="#fff" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_it(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_it(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="4" height="9" fill="#009246" />
      <rect x="5" y="3" width="4" height="9" fill="#fff" />
      <rect x="9" y="3" width="4" height="9" fill="#CE2B37" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_pl(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_pl(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="4.5" fill="#fff" />
      <rect x="1" y="7.5" width="12" height="4.5" fill="#DC143C" />
    </svg>
    """
  end

  attr :class, :string, default: nil

  @spec icon_flag_nl(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_flag_nl(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 14 14" shape-rendering="crispEdges" aria-hidden="true">
      <rect x="0" y="2" width="14" height="11" fill="#000" />
      <rect x="1" y="3" width="12" height="3" fill="#AE1C28" />
      <rect x="1" y="6" width="12" height="3" fill="#fff" />
      <rect x="1" y="9" width="12" height="3" fill="#21468B" />
    </svg>
    """
  end
end
