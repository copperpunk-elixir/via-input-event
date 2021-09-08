defmodule Joystick.SpektrumMapTest do
  use ExUnit.Case

  setup %{} do
    ViaUtils.Comms.Supervisor.start_link([])
    {:ok, []}
  end

  test "Open Joystick With Map" do
    config = [
      channel_map: %{
        Spektrum: %{
          multiplier: 1/0.662,
          abs_z: 0,
          abs_rx: 1,
          abs_y: 2,
          abs_x: 3,
          abs_ry: 4,
          abs_throttle: 5,
          none: 6,
          btn_rz: 9
        }
      },
      default_values: %{
        0 => 0,
        1 => 0,
        2 => -1.0,
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

    ViaInputEvent.Joystick.start_link(config)
    Process.sleep(1_000_000)
  end
end
