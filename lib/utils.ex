defmodule ViaInputEvent.Utils do
  require Logger
  def find_device(device_name, devices \\ InputEvent.enumerate()) do
    {[{input_name, device_info}], remaining_devices} = Enum.split(devices, 1)

    cond do
      String.contains?(String.downcase(device_info.name), device_name) ->
        Logger.debug("Found #{device_name} at #{input_name}")
        {input_name, device_info}

      Enum.empty?(remaining_devices) ->
        Logger.debug("device not found")
        {"", nil}

      true ->
        find_device(device_name, remaining_devices)
    end
  end
end
