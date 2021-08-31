defmodule Keyboard.KeyboardMapTest do
  use ExUnit.Case
  alias ViaInputEvent.KeypressAction, as: KA
  alias ViaInputEvent.KeyType, as: KT
  require Logger

  setup %{} do
    ViaUtils.Comms.Supervisor.start_link([])
    {:ok, []}
  end

  test "Key Type" do
    key_actions = %{
      roll_axis:
        KT.new_pcl(
          KA.new_discrete(-360, 360, 60, 0),
          KA.new_discrete(-60, 60, 5, 0),
          KA.new_discrete(-30, 30, 5, 0)
        )
    }
    key_type = key_actions.roll_axis
    result = KT.get_output(key_type, 1, :add, [])
    Logger.debug("result: #{inspect(result)}")
  end
end
