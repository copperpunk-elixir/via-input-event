defmodule Joystick.JoystickMapTest do
  use ExUnit.Case

  setup %{} do
    ViaUtils.Comms.Supervisor.start_link([])
    {:ok, []}
  end

  test "Open Joystick With Map" do
    config = [
      channel_map: %{
        :abs_x => 0,
        :abs_y => 1,
        :abs_z => 2,
        :abs_rx => 3,
        :abs_ry => 4,
        :abs_rz => 5,
        :abs_throttle => 6,
        :btn_b => 9
      },
      default_values: %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => -1,
        5 => -1,
        6 => -1,
        7 => 0,
        8 => 0,
        9 => 1
      },
      subscriber_groups: [],
      publish_joystick_loop_interval_ms: 20
    ]

    ViaInputEvent.FrskyJoystick.start_link(config)
    Process.sleep(1_000_000)
  end
end
