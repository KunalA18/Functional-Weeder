defmodule CLI.ToyRobotA do
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

      iex> CLI.ToyRobotA.place
      {:ok, %CLI.Position{facing: :north, x: 1, y: :a}}
  """
  def place do
    {:ok, %CLI.Position{}}
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

      iex> CLI.ToyRobotA.place(1, :b, :south)
      {:ok, %CLI.Position{facing: :south, x: 1, y: :b}}

      iex> CLI.ToyRobotA.place(-1, :f, :north)
      {:failure, "Invalid position"}

      iex> CLI.ToyRobotA.place(3, :c, :north_east)
      {:failure, "Invalid facing direction"}
  """
  def place(x, y, facing) do
    # IO.puts String.upcase("A I'm placed at => #{x},#{y},#{facing}")
    {:ok, %CLI.Position{x: x, y: y, facing: facing}}
  end

  @doc """
  Provide START position to the robot as given location of (x, y, facing) and place it.
  """
  def start(x, y, facing) do
    ###########################
    ## complete this funcion ##
    ###########################
    ToyRobot.place(1,:a,:NORTH)
  end

  def stop(_robot, goal_x, goal_y, _cli_proc_name) when goal_x < 1 or goal_y < :a or goal_x > @table_top_x or goal_y > @table_top_y do
    {:failure, "Invalid STOP position"}
  end

  @doc """
  Provide GOAL positions to the robot as given location of [(x1, y1),(x2, y2),..] and plan the path from START to these locations.
  Passing the CLI Server process name that will be used to send robot's current status after each action is taken.
  Spawn a process and register it with name ':client_toyrobotA' which is used by CLI Server to send an
  indication for the presence of obstacle ahead of robot's current position and facing.
  """
  def stop(robot, goal_locs, cli_proc_name) do
    ###########################
    ## complete this funcion ##
    ###########################

    #Sort out the goal locs

    #We need to plan the robot's route from start to end
    {x, y, _facing} = report(robot) #puts the robot's current co-ordinates into x,y,facing
    diff_x = goal_x - x #+ve implies moving right
                        #-ve implies moving left

    diff_y = @robot_map_y_atom_to_num[goal_y] - @robot_map_y_atom_to_num[y]
    #+ve implies that it needs to go up
    #-ve implies that it needs to go down

    #spawn a process that recieves from server
    #recieve a message then send the message to self()
    parent = self()
    pid = spawn_link(fn -> roundabout(parent) end)
    Process.register(pid, :client_toyrobotA)


    #IO.puts(ans)
    obs_ahead = send_robot_status(robot, cli_proc_name) # send status of the start location

    visited = []
    #start the obstacle avoidance and navigation loop
    goal_y = @robot_map_y_atom_to_num[goal_y]
    loop(robot, visited, diff_x, diff_y, goal_x, goal_y, obs_ahead, cli_proc_name)
  end

  def roundabout(parent) do
    receive do
      {:obstacle_presence, is_obs_ahead} ->
        send(parent, {:obstacle_presence, is_obs_ahead})
    end
  end

  def loop(robot, visited, diff_x, diff_y, goal_x, goal_y, obs_ahead, cli_proc_name) do
    case diff_y == 0 and diff_x == 0 do
      false ->
        #say you visit an old square or you're at the old square
        #remove it from the list and add it to the end

        #add the square it is at to the list
        {x, y, _facing} = report(robot)
        y = @robot_map_y_atom_to_num[y] #NOTE: y and goal_y are NUMBERS HEREAFTER
        visited = check_for_existing(x, y, visited)

        #generate the list of squares
        #arrange the list based on abs dist function
        # abs (goal_y - y) + abs(goal_x - x)
        #remove the squares which are out of bounds
        #squares = [:north, :south]
        squares = [east: distance(x+1, y, goal_x, goal_y), west: distance(x-1, y, goal_x, goal_y), north: distance(x, y+1, goal_x, goal_y), south: distance(x, y-1, goal_x, goal_y)]
        squares = squares |> List.keysort(1)
        squares = eliminate_out_of_bounds(squares, x, y)

        #IO.inspect(squares)
        sq_keys = Keyword.keys(squares) #getting a corresponding list of keys

        #list of visited squares [{1,1}, {1,3}, {1,2}]
        #                         less recent -> more recent
        # go through this list and search each element for matches
        # Add it to a buffer list [:north, :south]
        # add it to the old list of squares

        sq_keys = arrange_by_visited(x, y, sq_keys, visited)

        #navigate according to the list
        {robot, obs_ahead} = move_with_priority(robot, sq_keys, obs_ahead, 0, cli_proc_name)

        {x, y, _facing} = report(robot)
        diff_x = goal_x - x # +ve implies east and -ve implies west
        diff_y = goal_y - @robot_map_y_atom_to_num[y]

        loop(robot, visited, diff_x, diff_y, goal_x, goal_y, obs_ahead, cli_proc_name)
      true ->
        robot
    end

  end

  def arrange_by_visited(x, y, sq_keys, visited) do
    #get a list of tuples with the corresponding directions
    coords = Enum.reduce(sq_keys, [], fn (dir, acc) ->
      coord = []
      coord = if dir == :north, do: {x,y+1}, else: coord
      coord = if dir == :south, do: {x,y-1}, else: coord
      coord = if dir == :east, do: {x+1,y}, else: coord
      coord = if dir == :west, do: {x-1,y}, else: coord
      acc ++ [coord]
    end)

    #co-ords are in the order of distance function
    #final list should be in the order of visited list
    dirs_in_order = Enum.reduce(visited, [], fn ({x_v, y_v}, acc) ->
      i = Enum.find_index(coords, fn {x,y} -> x == x_v and y == y_v end)
      if i != nil do
        {_, buff} = Enum.fetch(sq_keys, i)
        acc ++ [buff]
      else
        acc
      end
    end)

    #dirs_in_order => Directions which are arranged in old -> new

    sq_keys = sq_keys -- dirs_in_order
    sq_keys = sq_keys ++ dirs_in_order
    sq_keys #sq_keys now has the keys with the visited ones at the end

  end

  def check_for_existing(x, y, visited) do
    #function is working !
    visited = Enum.reject(visited, fn {x_v, y_v} -> (x_v == x and y_v == y) end) # removes the x,y tuple from the list if it exists in it
    visited ++ [{x,y}] #adds the tuple to the end of the visited list
  end

  def rotate(%ToyRobot.Position{facing: facing} = robot, should_face, face_diff, obs_ahead, cli_proc_name) do
    case should_face == facing do
      false ->
        parent = self()
        pid = spawn_link(fn -> roundabout(parent) end)
        Process.register(pid, :client_toyrobotA)
        if (face_diff == -3 or face_diff == 1) do

          robot = left(robot) #rotate left
          obs_ahead = send_robot_status(robot, cli_proc_name)
          rotate(robot, should_face, face_diff, obs_ahead, cli_proc_name)
        else

          robot = right(robot) #rotate right
          obs_ahead = send_robot_status(robot, cli_proc_name)
          rotate(robot, should_face, face_diff, obs_ahead, cli_proc_name)
        end
      true ->
        {robot, obs_ahead} #return the robot object/struct
    end
  end


  def move_with_priority(%ToyRobot.Position{facing: facing} = robot, sq_keys, obs_ahead, i, cli_proc_name) do
    #rotate to the defined direction

    should_face = Enum.at(sq_keys, i)
    face_diff = @dir_to_num[facing] - @dir_to_num[should_face]
    {robot, obs_ahead} = if face_diff != 0, do: rotate(robot, should_face, face_diff, false, cli_proc_name), else: {robot, obs_ahead}

    if obs_ahead do
      i = i+1
      move_with_priority(robot, sq_keys, obs_ahead, i, cli_proc_name)
    else
      robot = move(robot)
      parent = self()
      pid = spawn_link(fn -> roundabout(parent) end)
      Process.register(pid, :client_toyrobotA)
      obs_ahead = send_robot_status(robot, cli_proc_name)
      {robot, obs_ahead}
    end
  end

  def eliminate_out_of_bounds(squares, x, y) do
    {_, squares} = if x+1 > 5, do: Keyword.pop(squares, :east), else: {:ok, squares}
    {_, squares} = if x-1 < 1, do: Keyword.pop(squares, :west), else: {:ok, squares}
    {_, squares} = if y+1 > 5, do: Keyword.pop(squares, :north), else: {:ok, squares}
    {_, squares} = if y-1 < 1, do: Keyword.pop(squares, :south), else: {:ok, squares}
    squares
  end


  def distance(x1, y1, x2, y2) do
    abs(x1 - x2) + abs(y1 - y2)
  end


  @doc """
  Send Toy Robot's current status i.e. location (x, y) and facing
  to the CLI Server process after each action is taken.
  Listen to the CLI Server and wait for the message indicating the presence of obstacle.
  The message with the format: '{:obstacle_presence, < true or false >}'.
  """
  def send_robot_status(%CLI.Position{x: x, y: y, facing: facing} = _robot, cli_proc_name) do
    send(cli_proc_name, {:toyrobotA_status, x, y, facing})
    # IO.puts("Sent by Toy Robot Client: #{x}, #{y}, #{facing}")
    listen_from_server()
  end

  @doc """
  Listen to the CLI Server and wait for the message indicating the presence of obstacle.
  The message with the format: '{:obstacle_presence, < true or false >}'.
  """
  def listen_from_server() do
    receive do
      {:obstacle_presence, is_obs_ahead} ->
        is_obs_ahead
    end
  end

  @doc """
  Provides the report of the robot's current position

  Examples:

      iex> {:ok, robot} = CLI.ToyRobotA.place(2, :b, :west)
      iex> CLI.ToyRobotA.report(robot)
      {2, :b, :west}
  """
  def report(%CLI.Position{x: x, y: y, facing: facing} = _robot) do
    {x, y, facing}
  end

  @directions_to_the_right %{north: :east, east: :south, south: :west, west: :north}
  @doc """
  Rotates the robot to the right
  """
  def right(%CLI.Position{facing: facing} = robot) do
    %CLI.Position{robot | facing: @directions_to_the_right[facing]}
  end

  @directions_to_the_left Enum.map(@directions_to_the_right, fn {from, to} -> {to, from} end)
  @doc """
  Rotates the robot to the left
  """
  def left(%CLI.Position{facing: facing} = robot) do
    %CLI.Position{robot | facing: @directions_to_the_left[facing]}
  end

  @doc """
  Moves the robot to the north, but prevents it to fall
  """
  def move(%CLI.Position{x: _, y: y, facing: :north} = robot) when y < @table_top_y do
    %CLI.Position{robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) + 1 end) |> elem(0)}
  end

  @doc """
  Moves the robot to the east, but prevents it to fall
  """
  def move(%CLI.Position{x: x, y: _, facing: :east} = robot) when x < @table_top_x do
    %CLI.Position{robot | x: x + 1}
  end

  @doc """
  Moves the robot to the south, but prevents it to fall
  """
  def move(%CLI.Position{x: _, y: y, facing: :south} = robot) when y > :a do
    %CLI.Position{robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) - 1 end) |> elem(0)}
  end

  @doc """
  Moves the robot to the west, but prevents it to fall
  """
  def move(%CLI.Position{x: x, y: _, facing: :west} = robot) when x > 1 do
    %CLI.Position{robot | x: x - 1}
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
