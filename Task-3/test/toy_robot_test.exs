defmodule CLITest do
  use ExUnit.Case
  doctest CLI.ToyRobotA

  test "rotates the robot to the right" do
    {:ok, robot} = CLI.ToyRobotA.start(1, :a, :north)
    position = robot |> CLI.ToyRobotA.right |> CLI.ToyRobotA.report
    assert position == {1, :a, :east}

    position = robot |> CLI.ToyRobotA.right |> CLI.ToyRobotA.right |> CLI.ToyRobotA.report
    assert position == {1, :a, :south}
  end

  test "rotates the robot to the left" do
    {:ok, robot} = CLI.ToyRobotA.start(4, :d, :north)
    position = robot |> CLI.ToyRobotA.left |> CLI.ToyRobotA.report

    assert position == {4, :d, :west}
  end

  test "rotating the robot 3 times to the right is the same as rotate its to the left" do
    {:ok, robot} = CLI.ToyRobotA.start(3, :c, :north)
    right_position = robot |> CLI.ToyRobotA.right |> CLI.ToyRobotA.right |> CLI.ToyRobotA.right |> CLI.ToyRobotA.report
    left_position = robot |> CLI.ToyRobotA.left |> CLI.ToyRobotA.report

    assert right_position == left_position
  end

  test "moving robot up if it is facing to the north" do
    {:ok, robot} = CLI.ToyRobotA.start(1, :c, :north)
    position = robot |> CLI.ToyRobotA.move |> CLI.ToyRobotA.report

    assert position == {1, :d, :north}
  end

  test "moving robot right if it is facing to the east" do
    {:ok, robot} = CLI.ToyRobotA.start(2, :c, :east)
    position = robot |> CLI.ToyRobotA.move |> CLI.ToyRobotA.report

    assert position == {3, :c, :east}
  end

  test "moving robot down if it is facing to the south" do
    {:ok, robot} = CLI.ToyRobotA.start(4, :c, :south)
    position = robot |> CLI.ToyRobotA.move |> CLI.ToyRobotA.report

    assert position == {4, :b, :south}
  end

  test "moving robot left if it is facing to the west" do
    {:ok, robot} = CLI.ToyRobotA.start(4, :d, :west)
    position = robot |> CLI.ToyRobotA.move |> CLI.ToyRobotA.report

    assert position == {3, :d, :west}
  end

  test "prevent the robot to fall going north" do
    {:ok, robot} = CLI.ToyRobotA.start(5, :e, :north)
    position = robot |> CLI.ToyRobotA.move |> CLI.ToyRobotA.report

    assert position == {5, :e, :north}
  end

  test "prevent the robot to fall going east" do
    {:ok, robot} = CLI.ToyRobotA.start(5, :e, :east)
    position = robot |> CLI.ToyRobotA.move |> CLI.ToyRobotA.report

    assert position == {5, :e, :east}
  end

  test "prevent the robot to fall going south" do
    {:ok, robot} = CLI.ToyRobotA.start(1, :a, :south)
    position = robot |> CLI.ToyRobotA.move |> CLI.ToyRobotA.report

    assert position == {1, :a, :south}
  end

  test "prevent the robot to fall going west" do
    {:ok, robot} = CLI.ToyRobotA.start(1, :e, :west)
    position = robot |> CLI.ToyRobotA.move |> CLI.ToyRobotA.report

    assert position == {1, :e, :west}
  end
end
