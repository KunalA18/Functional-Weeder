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
    ###########################
    ## complete this funcion ##
    ###########################
    Process.register(self(),:client_toyrobot)
    ToyRobot.place(x,y,facing)
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
    {x,y,facing} = report(robot)
    dist_x = goal_x - x
    dist_y = @robot_map_y_atom_to_num[goal_y] - @robot_map_y_atom_to_num[y]

    x_desired_dir = if dist_x >= 0, do: :east, else: :west
    y_desired_dir = if dist_y >= 0, do: :north, else: :south


    {x,y,facing} = report(robot)
    send_robot_status(robot, cli_proc_name)

    robot = rotate(robot, x_desired_dir, cli_proc_name)
    {_, robot} = navigate_path(robot, dist_x, cli_proc_name)
    {x, y, facing} = report(robot)

    robot = rotate(robot, y_desired_dir, cli_proc_name)
    {_, robot} = navigate_path(robot, dist_y, cli_proc_name)
    {x, y, facing} = report(robot)

    #adding the current cell to a visited list
    current_cell = [x,y]
    visited_cells = [current_cell]
    obstacle_presence = send_robot_status(robot, cli_proc_name)

    #generating a list of the possible cells it could travel to
    cell_list = []
    cell_list = possible_cells(robot, x, y, dist_x, dist_y, goal_x, goal_y, facing, visited_cells, cell_list)
  
  end
  
  def possible_cells(robot, x, y, x_diff, y_diff, goal_x, goal_y, facing, visited_cells, cells) do
    #visited cells contains the coordinates of the current cell
    #if the robot is on (3,a) then it can go to (2,a),(3,b) and (4,a) but it can't go south
    #if the robot is on (3,c) then it can travel in all 4 directions
    cond do
      x_diff == 0 and y_diff == 0 ->
        robot
      true->
        y = @robot_map_y_atom_to_num[y] #converting y to a number
        cells = [east: absolute_distance(x+1, y, goal_x, goal_y), west: absolute_distance(x-1, y, goal_x, goal_y), north: absolute_distance(x, y+1, goal_x, goal_y), south: absolute_distance(x, y-1, goal_x, goal_y)]
        cells = cells |> List.keysort(1)
        
    end
  end
  
  # arrange cells using their absolute distance from the goal 
  
  def rotate(%ToyRobot.Position{facing: facing} = robot, face, cli_proc_name) do
    if face == facing do
      robot
    else
      robot = right(robot)
      send_robot_status(robot, cli_proc_name)
      rotate(robot, face, cli_proc_name)
    end
  end

  def navigate_path(robot, diff, cli_proc_name) do
    if diff != 0 do
      cond do
        diff > 0 ->
          robot = move(robot)
          send_robot_status(robot, cli_proc_name)
          diff = diff-1
          navigate_path(robot, diff, cli_proc_name)
        diff <= 0 ->
          robot = move(robot)
          send_robot_status(robot, cli_proc_name)
          diff = diff+1
          navigate_path(robot, diff, cli_proc_name)
      end
    else
      {:ok, robot}
    end

  end

  def absolute_distance(a,b,c,d) do
    abs(a-c) + abs(b-d)
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
