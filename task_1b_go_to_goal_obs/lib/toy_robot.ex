defmodule ToyRobot do
  # max x-coordinate of table top
  @table_top_x 5
  # max y-coordinate of table top
  @table_top_y :e
  # mapping of y-coordinates
  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5}


  @doc """
  Places the robot to the default position of (1, A, North)
  Examples:
      iex> ToyRobot.place
      {:ok, %ToyRobot.Position{facing: :north, x: 1, y: :a}}
  """

  def place do
    {:ok, %ToyRobot.Position{}}
  end

  def place(x, y, _facing) when x < 1 or y < :a or x > @table_top_x or y > @table_top_y do
    {:failure, "Invalid position"}
  end

  def place(_x, _y, facing)
  when facing not in [:north, :east, :south, :west]
  do
    {:failure, "Invalid facing direction"}
  end

  @doc """
  Places the robot to the provided position of (x, y, facing),
  but prevents it to be placed outside of the table and facing invalid direction.
  Examples:
      iex> ToyRobot.place(1, :b, :south)
      {:ok, %ToyRobot.Position{facing: :south, x: 1, y: :b}}
      iex> ToyRobot.place(-1, :f, :north)
      {:failure, "Invalid position"}
      iex> ToyRobot.place(3, :c, :north_east)
      {:failure, "Invalid facing direction"}
  """
  def place(x, y, facing) do
    {:ok, %ToyRobot.Position{x: x, y: y, facing: facing}}
  end

  @doc """
  Provide START position to the robot as given location of (x, y, facing) and place it.
  """
  def start(x, y, facing) do
    ToyRobot.place(x, y, facing)
  end

  def start() do
    ToyRobot.place(1,:a,:north)
  end

  def stop(_robot, goal_x, goal_y, _cli_proc_name) when goal_x < 1 or goal_y < :a or goal_x > @table_top_x or goal_y > @table_top_y do
    {:failure, "Invalid STOP position"}
  end

  @doc """
  Provide STOP position to the robot as given location of (x, y) and plan the path from START to STOP.
  Passing the CLI Server process name that will be used to send robot's current status after each action is taken.
  Spawn a process and register it with name ':client_toyrobot' which is used by CLI Server to send an
  indication for the presence of obstacle ahead of robot's current position and facing.
  """
  def stop(robot, goal_x, goal_y, cli_proc_name) do
    ###########################
    ## complete this funcion ##
    ###########################
    {x, y, facing} = report(robot)

    diff_x = goal_x - x
    diff_y = @robot_map_y_atom_to_num[goal_y] - @robot_map_y_atom_to_num[y]

    face_x = if diff_x >= 0 do
      :east
    else
      :west
    end
    face_y = if diff_y >=0 do
      :north
    else
      :south
    end

    Process.register(self(), :client_toyrobot)
    send_robot_status(robot, cli_proc_name)

    robot = turn(robot,face_y, cli_proc_name)
    {_, robot,diff_y} = path_y(robot, diff_y, cli_proc_name)

    robot = turn(robot, face_x, cli_proc_name)
    {_, robot,diff_x} = path_x(robot, diff_x, cli_proc_name)

    robot = loop(robot,diff_x,diff_y,cli_proc_name,face_x,face_y,goal_x,goal_y)
  end

  def loop(robot,diff_x,diff_y,cli_proc_name,face_x,face_y,goal_x,goal_y) do

    cond do
      diff_x == 0 and diff_y != 0 ->

        obs_ahead = send_robot_status(robot, cli_proc_name)
        if obs_ahead do
          diff_x =1
        else
          diff_x=0
        end

        robot = turn(robot, face_x, cli_proc_name)
        {_, robot,diff_x} = path_x(robot, diff_x, cli_proc_name)
        robot = turn(robot,face_y, cli_proc_name)
        {_, robot,diff_y} = path_y(robot, diff_y, cli_proc_name)
        {x, y, facing} = report(robot)
        diff_x = goal_x - x
        diff_y = @robot_map_y_atom_to_num[goal_y] - @robot_map_y_atom_to_num[y]
        loop(robot,diff_x,diff_y,cli_proc_name,face_x,face_y,goal_x,goal_y)

      diff_x != 0 and diff_y == 0 ->
        obs_ahead = send_robot_status(robot, cli_proc_name)
        if obs_ahead do
          diff_y = 1
        else
          diff_y = 0
        end
        robot = turn(robot,face_y, cli_proc_name)
        {_, robot,diff_y} = path_y(robot, diff_y, cli_proc_name)
        robot = turn(robot, face_x, cli_proc_name)
        {_, robot,diff_x} = path_x(robot, diff_x, cli_proc_name)
        {x, y, facing} = report(robot)
        diff_x = goal_x - x
        diff_y = @robot_map_y_atom_to_num[goal_y] - @robot_map_y_atom_to_num[y]
        loop(robot,diff_x,diff_y,cli_proc_name,face_x,face_y,goal_x,goal_y)

      #diff_x!=0 and diff_y!=0 ->
      diff_x == 0 and diff_y == 0 ->
        robot


    end

  end

  def turn(%ToyRobot.Position{facing: facing} = robot, current_face, cli_proc_name) do
    obs_ahead = send_robot_status(robot, cli_proc_name)


    if (current_face == facing and obs_ahead==false) do
      robot

    else
      robot = right(robot)
      send_robot_status(robot, cli_proc_name)
      turn(robot, current_face, cli_proc_name)
    end

  end

  def path_x(%ToyRobot.Position{x: x, y: y, facing: facing} = robot, difference, cli_proc_name) do
    obs_ahead = send_robot_status(robot, cli_proc_name)


    if difference != 0 do

      if difference > 0 do
        if obs_ahead== false do
          robot = move(robot)

          difference = difference - 1
          path_x(robot, difference, cli_proc_name)
        else
          {:ok, robot,difference}
        end
      else
        if obs_ahead== false do
          robot = move(robot)

          difference = difference + 1
          path_x(robot, difference, cli_proc_name)
        else
          {:ok, robot,difference}
        end
      end
    else
      {:ok, robot,difference}
    end
  end

  def path_y(%ToyRobot.Position{x: x, y: y, facing: facing} = robot, difference, cli_proc_name) do
    obs_ahead = send_robot_status(robot, cli_proc_name)


    if difference != 0 do

      if difference > 0 do
        if obs_ahead== false do
          robot = move(robot)

          difference = difference - 1
          path_y(robot, difference, cli_proc_name)
        else
          {:ok, robot,difference}
        end
      else
        if obs_ahead== false do
          robot = move(robot)

          difference = difference + 1
          path_y(robot, difference, cli_proc_name)
        else
          {:ok, robot,difference}
        end
      end
    else
      {:ok, robot,difference}

    end
  end


  @doc """
  Send Toy Robot's current status i.e. location (x, y) and facing
  to the CLI Server process after each action is taken.
  Listen to the CLI Server and wait for the message indicating the presence of obstacle.
  The message with the format: '{:obstacle_presence, < true or false >}'.
  """
  def send_robot_status(%ToyRobot.Position{x: x, y: y, facing: facing} = _robot, cli_proc_name) do
    send(cli_proc_name, {:toyrobot_status, x, y, facing})
    # IO.puts("Sent by Toy Robot Client: #{x}, #{y}, #{facing}")
    listen_from_server()
  end

  @doc """
  Listen to the CLI Server and wait for the message indicating the presence of obstacle.
  The message with the format: '{:obstacle_presence, < true or false >}'.
  """
  def listen_from_server() do
    receive do
      {:obstacle_presence, is_obs_ahead} -> is_obs_ahead
        #listen_from_server()
    end
  end

  @doc """
  Provides the report of the robot's current position
  Examples:
      iex> {:ok, robot} = ToyRobot.place(2, :b, :west)
      iex> ToyRobot.report(robot)
      {2, :b, :west}
  """
  def report(%ToyRobot.Position{x: x, y: y, facing: facing} = _robot) do
    {x, y, facing}
  end

  @directions_to_the_right %{north: :east, east: :south, south: :west, west: :north}
  @doc """
  Rotates the robot to the right
  """
  def right(%ToyRobot.Position{facing: facing} = robot) do
    %ToyRobot.Position{robot | facing: @directions_to_the_right[facing]}
  end

  @directions_to_the_left Enum.map(@directions_to_the_right, fn {from, to} -> {to, from} end)
  @doc """
  Rotates the robot to the left
  """
  def left(%ToyRobot.Position{facing: facing} = robot) do
    %ToyRobot.Position{robot | facing: @directions_to_the_left[facing]}
  end

  @doc """
  Moves the robot to the north, but prevents it to fall
  """
  def move(%ToyRobot.Position{x: _, y: y, facing: :north} = robot) when y < @table_top_y do
    %ToyRobot.Position{robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) + 1 end) |> elem(0)}
  end

  @doc """
  Moves the robot to the east, but prevents it to fall
  """
  def move(%ToyRobot.Position{x: x, y: _, facing: :east} = robot) when x < @table_top_x do
    %ToyRobot.Position{robot | x: x + 1}
  end

  @doc """
  Moves the robot to the south, but prevents it to fall
  """
  def move(%ToyRobot.Position{x: _, y: y, facing: :south} = robot) when y > :a do
    %ToyRobot.Position{robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) - 1 end) |> elem(0)}
  end

  @doc """
  Moves the robot to the west, but prevents it to fall
  """
  def move(%ToyRobot.Position{x: x, y: _, facing: :west} = robot) when x > 1 do
    %ToyRobot.Position{robot | x: x - 1}
  end

  @doc """
  Does not change the position of the robot.
  This function used as fallback if the robot cannot move outside the table
  """
  def move(robot), do: robot

  def failure do
    raise "Connection has been lost"
  end
end
