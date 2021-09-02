defmodule ViaInputEvent.KeyCollection do
  alias ViaInputEvent.KeyCollection
  alias ViaInputEvent.KeypressAction, as: KA
  require Logger

  defstruct scope: nil,
            actions: nil

  def new_all(action) do
    %KeyCollection{scope: :all, actions: action}
  end

  def new_pcl(action_pcl1, action_pcl2, action_pcl4) do
    %KeyCollection{
      scope: :pcl,
      actions: %{
        1 => action_pcl1,
        2 => action_pcl2,
        4 => action_pcl4
      }
    }
  end

  def get_output(key_collection, pcl, operation, args) do
    case key_collection.scope do
      :all ->
        action = key_collection.actions
        {action, output} = apply(KA, operation, [action] ++ args)
        {%{key_collection | actions: action}, output}

      :pcl ->
        actions = key_collection.actions
        action = Map.fetch!(actions, pcl)
        {action, output} = apply(KA, operation, [action] ++ args)
        actions = Map.put(actions, pcl, action)
        {%{key_collection | actions: actions}, output}
    end
  end
end
