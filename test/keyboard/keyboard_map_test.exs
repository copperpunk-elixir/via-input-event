defmodule Keyboard.KeyboardMapTest do
  use ExUnit.Case
  alias ViaInputEvent.KeypressAction, as: KA
  alias ViaInputEvent.KeyType, as: KT

  setup %{} do
    ViaUtils.Comms.Supervisor.start_link([])
    {:ok, []}
  end

  test "Open Keyboard With Map" do
    config = [
      key_actions: %{
        roll_axis:
          KT.new_pcl(
            KA.new_discrete(-360, 360, 60, 0),
            KA.new_discrete(-60, 60, 5, 0),
            KA.new_discrete(-30, 30, 5, 0)
          ),
        pitch_axis:
          KT.new_pcl(
            KA.new_discrete(-180, 180, 60, 0),
            KA.new_discrete(-30, 30, 5, 0),
            KA.new_discrete(-5, 5, 1, 0)
          ),
        yaw_axis:
          KT.new_pcl(
            KA.new_discrete(-180, 180, 60, 0),
            KA.new_discrete(-45, 45, 5, 0),
            KA.new_discrete(-15, 15, 5, 0)
          ),
        thrust_axis:
          KT.new_pcl(
            KA.new_discrete(0, 1, 0.1, 0),
            KA.new_discrete(0, 1, 0.1, 0),
            KA.new_discrete(0, 65, 5, 0)
          ),
        flaps: KT.new_all(KA.new_discrete(0, 1, 0.5, 0)),
        gear: KT.new_all(KA.new_toggle(-1)),
        pcl: KT.new_all(KA.new_discrete(1, 3, 1, 1))
      },
      key_map: %{
        key_a: {:yaw_axis, :subtract, []},
        key_d: {:yaw_axis, :add, []},
        key_s: {:thrust_axis, :subtract, []},
        key_w: {:thrust_axis, :add, []},
        key_left: {:roll_axis, :subtract, []},
        key_right: {:thrust_axis, :add, []},
        key_up: {:pitch_axis, :subtract, []},
        key_down: {:pitch_axis, :add, []},
        key_1: {:pcl, :set, [1]},
        key_2: {:pcl, :set, [2]},
        key_3: {:pcl, :set, [3]},
        key_f: {:flaps, :increment, []},
        key_g: {:gear, :toggle, []}
      },
      channel_map: %{
        roll_axis: 0,
        pitch_axis: 1,
        thrust_axis: 2,
        yaw_axis: 3,
        flaps: 4,
        pcl: 5,
        gear: 9
      },
      default_values: %{
        0 => 0,
        1 => 0,
        2 => 0,
        3 => 0,
        4 => -1,
        5 => -1,
        6 => 0,
        7 => 0,
        8 => 0,
        9 => 1
      },
      subscriber_groups: [],
      publish_keyboard_loop_interval_ms: 20
    ]

    ViaInputEvent.Keyboard.start_link(config)
    Process.sleep(1_000_000)
  end
end
