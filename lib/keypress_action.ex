defmodule ViaInputEvent.KeypressAction do
  alias ViaInputEvent.KeypressAction
  require Logger

  defstruct min_value: nil,
            max_value: nil,
            delta_value: nil,
            multiplier: nil,
            value: nil

  @output_min -1
  @output_max 1

  @spec new_discrete(number(), number(), number(), number()) :: struct()
  def new_discrete(min_value, max_value, delta_value, starting_value) do
    multiplier = (@output_max - @output_min) / (max_value - min_value)

    %KeypressAction{
      min_value: min_value,
      max_value: max_value,
      delta_value: delta_value,
      multiplier: multiplier,
      value: starting_value
    }
  end

  @spec new_toggle(number()) :: struct()
  def new_toggle(starting_value) do
    %KeypressAction{
      min_value: -1,
      max_value: 1,
      multiplier: 1,
      value: starting_value
    }
  end

  @spec add(struct()) :: tuple()
  def add(key) do
    value = ViaUtils.Math.constrain(key.value + key.delta_value, key.min_value, key.max_value)
    output = get_output_for_value(key, value)
    {%{key | value: value}, output}
  end

  @spec subtract(struct()) :: tuple()
  def subtract(key) do
    value = ViaUtils.Math.constrain(key.value - key.delta_value, key.min_value, key.max_value)
    output = get_output_for_value(key, value)
    {%{key | value: value}, output}
  end

  @spec set(struct(), number()) :: tuple()
  def set(key, value) do
    output = get_output_for_value(key, value)
    {%{key | value: value}, output}
  end

  @spec zero(struct()) :: tuple()
  def zero(key) do
    set(key, 0)
  end

  @spec toggle(struct()) :: tuple()
  def toggle(key) do
    set(key, key.value * -1)
  end

  @spec increment(struct()) :: tuple()
  def increment(key) do
    value = key.value + key.delta_value
    value = if value > key.max_value, do: key.min_value, else: value
    output = get_output_for_value(key, value)
    {%{key | value: value}, output}
  end

  @spec set_value_for_output(struct(), number()) :: tuple()
  def set_value_for_output(key, output) do
    value = get_value_for_output(key, output)
    {%{key | value: value}, output}
  end

  @spec get(struct()) :: tuple()
  def get(key) do
    {key, key.value}
  end

  @spec get_output(struct()) :: tuple()
  def get_output(key) do
    {key, get_output_for_value(key, key.value)}
  end

  @spec get_output_for_value(struct(), number()) :: number()
  def get_output_for_value(key, x) do
    (x - key.min_value) * key.multiplier + @output_min
  end

  @spec get_value_for_output(struct(), number()) :: number()
  def get_value_for_output(key, x) do
    (x - @output_min) / key.multiplier + key.min_value
  end
end
