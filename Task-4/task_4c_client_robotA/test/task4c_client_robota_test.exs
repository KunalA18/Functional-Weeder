defmodule Task4CClientRobotATest do
  use ExUnit.Case
  doctest Task4CClientRobotA

  test "rotates the robot to the right" do
    {:ok, robot} = Task4CClientRobotA.start(1, :a, :north)
    position = robot |> Task4CClientRobotA.right |> Task4CClientRobotA.report
    assert position == {1, :a, :east}

    position = robot |> Task4CClientRobotA.right |> Task4CClientRobotA.right |> Task4CClientRobotA.report
    assert position == {1, :a, :south}
  end

  test "rotates the robot to the left" do
    {:ok, robot} = Task4CClientRobotA.start(4, :d, :north)
    position = robot |> Task4CClientRobotA.left |> Task4CClientRobotA.report

    assert position == {4, :d, :west}
  end

  test "rotating the robot 3 times to the right is the same as rotate its to the left" do
    {:ok, robot} = Task4CClientRobotA.start(3, :c, :north)
    right_position = robot |> Task4CClientRobotA.right |> Task4CClientRobotA.right |> Task4CClientRobotA.right |> Task4CClientRobotA.report
    left_position = robot |> Task4CClientRobotA.left |> Task4CClientRobotA.report

    assert right_position == left_position
  end

  test "moving robot up if it is facing to the north" do
    {:ok, robot} = Task4CClientRobotA.start(1, :c, :north)
    position = robot |> Task4CClientRobotA.move |> Task4CClientRobotA.report

    assert position == {1, :d, :north}
  end

  test "moving robot right if it is facing to the east" do
    {:ok, robot} = Task4CClientRobotA.start(2, :c, :east)
    position = robot |> Task4CClientRobotA.move |> Task4CClientRobotA.report

    assert position == {3, :c, :east}
  end

  test "moving robot down if it is facing to the south" do
    {:ok, robot} = Task4CClientRobotA.start(4, :c, :south)
    position = robot |> Task4CClientRobotA.move |> Task4CClientRobotA.report

    assert position == {4, :b, :south}
  end

  test "moving robot left if it is facing to the west" do
    {:ok, robot} = Task4CClientRobotA.start(4, :d, :west)
    position = robot |> Task4CClientRobotA.move |> Task4CClientRobotA.report

    assert position == {3, :d, :west}
  end

  test "prevent the robot to fall going north" do
    {:ok, robot} = Task4CClientRobotA.start(6, :f, :north)
    position = robot |> Task4CClientRobotA.move |> Task4CClientRobotA.report

    assert position == {6, :f, :north}
  end

  test "prevent the robot to fall going east" do
    {:ok, robot} = Task4CClientRobotA.start(6, :f, :east)
    position = robot |> Task4CClientRobotA.move |> Task4CClientRobotA.report

    assert position == {6, :f, :east}
  end

  test "prevent the robot to fall going south" do
    {:ok, robot} = Task4CClientRobotA.start(1, :a, :south)
    position = robot |> Task4CClientRobotA.move |> Task4CClientRobotA.report

    assert position == {1, :a, :south}
  end

  test "prevent the robot to fall going west" do
    {:ok, robot} = Task4CClientRobotA.start(1, :f, :west)
    position = robot |> Task4CClientRobotA.move |> Task4CClientRobotA.report

    assert position == {1, :f, :west}
  end
end
