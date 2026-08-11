defmodule RetroHexChatWeb.MediaDevicesTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChatWeb.MediaDevices

  describe "kinds/0 and none/0" do
    test "the three a browser reports, in the order the dialogs offer them" do
      assert MediaDevices.kinds() == ["audioinput", "videoinput", "audiooutput"]
    end

    test "every kind is present before the browser has answered" do
      assert MediaDevices.none() == %{
               "audioinput" => [],
               "videoinput" => [],
               "audiooutput" => []
             }
    end
  end

  describe "normalize/2" do
    test "a device keeps its id and its label" do
      payload = %{"audioinput" => [%{"deviceId" => "mic-1", "label" => "Built-in"}]}

      assert %{"audioinput" => [%{"id" => "mic-1", "label" => "Built-in"}]} =
               MediaDevices.normalize(payload, "Default device")
    end

    test "atom keys and string keys are the same payload" do
      atoms = MediaDevices.normalize(%{audioinput: [%{id: "mic-1", label: "Built-in"}]}, "-")

      strings =
        MediaDevices.normalize(
          %{"audioinput" => [%{"id" => "mic-1", "label" => "Built-in"}]},
          "-"
        )

      assert atoms == strings
    end

    test "a browser that says deviceId is saying id" do
      by_device_id = MediaDevices.normalize(%{"videoinput" => [%{"deviceId" => "cam"}]}, "-")
      by_id = MediaDevices.normalize(%{"videoinput" => [%{"id" => "cam"}]}, "-")

      assert by_device_id == by_id
    end

    test "a device the browser will not name takes the caller's label" do
      payload = %{"audioinput" => [%{"deviceId" => "mic-1"}]}

      assert %{"audioinput" => [%{"label" => "Dispositivo padrão"}]} =
               MediaDevices.normalize(payload, "Dispositivo padrão")
    end

    test "a device with no id at all is still listed, with an empty one" do
      assert %{"audiooutput" => [%{"id" => "", "label" => "Speakers"}]} =
               MediaDevices.normalize(%{"audiooutput" => [%{"label" => "Speakers"}]}, "-")
    end

    test "a kind the browser did not mention is empty, not missing" do
      normalized = MediaDevices.normalize(%{"audioinput" => [%{"id" => "mic"}]}, "-")

      assert normalized["videoinput"] == []
      assert normalized["audiooutput"] == []
    end

    test "a kind that is not a list is empty rather than a crash" do
      assert MediaDevices.normalize(%{"audioinput" => "nonsense"}, "-")["audioinput"] == []
    end

    test "a payload that is not a map at all leaves the dialog empty" do
      assert MediaDevices.normalize("nonsense", "-") == MediaDevices.none()
      assert MediaDevices.normalize(nil, "-") == MediaDevices.none()
    end

    test "ids and labels come back as strings, whatever the client sent" do
      assert %{"audioinput" => [%{"id" => "7", "label" => "9"}]} =
               MediaDevices.normalize(%{"audioinput" => [%{"id" => 7, "label" => 9}]}, "-")
    end
  end

  describe "listing/1" do
    test "fills in the kinds a dialog is missing" do
      assert MediaDevices.listing(%{devices: %{"audioinput" => [%{"id" => "mic"}]}}) == %{
               "audioinput" => [%{"id" => "mic"}],
               "videoinput" => [],
               "audiooutput" => []
             }
    end

    test "a dialog with no devices yet shows three empty pickers" do
      assert MediaDevices.listing(%{}) == MediaDevices.none()
      assert MediaDevices.listing(nil) == MediaDevices.none()
      assert MediaDevices.listing(%{devices: "nonsense"}) == MediaDevices.none()
    end
  end

  describe "preferences/1" do
    test "nothing chosen is nothing for each kind" do
      assert MediaDevices.no_preference() == %{
               audio_input_id: nil,
               video_input_id: nil,
               audio_output_id: nil
             }
    end

    test "reads a choice held at the top level" do
      assert %{audio_input_id: "mic-1"} = MediaDevices.preferences(%{audio_input_id: "mic-1"})
    end

    test "reads a choice held under device_preferences" do
      source = %{device_preferences: %{video_input_id: "cam-1"}}

      assert %{video_input_id: "cam-1"} = MediaDevices.preferences(source)
    end

    test "a top-level choice wins over a stored one, which is what submitting a form means" do
      source = %{audio_output_id: "new", device_preferences: %{audio_output_id: "old"}}

      assert %{audio_output_id: "new"} = MediaDevices.preferences(source)
    end

    test "an empty choice is no choice, not a device called nothing" do
      assert %{audio_input_id: nil} = MediaDevices.preferences(%{audio_input_id: ""})
    end

    test "string keys read the same as atom keys" do
      assert MediaDevices.preferences(%{"audio_input_id" => "mic"}) ==
               MediaDevices.preferences(%{audio_input_id: "mic"})
    end

    test "anything that is not a map is nobody's choice" do
      assert MediaDevices.preferences(nil) == MediaDevices.no_preference()
      assert MediaDevices.preferences("nonsense") == MediaDevices.no_preference()
    end
  end

  describe "device_id/1" do
    test "an empty id is nothing" do
      assert MediaDevices.device_id("") == nil
      assert MediaDevices.device_id(nil) == nil
    end

    test "a real id is itself" do
      assert MediaDevices.device_id("mic-1") == "mic-1"
    end

    test "an id the client sent as something else becomes a string" do
      assert MediaDevices.device_id(7) == "7"
    end
  end
end
