defmodule RetroHexChatWeb.ShowcaseLive.Primitives.FormPage do
  @moduledoc false
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  use Phoenix.VerifiedRoutes,
    endpoint: RetroHexChatWeb.Endpoint,
    router: RetroHexChatWeb.Router,
    statics: RetroHexChatWeb.static_paths()

  import RetroHexChatWeb.Components.UI.Form
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.ShowcaseHelpers
  alias RetroHexChatWeb.Icons

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Form"), active_page: "form")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">{gettext("Form")}</h2>

      <.showcase_card
        title={gettext("Form Components")}
        description="Form layout primitives: item, label, control, description, and message."
      >
        <div class="max-w-sm space-y-4">
          <.form_item>
            <.form_label>{gettext("Username")}</.form_label>
            <.form_control>
              <.input type="text" name="username" placeholder={gettext("Enter username")} />
            </.form_control>
            <.form_description>{gettext("This is your public display name.")}</.form_description>
          </.form_item>

          <.form_item>
            <.form_label>{gettext("Email")}</.form_label>
            <.form_control>
              <.input type="email" name="email" placeholder={gettext("user@example.com")} />
            </.form_control>
            <.form_description>{gettext("We'll never share your email.")}</.form_description>
          </.form_item>

          <.form_item>
            <.form_label error={true}>{gettext("Password")}</.form_label>
            <.form_control>
              <.input type="password" name="password" />
            </.form_control>
            <.form_message errors={["Password must be at least 8 characters"]} />
          </.form_item>

          <.button type="submit">
            <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
            {gettext("Submit")}
          </.button>
        </div>
        <.code_example>
          &lt;.form_item&gt;
          &lt;.form_label&gt;Username&lt;/.form_label&gt;
          &lt;.form_control&gt;
          &lt;.input type="text" name="username" /&gt;
          &lt;/.form_control&gt;
          &lt;.form_description&gt;Help text&lt;/.form_description&gt;
          &lt;.form_message errors={["Error"]} /&gt;
          &lt;/.form_item&gt;
        </.code_example>
      </.showcase_card>
    </.showcase_layout>
    """
  end
end
