defmodule ViaInputEvent.Utils do
  require Logger

  def find_device(device_names) when is_list(device_names) do
    {[device_name], remaining_devices} = Enum.split(device_names, 1)
    Logger.warn("seatch for #{device_name}")

    case find_device(device_name) do
      {"", nil} ->
        if Enum.empty?(remaining_devices), do: {"", "", nil}, else: find_device(remaining_devices)

      {input_name, device_info} ->
        {input_name, device_name, device_info}
    end
  end

  def find_device(device_name, devices \\ InputEvent.enumerate()) do
    {[{input_name, device_info}], remaining_devices} = Enum.split(devices, 1)
    device_name = String.downcase(device_name)

    cond do
      String.contains?(String.downcase(device_info.name), device_name) ->
        Logger.debug("Found #{inspect(device_name)} at #{input_name}")
        {input_name, device_info}

      Enum.empty?(remaining_devices) ->
        # Logger.debug("device not found")
        {"", nil}

      true ->
        find_device(device_name, remaining_devices)
    end
  end

  def find_device_with_event_number(event_number, devices \\ InputEvent.enumerate()) do
    {[{input_name, device_info}], remaining_devices} = Enum.split(devices, 1)

    cond do
      String.equivalent?("/dev/input/event#{event_number}", input_name) ->
        # Logger.debug("Found #{device_name} at #{input_name}")
        {input_name, device_info}

      Enum.empty?(remaining_devices) ->
        # Logger.debug("device not found")
        {"", nil}

      true ->
        find_device_with_event_number(event_number, remaining_devices)
    end
  end

  @spec find_keyboard(list()) :: tuple()
  def find_keyboard(devices_to_ignore \\ []) do
    all_devices =
      Enum.reduce(InputEvent.enumerate(), [], fn {event, device}, acc ->
        device_name = String.downcase(device.name)

        if String.contains?(device_name, devices_to_ignore),
          do: acc,
          else: acc ++ [{event, device}]
      end)

    if Enum.empty?(all_devices) do
      {"", nil}
    else
      find_keyboard(all_devices, {"", nil}, 0)
    end
  end

  def find_keyboard(devices, current_device, longest_key_list) do
    {[{input_name, device}], remaining_devices} = Enum.split(devices, 1)

    num_keys = device.report_info |> Keyword.get(:ev_key, []) |> length()

    cond do
      num_keys > longest_key_list ->
        # Logger.debug("Found #{device_name} at #{input_name}")
        find_keyboard(remaining_devices, {input_name, device}, num_keys)

      Enum.empty?(remaining_devices) ->
        current_device

      # Logger.debug("device not found")

      true ->
        find_keyboard(remaining_devices, current_device, longest_key_list)
    end
  end
end
