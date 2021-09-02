defmodule ViaInputEvent.Keyboard do
  use GenServer
  require Logger
  alias ViaInputEvent.KeyCollection, as: KC

  @connect_to_keyboard_loop :connect_to_keyboard_loop
  @publish_keyboard_loop :publish_keyboard_loop
  @wait_for_all_channels_loop :wait_for_all_channels_loop
  @remote_input_found_group :remote_input_found

  def start_link(config) do
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    ViaUtils.Comms.Supervisor.start_operator(__MODULE__)
    channel_map = Keyword.fetch!(config, :channel_map)

    connect_keyboard_timer =
      ViaUtils.Process.start_loop(
        self(),
        1000,
        @connect_to_keyboard_loop
      )

    state = %{
      keyboard_input_name: nil,
      keyboard: nil,
      num_channels: get_num_channels(channel_map),
      channel_map: channel_map,
      key_collections: Keyword.fetch!(config, :key_collections),
      key_map: Keyword.fetch!(config, :key_map),
      keyboard_channels: Keyword.get(config, :default_values, %{}),
      publish_keyboard_loop_interval_ms:
        Keyword.fetch!(config, :publish_keyboard_loop_interval_ms),
      subscriber_groups: Keyword.fetch!(config, :subscriber_groups),
      connect_keyboard_timer: connect_keyboard_timer
    }

    ViaUtils.Comms.join_group(__MODULE__, @remote_input_found_group, self())
    {:ok, state}
  end

  def handle_info(@connect_to_keyboard_loop, state) do
    {keyboard_input_name, keyboard} = ViaInputEvent.Utils.find_keyboard()

    state =
      if is_nil(keyboard) do
        Logger.warn("Keyboard not found. Retrying in 1000ms.")
        Process.sleep(1000)
        # GenServer.cast(self(), :connect_to_keyboard)
        state
      else
        Logger.debug("found keyboard: #{inspect(keyboard)}")
        InputEvent.start_link(keyboard_input_name)

        connect_keyboard_timer = ViaUtils.Process.stop_loop(state.connect_keyboard_timer)

        ViaUtils.Comms.send_local_msg_to_group(
          __MODULE__,
          @remote_input_found_group,
          @remote_input_found_group,
          self()
        )

        GenServer.cast(
          __MODULE__,
          {@wait_for_all_channels_loop, state.publish_keyboard_loop_interval_ms}
        )

        %{
          state
          | keyboard_input_name: keyboard_input_name,
            keyboard: keyboard,
            connect_keyboard_timer: connect_keyboard_timer
        }
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:input_event, _input_name, events}, state) do
    keyboard_channels = state.keyboard_channels
    key_map = state.key_map
    key_collections = state.key_collections
    channel_map = state.channel_map
    pcl = round((Map.get(keyboard_channels, 5, -1) + 1) * 1.5) + 1

    {keyboard_channels, key_collections} =
      Enum.reduce(events, {keyboard_channels, key_collections}, fn event,
                                                                   {acc_keyboard_channels,
                                                                    acc_key_collections} ->
        {type, key, pressed} = event

        if type == :ev_key and pressed == 1 do
          key_operations = Map.get(key_map, key, [])
          first_operation = Enum.at(key_operations, 0)

          new_pcl =
            if length(key_operations) > 0 and elem(first_operation, 0) == :pcl do
              elem(first_operation, 2) |> Enum.at(0)
            else
              pcl
            end

          Enum.reduce(
            key_operations,
            {acc_keyboard_channels, acc_key_collections},
            fn key_operation, {acc_acc_keyboard_channels, acc_acc_key_collections} ->
              {key_collection_key, operation, args} = key_operation

              if is_nil(key_collection_key) do
                {acc_acc_keyboard_channels, acc_acc_key_collections}
              else
                key_type = Map.fetch!(key_collections, key_collection_key)

                args =
                  if key_collection_key == :thrust_axis and args == :pcl_hold do
                    {_, output} = KC.get_output(key_type, pcl, :get_output, [])
                    [output]
                  else
                    args
                  end

                {key_action, output} = KC.get_output(key_type, new_pcl, operation, args)
                channel_number = Map.fetch!(channel_map, key_collection_key)

                {Map.put(acc_acc_keyboard_channels, channel_number, output),
                 Map.put(acc_acc_key_collections, key_collection_key, key_action)}
              end
            end
          )
        else
          {acc_keyboard_channels, acc_key_collections}
        end
      end)

    {:noreply, %{state | keyboard_channels: keyboard_channels, key_collections: key_collections}}
  end

  @impl GenServer
  def handle_info(@publish_keyboard_loop, state) do
    channel_values = get_channels(state.keyboard_channels, state.num_channels)

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
    connect_keyboard_timer = ViaUtils.Process.stop_loop(state.connect_keyboard_timer)
    {:noreply, %{state | connect_keyboard_timer: connect_keyboard_timer}}
  end

  @impl GenServer
  def handle_cast({@wait_for_all_channels_loop, publish_keyboard_loop_interval_ms}, state) do
    Logger.debug("wait for channels. currently have: #{inspect(state.keyboard_channels)}")

    if length(get_channels(state.keyboard_channels, state.num_channels)) == state.num_channels do
      ViaUtils.Process.start_loop(
        self(),
        publish_keyboard_loop_interval_ms,
        @publish_keyboard_loop
      )
    else
      Process.sleep(100)

      GenServer.cast(
        __MODULE__,
        {@wait_for_all_channels_loop, publish_keyboard_loop_interval_ms}
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
  def get_channels(keyboard_channels, num_channels) do
    keyboard_channels
    |> Map.to_list()
    |> Enum.sort(fn {k1, _val1}, {k2, _val2} -> k1 < k2 end)
    |> Enum.reduce([], fn {_k, v}, acc -> [v] ++ acc end)
    |> Enum.reverse()
    |> Enum.take(num_channels)
  end

  @spec get_analog_min_max(struct()) :: tuple()
  def get_analog_min_max(keyboard) do
    stick_settings = keyboard.report_info |> Keyword.fetch!(:ev_abs) |> Keyword.fetch!(:abs_x)
    {stick_settings.min, stick_settings.max}
  end
end
