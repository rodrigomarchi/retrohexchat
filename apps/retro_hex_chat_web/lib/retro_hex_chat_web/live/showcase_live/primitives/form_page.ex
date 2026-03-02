defmodule RetroHexChatWeb.ShowcaseLive.Primitives.FormPage do
  @moduledoc false
  use Phoenix.LiveView

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
    {:ok, assign(socket, page_title: "Form", active_page: "form")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.showcase_layout active_page={@active_page}>
      <h2 class="text-lg font-bold mb-3">Form</h2>

      <.showcase_card
        title="Form Components"
        description="Form layout primitives: item, label, control, description, and message."
      >
        <div class="max-w-sm space-y-4">
          <.form_item>
            <.form_label>Username</.form_label>
            <.form_control>
              <.input type="text" name="username" placeholder="Enter username" />
            </.form_control>
            <.form_description>This is your public display name.</.form_description>
          </.form_item>

          <.form_item>
            <.form_label>Email</.form_label>
            <.form_control>
              <.input type="email" name="email" placeholder="user@example.com" />
            </.form_control>
            <.form_description>We'll never share your email.</.form_description>
          </.form_item>

          <.form_item>
            <.form_label error={true}>Password</.form_label>
            <.form_control>
              <.input type="password" name="password" />
            </.form_control>
            <.form_message errors={["Password must be at least 8 characters"]} />
          </.form_item>

          <.button type="submit">
            <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
            Submit
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
