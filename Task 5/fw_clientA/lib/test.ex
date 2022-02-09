defmodule CLI.Test do
  def print(x) do
    IO.inspect(x, label: "Printed in Test Module")
  end
end
