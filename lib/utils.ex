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
    all_devices = get_all_devices(devices_to_ignore)

    # Logger.debug("all devs: #{inspect(all_devices)}")

    if Enum.empty?(all_devices) do
      {"", nil}
    else
      find_keyboard(all_devices, {"", nil}, 0)
    end
  end

  def find_keyboard(devices, current_best_device, longest_key_list) do
    {[new_device], remaining_devices} = Enum.split(devices, 1)
    {_input_name, device} = new_device
    num_keys = device.report_info |> Keyword.get(:ev_key, []) |> length()
    # Logger.debug("#{device.name} at #{input_name} with #{num_keys}")
    # Logger.debug("current dev#{inspect(current_best_device)}")

    # Logger.debug("#{inspect(remaining_devices)}")
    device_has_most_keys = num_keys > longest_key_list

    cond do
      Enum.empty?(remaining_devices) ->
        if device_has_most_keys, do: new_device, else: current_best_device

      num_keys > longest_key_list ->
        # Logger.debug("Found #{device.name} at #{input_name}")
        find_keyboard(remaining_devices, new_device, num_keys)

      # Logger.debug("device not found")

      true ->
        find_keyboard(remaining_devices, current_best_device, longest_key_list)
    end
  end

  def get_all_devices(devices_to_ignore \\ []) do
    Enum.reduce(InputEvent.enumerate(), [], fn {event, device}, acc ->
      device_name = String.downcase(device.name)

      if String.contains?(device_name, devices_to_ignore),
        do: acc,
        else: acc ++ [{event, device}]
    end)
  end
end
