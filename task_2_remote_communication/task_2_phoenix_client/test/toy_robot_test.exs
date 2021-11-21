defmodule ToyRobotTest do
  use ExUnit.Case
  doctest ToyRobot

  test "rotates the robot to the right" do
    {:ok, robot} = ToyRobot.start(1, :a, :north)
    position = robot |> ToyRobot.right |> ToyRobot.report
    assert position == {1, :a, :east}

    position = robot |> ToyRobot.right |> ToyRobot.right |> ToyRobot.report
    assert position == {1, :a, :south}
  end

  test "rotates the robot to the left" do
    {:ok, robot} = ToyRobot.start(4, :d, :north)
    position = robot |> ToyRobot.left |> ToyRobot.report

    assert position == {4, :d, :west}
  end

  test "rotating the robot 3 times to the right is the same as rotate its to the left" do
    {:ok, robot} = ToyRobot.start(3, :c, :north)
    right_position = robot |> ToyRobot.right |> ToyRobot.right |> ToyRobot.right |> ToyRobot.report
    left_position = robot |> ToyRobot.left |> ToyRobot.report

    assert right_position == left_position
  end

  test "moving robot up if it is facing to the north" do
    {:ok, robot} = ToyRobot.start(1, :c, :north)
    position = robot |> ToyRobot.move |> ToyRobot.report

    assert position == {1, :d, :north}
  end

  test "moving robot right if it is facing to the east" do
    {:ok, robot} = ToyRobot.start(2, :c, :east)
    position = robot |> ToyRobot.move |> ToyRobot.report

    assert position == {3, :c, :east}
  end

  test "moving robot down if it is facing to the south" do
    {:ok, robot} = ToyRobot.start(4, :c, :south)
    position = robot |> ToyRobot.move |> ToyRobot.report

    assert position == {4, :b, :south}
  end

  test "moving robot left if it is facing to the west" do
    {:ok, robot} = ToyRobot.start(4, :d, :west)
    position = robot |> ToyRobot.move |> ToyRobot.report

    assert position == {3, :d, :west}
  end

  test "prevent the robot to fall going north" do
    {:ok, robot} = ToyRobot.start(5, :e, :north)
    position = robot |> ToyRobot.move |> ToyRobot.report

    assert position == {5, :e, :north}
  end

  test "prevent the robot to fall going east" do
    {:ok, robot} = ToyRobot.start(5, :e, :east)
    position = robot |> ToyRobot.move |> ToyRobot.report

    assert position == {5, :e, :east}
  end

  test "prevent the robot to fall going south" do
    {:ok, robot} = ToyRobot.start(1, :a, :south)
    position = robot |> ToyRobot.move |> ToyRobot.report

    assert position == {1, :a, :south}
  end

  test "prevent the robot to fall going west" do
    {:ok, robot} = ToyRobot.start(1, :e, :west)
    position = robot |> ToyRobot.move |> ToyRobot.report

    assert position == {1, :e, :west}
  end
end
