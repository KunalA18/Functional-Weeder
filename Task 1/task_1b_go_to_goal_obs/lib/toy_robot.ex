defmodule ToyRobot do
  # max x-coordinate of table top
  @table_top_x 5
  # max y-coordinate of table top
  @table_top_y :e
  # mapping of y-coordinates
  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5}
  # maps directions to numbers
  @dir_to_num %{:north => 1, :east => 2, :south => 3, :west => 4}

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
    ToyRobot.place(1,:a,:NORTH)
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
    #We need to plan the robot's route from start to end
    {x, y, facing} = report(robot) #puts the robot's current co-ordinates into x,y,facing
    diff_x = goal_x - x #+ve implies moving right
                        #-ve implies moving left

    diff_y = @robot_map_y_atom_to_num[goal_y] - @robot_map_y_atom_to_num[y]
    #+ve implies that it needs to go up
    #-ve implies that it needs to go down

    should_face_y = if diff_y >=0, do: :north, else: :south
    should_face_x = if diff_x >= 0, do: :east, else: :west

    #pid = spawn_link(fn -> listen_from_server() end)
    #pid = spawn_link(fn -> send_robot_status(robot, cli_proc_name) end)
    Process.register(self(), :client_toyrobot) #the process that is currently being executed is :client_toyrobot

    #here determine the direction of rotation
    # face_diff = @dir_to_num[facing] - @dir_to_num[should_face_x]

    IO.puts("Something Before")
    send_robot_status(robot, cli_proc_name)
    IO.puts("Something")


    # robot = rotate(robot, should_face_x, face_diff, cli_proc_name)
    # {_, robot} = navigate(robot, diff_x, cli_proc_name)


    # {x, y, facing} = report(robot)

    # face_diff = @dir_to_num[facing] - @dir_to_num[should_face_y]


    # robot = rotate(robot, should_face_y, face_diff, cli_proc_name)
    # {_, robot} = navigate(robot, diff_y, cli_proc_name)
    robot = loop(robot, diff_x, diff_y, should_face_x, should_face_y, facing, goal_x, goal_y, cli_proc_name)
    send_robot_status(robot, cli_proc_name)

  end

  def loop(robot, diff_x, diff_y, should_face_x, should_face_y, facing, goal_x, goal_y, cli_proc_name) do
    case diff_y == 0 and diff_x == 0 do
      false ->
        {x, y, facing} = report(robot)
        diff_x = goal_x - x #+ve implies moving right
                        #-ve implies moving left
        diff_y = @robot_map_y_atom_to_num[goal_y] - @robot_map_y_atom_to_num[y]
        #+ve implies that it needs to go up

        should_face_y = if diff_y >=0, do: :north, else: :south
        should_face_x = if diff_x >= 0, do: :east, else: :west

        face_diff = @dir_to_num[facing] - @dir_to_num[should_face_x]

        robot = rotate(robot, should_face_x, face_diff, cli_proc_name)
        {robot, prev} = navigate(robot, diff_x, goal_x, goal_y, [x,y], cli_proc_name)

        IO.inspect(robot, label: "robot after x")

        {x, y, facing} = report(robot)
        diff_x = goal_x - x #+ve implies moving right
                            #-ve implies moving left

        should_face_y = if diff_y >=0, do: :north, else: :south
        should_face_x = if diff_x >= 0, do: :east, else: :west

        diff_y = @robot_map_y_atom_to_num[goal_y] - @robot_map_y_atom_to_num[y]
        face_diff = @dir_to_num[facing] - @dir_to_num[should_face_y]



        robot = rotate(robot, should_face_y, face_diff, cli_proc_name)
        {robot, prev} = navigate(robot, diff_y, goal_x, goal_y, [x,y], cli_proc_name)



        {x, y, facing} = report(robot)
        diff_x = goal_x - x #+ve implies moving right
                            #-ve implies moving left
        diff_y = @robot_map_y_atom_to_num[goal_y] - @robot_map_y_atom_to_num[y]

        loop(robot, diff_x, diff_y, should_face_x, should_face_y, facing, goal_x, goal_y, cli_proc_name)
      true ->
        robot
    end

  end

  def rotate(%ToyRobot.Position{facing: facing} = robot, should_face, face_diff, cli_proc_name) do
    #obs_ahead = send_robot_status(robot, cli_proc_name)
    #IO.puts(obs_ahead)
    case should_face == facing do
      false ->
        if (face_diff == -3 or face_diff == 1) do
          robot = left(robot)

          rotate(robot, should_face, face_diff, cli_proc_name)
        else
          robot = right(robot)
          #{:ok, robot} #tuple that is needed to be returned
          #send_robot_status(robot, cli_proc_name)
          rotate(robot, should_face, face_diff, cli_proc_name)
        end
      true ->
        #{:ok, robot} #tuple that is needed to be returned
        #send_robot_status(robot, cli_proc_name)
        robot
    end
  end

  # @spec navigate(
  #         %ToyRobot.Position{:facing => any, :x => any, :y => any, optional(any) => any},
  #         any,
  #         atom | pid | port | reference | {atom, atom}
  #       ) :: {:ok, %ToyRobot.Position{:facing => any, :x => any, :y => any, optional(any) => any}}


  def avoid(%ToyRobot.Position{x: x, y: y, facing: facing} = robot, goal_x, goal_y, prev, cli_proc_name) do
    #calculate best squares around it
    y = @robot_map_y_atom_to_num[y]
    goal_y = @robot_map_y_atom_to_num[goal_y]
    squares = [east: distance(x+1, y, goal_x, goal_y), west: distance(x-1, y, goal_x, goal_y), north: distance(x, y+1, goal_x, goal_y), south: distance(x, y-1, goal_x, goal_y)]
    squares = squares |> List.keysort(1)
    #eliminate out of bounds options
    squares = eliminate_out_of_bounds(squares, x, y) #eliminate out of bounds directions
    prev_dir = calculate_old_direction(x,y,Enum.at(prev,0),Enum.at(prev,1))
    {_, squares} = Keyword.pop(squares, prev_dir) #eliminate old direction
    # IO.inspect(squares, label: "Sorted list")

    sq_values = Keyword.values(squares) #getting a list of values
    sq_keys = Keyword.keys(squares) #getting a corresponding list of keys
    sq_keys = sq_keys ++ prev_dir
    # IO.inspect(sq_values, label: "Sorted vals")
    # IO.inspect(sq_keys, label: "Sorted keys")
    # IO.inspect(prev, label: "Direction where it came from")
    #check each one in order if it can move there
    #then move it return robot and exit

    move_with_priority(robot, sq_keys, 0, cli_proc_name)
  end

  def move_with_priority(%ToyRobot.Position{x: x, y: y, facing: facing} = robot, sq_keys, i, cli_proc_name) do
    #rotate to the defined direction
    should_face = Enum.at(sq_keys, i)
    face_diff = @dir_to_num[facing] - @dir_to_num[should_face]
    robot = rotate(robot, should_face, face_diff, cli_proc_name)

    obs_ahead = send_robot_status(robot, cli_proc_name)
    if obs_ahead do
      i = i+1
      move_with_priority(robot, sq_keys, i, cli_proc_name)
    else
      {x,y,_} = report(robot)
      prev = [x,y]
      robot = move(robot)
      IO.puts("move with priority executed")
      {robot, prev}
    end
  end

  def calculate_old_direction(x1,y1,x2,y2) do
    y2 = @robot_map_y_atom_to_num[y2]
    ans = :x
    ans = if x1 - x2 > 0, do: :west, else: ans
    ans = if x1 - x2 < 0, do: :east, else: ans
    ans = if y1 - y2 > 0, do: :south, else: ans
    ans = if y1 - y2 < 0, do: :north, else: ans
    ans
  end
  def eliminate_out_of_bounds(squares, x, y) do
    {_, squares} = if x+1 > 5, do: Keyword.pop(squares, :east), else: {:ok, squares}
    {_, squares} = if x-1 < 1, do: Keyword.pop(squares, :west), else: {:ok, squares}
    {_, squares} = if y+1 > 5, do: Keyword.pop(squares, :north), else: {:ok, squares}
    {_, squares} = if y-1 < 1, do: Keyword.pop(squares, :south), else: {:ok, squares}
    squares
  end

  def eliminate_previous(squares, facing) do
    el = :north
    el = if facing == :north, do: :south, else: el
    el = if facing == :south, do: :north, else: el
    el = if facing == :east, do: :west, else: el
    el = if facing == :west, do: :east, else: el
    {_, squares} = Keyword.pop(squares, el)

    {squares, el}
  end

  def distance(x1, y1, x2, y2) do
    (x1 - x2)*(x1 - x2) + (y1 - y2)*(y1 - y2)
  end




  def navigate(%ToyRobot.Position{x: x, y: y, facing: facing} = robot, diff, goal_x, goal_y, prev, cli_proc_name) do
    #obstacle avoidance code will be here
    IO.inspect(report(robot), label: "Current pos at first obs of navigate")
    IO.puts("First obs of navigate executed")

    obs_ahead = send_robot_status(robot, cli_proc_name)
    IO.puts(obs_ahead)
    aex = obs_ahead
    diff = if obs_ahead, do: 0, else: diff
    {robot,prev} = call_avoid(robot, obs_ahead, goal_x, goal_y, prev, cli_proc_name)

    # if obs_ahead do
    #   {robot, prev} = avoid(robot, goal_x, goal_y, prev, cli_proc_name)
      # IO.puts("avoid executed")
      # IO.inspect(report(robot), label: "Current pos")
      # send_robot_status(robot, cli_proc_name)
    #   {:ok, robot, prev}
    # end
      # IO.puts("else of avoid executed")
      if (diff != 0 and !obs_ahead) do
        case diff > 0 do
          true ->
            diff = diff - 1
            {x,y,_} = report(robot)
            prev = [x,y]
            robot = move(robot)
            #IO.inspect(report(robot), label: "Current pos")
            #{:ok, robot}

            navigate(robot, diff, goal_x, goal_y, prev, cli_proc_name)
          false ->
            diff = diff + 1
            {x,y,_} = report(robot)
            prev = [x,y]
            IO.puts("robot being moved by the diff function")
            #IO.inspect(report(robot), label: "Current pos")
            robot = move(robot)

            #{:ok, robot}
            #send_robot_status(robot, cli_proc_name)
            navigate(robot, diff, goal_x, goal_y, prev, cli_proc_name)

        end
      else
        IO.puts("Ending else of navigate")
        # IO.inspect(report(robot), label: "Current pos")
        {robot, prev}
        #send_robot_status(robot, cli_proc_name)
      end



      # IO.inspect(report(robot), label: "Current pos")
      # IO.puts("after line 318")

  end


  def call_avoid(robot, obs_ahead, goal_x, goal_y, prev, cli_proc_name) do
    if obs_ahead, do: avoid(robot, goal_x, goal_y, prev, cli_proc_name), else: {robot, prev}
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

#at a node
# check whether the direction you are facing is the right one? If not
# turn in the right direction
# if there is an obstacle?
# we have to circumvent it
# then start from the beginning
