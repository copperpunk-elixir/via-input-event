defmodule ViaInputEvent.FrskyJoystick do
  use GenServer
  require Logger

  @joystick_name "frsky"
  @connect_to_joystick_loop :connect_to_joystick_loop
  @publish_joystick_loop :publish_joystick_loop
  @wait_for_all_channels_loop :wait_for_all_channels_loop
  @remote_input_found_group :remote_input_found

  def start_link(config) do
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    ViaUtils.Comms.Supervisor.start_operator(__MODULE__)
    channel_map = Keyword.fetch!(config, :channel_map)

    connect_joystick_timer =
      ViaUtils.Process.start_loop(
        self(),
        1000,
        @connect_to_joystick_loop
      )

    state = %{
      joystick_input_name: nil,
      joystick: nil,
      num_channels: get_num_channels(channel_map),
      channel_map: channel_map,
      analog_min_and_range: nil,
      joystick_channels: Keyword.get(config, :default_values, %{}),
      publish_joystick_loop_interval_ms:
        Keyword.fetch!(config, :publish_joystick_loop_interval_ms),
      subscriber_groups: Keyword.fetch!(config, :subscriber_groups),
      connect_joystick_timer: connect_joystick_timer
    }

    ViaUtils.Comms.join_group(__MODULE__, @remote_input_found_group, self())
    {:ok, state}
  end

  def handle_info(@connect_to_joystick_loop, state) do
    {joystick_input_name, joystick} = ViaInputEvent.Utils.find_device(@joystick_name)

    state =
      if joystick_input_name == "" do
        Logger.warn("Joystick #{@joystick_name} not found. Retrying in 1000ms.")
        Process.sleep(1000)
        state
      else
        Logger.debug("found #{@joystick_name}: #{inspect(joystick)}")
        InputEvent.start_link(joystick_input_name)
        {analog_min, analog_max} = get_analog_min_max(joystick)
        analog_range = analog_max - analog_min

        connect_joystick_timer = ViaUtils.Process.stop_loop(state.connect_joystick_timer)

        ViaUtils.Comms.send_local_msg_to_group(
          __MODULE__,
          @remote_input_found_group,
          @remote_input_found_group,
          self()
        )

        GenServer.cast(
          __MODULE__,
          {@wait_for_all_channels_loop, state.publish_joystick_loop_interval_ms}
        )

        %{
          state
          | joystick_input_name: joystick_input_name,
            joystick: joystick,
            analog_min_and_range: {analog_min, analog_range},
            connect_joystick_timer: connect_joystick_timer
        }
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:input_event, input_name, events}, state) do
    state =
      if input_name == state.joystick_input_name do
        channel_map = state.channel_map

        {analog_min, analog_range} = state.analog_min_and_range

        joystick_channels =
          Enum.reduce(events, state.joystick_channels, fn {type, channel, value}, acc ->
            # Logger.debug("event rx: #{input_name}:#{type}/#{channel}/#{value}")
            channel_number = Map.get(channel_map, channel, nil)

            if is_nil(channel_number) do
              acc
            else
              case type do
                :ev_abs ->
                  Map.put(
                    acc,
                    channel_number,
                    2 * (value - analog_min) / analog_range - 1
                  )

                :ev_key ->
                  Map.put(acc, channel_number, 2 * value - 1)

                other ->
                  Logger.warn("unsupported type: #{inspect(other)}")
              end
            end
          end)

        Map.put(state, :joystick_channels, joystick_channels)
      else
        state
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(@publish_joystick_loop, state) do
    channel_values = get_channels(state.joystick_channels, state.num_channels)
    # Logger.debug("#{ViaUtils.Format.eftb_map(state.joystick_channels, 3)}")
    # Logger.debug("#{ViaUtils.Format.eftb_list(channel_values, 3)}")

    Enum.each(state.subscriber_groups, fn group ->
      ViaUtils.Comms.send_local_msg_to_group(
        __MODULE__,
        {group, channel_values},
        self()
      )
    end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(@remote_input_found_group, state) do
    Logger.debug("Other input found. Stop connect_keyboard loop.")
    connect_joystick_timer = ViaUtils.Process.stop_loop(state.connect_joystick_timer)
    {:noreply, %{state | connect_joystick_timer: connect_joystick_timer}}
  end

  @impl GenServer
  def handle_cast({@wait_for_all_channels_loop, publish_joystick_loop_interval_ms}, state) do
    Logger.debug("wait for channels. currently have: #{inspect(state.joystick_channels)}")

    if length(get_channels(state.joystick_channels, state.num_channels)) == state.num_channels do
      ViaUtils.Process.start_loop(
        self(),
        publish_joystick_loop_interval_ms,
        @publish_joystick_loop
      )
    else
      Process.sleep(100)

      GenServer.cast(
        __MODULE__,
        {@wait_for_all_channels_loop, publish_joystick_loop_interval_ms}
      )
    end

    {:noreply, state}
  end

  @spec get_num_channels(map()) :: integer()
  def get_num_channels(channel_map) do
    Map.values(channel_map)
    |> Enum.sort()
    |> Enum.at(-1)
    |> Kernel.+(1)
  end

  @spec get_channels(map(), integer()) :: list()
  def get_channels(joystick_channels, num_channels) do
    joystick_channels
    |> Map.to_list()
    |> Enum.sort(fn {k1, _val1}, {k2, _val2} -> k1 < k2 end)
    |> Enum.reduce([], fn {_k, v}, acc -> [v] ++ acc end)
    |> Enum.reverse()
    |> Enum.take(num_channels)
  end

  @spec get_analog_min_max(struct()) :: tuple()
  def get_analog_min_max(joystick) do
    stick_settings = joystick.report_info |> Keyword.fetch!(:ev_abs) |> Keyword.fetch!(:abs_x)
    {stick_settings.min, stick_settings.max}
  end
end
