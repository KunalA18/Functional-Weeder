defmodule Stack do
  @moduledoc """
  Stack is a stack of values
  """


  @typedoc "a value stored on the stack"
  @type value :: any

  @typedoc "a stack"
  @type t :: %Stack{ array: [value] }
  defstruct array: []

  @doc """
  Return a new Stack
  """
  @spec new() :: Stack.t
  def new do
    %Stack{}
  end

  @doc """
  Return the size of the Stack
  """
  @spec size(Stack.t) :: non_neg_integer
  def size(%Stack{array: array}) do
    length(array)
  end

  @doc """
  Push a value onto the Stack
  """
  @spec push(Stack.t, value) :: Stack.t
  def push(%Stack{array: array}, item) do
    %Stack{ array: [item | array] }
  end

  @doc """
  Pop the last value off the Stack
  """
  @spec pop(Stack.t) :: {value, Stack.t}
  def pop(%Stack{ array: [item | rest]}) do
    {item,  %Stack{ array: rest }}
  end
  def pop(stack = %Stack{ array: []}) do
    {nil, stack}
  end
end
