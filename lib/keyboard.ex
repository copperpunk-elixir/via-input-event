defmodule ViaInputEvent.Keyboard do
  use GenServer
  require Logger
  alias ViaInputEvent.KeypressAction, as: KA
  alias ViaInputEvent.KeyType, as: KT

  @publish_keyboard_loop :publish_keyboard_loop
  @wait_for_all_channels_loop :wait_for_all_channels_loop

  def start_link(config) do
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    ViaUtils.Comms.Supervisor.start_operator(__MODULE__)
    channel_map = Keyword.fetch!(config, :channel_map)

    state = %{
      keyboard_input_name: nil,
      keyboard: nil,
      num_channels: get_num_channels(channel_map),
      channel_map: channel_map,
      key_actions: Keyword.fetch!(config, :key_actions),
      key_map: Keyword.fetch!(config, :key_map),
      keyboard_channels: Keyword.get(config, :default_values, %{}),
      publish_keyboard_loop_interval_ms:
        Keyword.fetch!(config, :publish_keyboard_loop_interval_ms),
      subscriber_groups: Keyword.fetch!(config, :subscriber_groups)
    }

    GenServer.cast(__MODULE__, :connect_to_keyboard)
    {:ok, state}
  end

  def handle_cast(:connect_to_keyboard, state) do
    {keyboard_input_name, keyboard} = ViaInputEvent.Utils.find_keyboard()

    state =
      if is_nil(keyboard) do
        Logger.warn("Keyboard not found. Retrying in 1000ms.")
        Process.sleep(1000)
        GenServer.cast(self(), :connect_to_keyboard)
        state
      else
        Logger.debug("found keyboard: #{inspect(keyboard)}")
        InputEvent.start_link(keyboard_input_name)

        # GenServer.cast(
        #   __MODULE__,
        #   {@wait_for_all_channels_loop, state.publish_keyboard_loop_interval_ms}
        # )

        %{
          state
          | keyboard_input_name: keyboard_input_name,
            keyboard: keyboard
        }
      end

    {:noreply, state}
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

  @impl GenServer
  def handle_info({:input_event, _input_name, events}, state) do
    Logger.debug("events: #{inspect(events)}")
    keyboard_channels = state.keyboard_channels
    key_map = state.key_map
    key_actions = state.key_actions
    channel_map = state.channel_map
    pcl = round(Map.get(keyboard_channels, 5, -1) + 2)

    Logger.debug("pcl: #{pcl}")

    {keyboard_channels, key_actions} =
      Enum.reduce(events, {keyboard_channels, key_actions}, fn event,
                                                               {acc_keyboard_channels,
                                                                acc_key_actions} ->
        Logger.debug("event: #{inspect(event)}")
        {type, key, pressed} = event

        if type == :ev_key and pressed == 1 do
          Logger.debug("key event: #{inspect(key)}")
          {key_action_key, operation, args} = Map.fetch!(key_map, key)

          Logger.debug("kAk: #{key_action_key}")
          Logger.debug("opertion: #{operation}")
          key_type = Map.fetch!(key_actions, key_action_key)
          Logger.debug("key type: #{inspect(key_type)}")
          {key_action, output} = KT.get_output(key_type, pcl, operation, args)

          Logger.debug("key action: #{inspect(key_action)}")
          Logger.debug("output: #{output}")
          channel_number = Map.fetch!(channel_map, key_action_key)
          Logger.debug("channeL_number: #{channel_number}")

          {Map.put(acc_keyboard_channels, channel_number, output),
           Map.put(key_actions, key_action_key, key_action)}
        else
          {acc_keyboard_channels, acc_key_actions}
        end
      end)

    # state =
    #   if input_name == state.keyboard_input_name do
    #     channel_map = state.channel_map

    {:noreply, %{state | keyboard_channels: keyboard_channels, key_actions: key_actions}}
  end

  @impl GenServer
  def handle_info(@publish_keyboard_loop, state) do
    channel_values = get_channels(state.keyboard_channels, state.num_channels)
    Logger.debug("#{ViaUtils.Format.eftb_map(state.keyboard_channels, 3)}")
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
