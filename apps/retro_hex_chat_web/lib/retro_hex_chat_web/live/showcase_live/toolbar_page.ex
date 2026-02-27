defmodule RetroHexChatWeb.ShowcaseLive.ToolbarPage do
  @moduledoc false
  use Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  alias RetroHexChatWeb.Icons

  import RetroHexChatWeb.Components.UI.Toolbar
  import RetroHexChatWeb.ShowcaseHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Toolbar", active_page: "toolbar")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Toolbar</h2>

      <.showcase_card title="Default Toolbar" description="Standard toolbar with 34x34 icon buttons.">
        <.toolbar>
          <.toolbar_button label="New">
            <Icons.icon_notepad />
          </.toolbar_button>
          <.toolbar_button label="Open">
            <Icons.icon_folder />
          </.toolbar_button>
          <.toolbar_button label="Save">
            <Icons.icon_btn_save />
          </.toolbar_button>
          <.toolbar_separator />
          <.toolbar_button label="Cut">
            <Icons.icon_btn_edit />
          </.toolbar_button>
          <.toolbar_button label="Copy">
            <Icons.icon_copy />
          </.toolbar_button>
          <.toolbar_button label="Paste">
            <Icons.icon_dialog_paste />
          </.toolbar_button>
        </.toolbar>
        <.code_example>
          &lt;.toolbar&gt;
          &lt;.toolbar_button label="New"&gt;
          &lt;Icons.icon_notepad /&gt;
          &lt;/.toolbar_button&gt;
          &lt;.toolbar_separator /&gt;
          &lt;.toolbar_button label="Cut"&gt;
          &lt;Icons.icon_btn_edit /&gt;
          &lt;/.toolbar_button&gt;
          &lt;/.toolbar&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Compact Toolbar"
        description="Smaller 24x24 buttons for formatting toolbars."
      >
        <.toolbar variant="compact">
          <.toolbar_button variant="compact" label="Bold">
            <Icons.icon_fmt_bold class="w-3.5 h-3.5" />
          </.toolbar_button>
          <.toolbar_button variant="compact" label="Italic">
            <Icons.icon_fmt_italic class="w-3.5 h-3.5" />
          </.toolbar_button>
          <.toolbar_button variant="compact" label="Underline">
            <Icons.icon_fmt_underline class="w-3.5 h-3.5" />
          </.toolbar_button>
          <.toolbar_separator variant="compact" />
          <.toolbar_button variant="compact" label="Text Color">
            <Icons.icon_fmt_color class="w-3.5 h-3.5" />
          </.toolbar_button>
          <.toolbar_button variant="compact" label="Background Color">
            <Icons.icon_fmt_reverse class="w-3.5 h-3.5" />
          </.toolbar_button>
        </.toolbar>
        <.code_example>
          &lt;.toolbar variant="compact"&gt;
          &lt;.toolbar_button variant="compact" label="Bold"&gt;
          &lt;Icons.icon_fmt_bold class="w-3.5 h-3.5" /&gt;
          &lt;/.toolbar_button&gt;
          &lt;.toolbar_separator variant="compact" /&gt;
          &lt;/.toolbar&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Active & Disabled States"
        description="Buttons can be active (pressed) or disabled."
      >
        <.toolbar>
          <.toolbar_button label="Connect">
            <Icons.icon_btn_connect_lightning />
          </.toolbar_button>
          <.toolbar_button label="Disconnect" active>
            <Icons.icon_btn_disconnect />
          </.toolbar_button>
          <.toolbar_button label="Disabled" disabled>
            <Icons.icon_btn_connect_disabled />
          </.toolbar_button>
        </.toolbar>
        <.code_example>
          &lt;.toolbar_button label="Connect"&gt;
          &lt;Icons.icon_btn_connect_lightning /&gt;
          &lt;/.toolbar_button&gt;
          &lt;.toolbar_button label="Disconnect" active&gt;
          &lt;Icons.icon_btn_disconnect /&gt;
          &lt;/.toolbar_button&gt;
          &lt;.toolbar_button label="Disabled" disabled&gt;
          &lt;Icons.icon_btn_connect_disabled /&gt;
          &lt;/.toolbar_button&gt;
        </.code_example>
      </.showcase_card>

      <.showcase_card
        title="Platform Main Toolbar"
        description="Replicating the platform's main toolbar with icon groups."
      >
        <.toolbar>
          <.toolbar_button label="Home">
            <Icons.icon_community />
          </.toolbar_button>
          <.toolbar_button label="Settings">
            <Icons.icon_btn_settings />
          </.toolbar_button>
          <.toolbar_button label="Channels">
            <Icons.icon_btn_channel_list />
          </.toolbar_button>
          <.toolbar_separator />
          <.toolbar_button label="Sounds">
            <Icons.icon_btn_sounds />
          </.toolbar_button>
          <.toolbar_button label="DND">
            <Icons.icon_btn_dnd />
          </.toolbar_button>
          <.toolbar_separator />
          <.toolbar_button label="Help">
            <Icons.icon_btn_help_topics />
          </.toolbar_button>
        </.toolbar>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
