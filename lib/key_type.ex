defmodule ViaInputEvent.KeyType do
  alias ViaInputEvent.KeyType
  alias ViaInputEvent.KeypressAction, as: KA

  defstruct scope: nil,
            actions: nil

  def new_all(action) do
    %KeyType{scope: :all, actions: action}
  end

  def new_pcl(action_pcl1, action_pcl2, action_pcl3) do
    %KeyType{
      scope: :pcl,
      actions: %{
        1 => action_pcl1,
        2 => action_pcl2,
        3 => action_pcl3
      }
    }
  end

  def get_output(key_type, pcl, operation, args) do
    case key_type.scope do
      :all ->
        action = key_type.actions
        {action, output} = apply(KA, operation, [action] ++ args)
        {%{key_type | actions: action}, output}

      :pcl ->
        actions = key_type.actions
        action = Map.fetch!(actions, pcl)
        {action, output} = apply(KA, operation, [action] ++ args)
        actions = Map.put(actions, pcl, action)
        {%{key_type | actions: actions}, output}
    end
  end
end
