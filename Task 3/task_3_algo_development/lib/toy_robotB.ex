defmodule CLI.ToyRobotB do
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

      iex> CLI.ToyRobotB.place
      {:ok, %CLI.Position{facing: :north, x: 1, y: :a}}
  """
  def place do
    {:ok, %CLI.Position{}}
  end

  def place(x, y, _facing) when x < 1 or y < :a or x > @table_top_x or y > @table_top_y do
    {:failure, "Invalid position"}
  end

  def place(_x, _y, facing)
      when facing not in [:north, :east, :south, :west] do
    {:failure, "Invalid facing direction"}
  end

  @doc """
  Places the robot to the provided position of (x, y, facing),
  but prevents it to be placed outside of the table and facing invalid direction.

  Examples:

      iex> CLI.ToyRobotB.place(1, :b, :south)
      {:ok, %CLI.Position{facing: :south, x: 1, y: :b}}

      iex> CLI.ToyRobotB.place(-1, :f, :north)
      {:failure, "Invalid position"}

      iex> CLI.ToyRobotB.place(3, :c, :north_east)
      {:failure, "Invalid facing direction"}
  """
  def place(x, y, facing) do
    # IO.puts String.upcase("B I'm placed at => #{x},#{y},#{facing}")
    {:ok, %CLI.Position{x: x, y: y, facing: facing}}
  end

  @doc """
  Provide START position to the robot as given location of (x, y, facing) and place it.
  """
  def start(x, y, facing) do
    ###########################
    ## complete this funcion ##
    ###########################

    # Robot B need to listen to A

    CLI.ToyRobotB.place(x, y, facing)
  end

  def stop(_robot, goal_x, goal_y, _cli_proc_name)
      when goal_x < 1 or goal_y < :a or goal_x > @table_top_x or goal_y > @table_top_y do
    {:failure, "Invalid STOP position"}
  end

  def wait_for_agent() do
    if Process.whereis(:coords_store) == nil or Process.whereis(:goal_store) == nil or Process.whereis(:turns) == nil or Process.whereis(:goal_choice) == nil do
      wait_for_agent()
    end
  end

  @doc """
  Provide GOAL positions to the robot as given location of [(x1, y1),(x2, y2),..] and plan the path from START to these locations.
  Passing the CLI Server process name that will be used to send robot's current status after each action is taken.
  Spawn a process and register it with name ':client_toyrobotB' which is used by CLI Server to send an
  indication for the presence of obstacle ahead of robot's current position and facing.
  """
  def stop(robot, goal_locs, cli_proc_name) do
    # Wait for the Agent to be created
    wait_for_agent()

    {:ok, pid_prev} = Agent.start(fn -> %{} end)
    Process.register(pid_prev, :previous_store_B)

    ###########################
    ## complete this funcion ##
    ###########################
    Agent.update(:coords_store, fn map -> Map.put(map, :B, report(robot)) end)
    # goal_loc format => [["3", "d"], ["2", "c"]]
    {r_x, r_y, _facing} = report(robot)

    # Sort out the goal locs
    distance_array = sort_according_to_distance(r_x, r_y, goal_locs)
    # ["2d":4]

    k_b = Integer.to_string(r_x) <> Atom.to_string(r_y)

    Agent.update(:goal_store, &List.delete(&1, String.to_atom(k_b)))

    #function to compare the agent with the current and return only vals that satisy
    distance_array = compare_with_store(distance_array)

    if length(distance_array) == 0 do
      parent = self()
      pid = spawn_link(fn -> roundabout(parent) end)
      Process.register(pid, :client_toyrobotB)

      # send status of the start location
      obs_ahead = send_robot_status(robot, cli_proc_name)
    else
      Agent.update(:goal_choice, fn map -> Map.put(map, :B, {Enum.at(distance_array, 0)}) end)
      # Feed the distance_array to a function which loops through the thing giving goal co-ordinates one by one
      loop_through_goal_locs(distance_array, robot, cli_proc_name)
    end
  end

  def compare_with_store(distance_array) do
    key_list = Agent.get(:goal_store, fn list -> list end)

    Enum.filter(distance_array, fn {key, _val} -> Enum.member?(key_list, key) end)
  end

  def wait_for_a_choice() do
    if Agent.get(:goal_choice, fn map -> Map.get(map, :A) end) == nil do
      wait_for_a_choice()
    end
  end

  def loop_through_goal_locs(distance_array, robot, cli_proc_name) do
    if length(distance_array) > 0 do
      #IO.inspect(distance_array)
      # Extract the current position from the KeyWord List
      {pos, dis_b} = Enum.at(distance_array, 0)
      wait_for_a_choice()
      {{a_choice, dis_a}} = Agent.get(:goal_choice, fn map -> Map.get(map, :A) end)

      {pos, _} =
        if a_choice == pos and length(distance_array) > 1 and dis_a > dis_b do
          Enum.at(distance_array, 1)
        else
          {pos, nil}
        end
        #IO.inspect(pos, label: "B's chosen goal")
      # tup = {:"2a", 1}
      pos = Atom.to_string(pos)

      {goal_x, goal_y} = {String.at(pos, 0), String.at(pos, 1)}
      goal_x = String.to_integer(goal_x)
      goal_y = String.to_atom(goal_y)

      # We need to plan the robot's route from start to end
      {x, y, _facing} = report(robot)

      diff_x = goal_x - x
      # +ve implies moving right
      # -ve implies moving left

      diff_y = @robot_map_y_atom_to_num[goal_y] - @robot_map_y_atom_to_num[y]
      # +ve implies that it needs to go up
      # -ve implies that it needs to go down

      # spawn a process that recieves from server
      # recieve a message then send the message to self()
      parent = self()
      pid = spawn_link(fn -> roundabout(parent) end)
      Process.register(pid, :client_toyrobotB)

      # send status of the start location
      obs_ahead = wait_and_send(robot, cli_proc_name, 0)

      {x, y, _facing} = report(robot)
      key_current = Integer.to_string(x) <> Atom.to_string(y)

      Agent.update(:goal_store, &List.delete(&1, String.to_atom(key_current)))
      distance_array = compare_with_store(distance_array)

      visited = []

      # start the obstacle avoidance and navigation loop
      goal_y = @robot_map_y_atom_to_num[goal_y]

      {robot, distance_array} =
        loop(
          robot,
          visited,
          diff_x,
          diff_y,
          goal_x,
          goal_y,
          obs_ahead,
          distance_array,
          cli_proc_name
        )

        if length(distance_array) > 0 do
          loop_through_goal_locs(distance_array, robot, cli_proc_name)
        end
    end
  end

  def wait_and_send(robot, cli_proc_name, i) do
    a_turn = Agent.get(:turns, fn map -> Map.get(map, :A) end)
    b_turn = Agent.get(:turns, fn map -> Map.get(map, :B) end)

    if (b_turn == true and a_turn == false) or (i > 10000000) do
      obs_ahead = send_robot_status(robot, cli_proc_name)
      #Now update it to show that it is B's turn
      Agent.update(:turns, fn map -> Map.put(map, :A, true) end)
      Agent.update(:turns, fn map -> Map.put(map, :B, false) end)
      obs_ahead
    else
      wait_and_send(robot, cli_proc_name, i+1)
    end
  end

  def roundabout(parent) do
    receive do
      {:obstacle_presence, is_obs_ahead} ->
        send(parent, {:obstacle_presence, is_obs_ahead})
    end
  end

  def sort_according_to_distance(r_x, r_y, goal_locs) do
    distance_array =
      Enum.map(goal_locs, fn [x, y] ->
        {p_x, _} = Integer.parse(x)
        p_y = @robot_map_y_atom_to_num[String.to_atom(y)]

        d =
          distance(
            p_x,
            p_y,
            r_x,
            @robot_map_y_atom_to_num[r_y]
          )

        s = String.to_atom(x <> y)
        {s, d}
      end)

    # Re-arrange goal locs according to distance array
    distance_array |> List.keysort(1)
  end

  def loop(robot, visited, diff_x, diff_y, goal_x, goal_y, obs_ahead, distance_array, cli_proc_name) do
    case diff_y == 0 and diff_x == 0 do
      false ->
        # say you visit an old square or you're at the old square
        # remove it from the list and add it to the end

        # add the square it is at to the list
        {x, y, _facing} = report(robot)

        Agent.update(:coords_store, fn map -> Map.put(map, :B, report(robot)) end)

        # NOTE: y and goal_y are NUMBERS HEREAFTER
        y = @robot_map_y_atom_to_num[y]
        visited = check_for_existing(x, y, visited)

        # generate the list of squares
        # arrange the list based on abs dist function
        # abs (goal_y - y) + abs(goal_x - x)
        # remove the squares which are out of bounds
        # squares = [:north, :south]
        squares = [
          east: distance(x + 1, y, goal_x, goal_y),
          west: distance(x - 1, y, goal_x, goal_y),
          north: distance(x, y + 1, goal_x, goal_y),
          south: distance(x, y - 1, goal_x, goal_y)
        ]

        squares = squares |> List.keysort(1)
        squares = eliminate_out_of_bounds(squares, x, y)

        # IO.inspect(squares)
        # getting a corresponding list of keys
        sq_keys = Keyword.keys(squares)

        # list of visited squares [{1,1}, {1,3}, {1,2}]
        #                         less recent -> more recent
        # go through this list and search each element for matches
        # Add it to a buffer list [:north, :south]
        # add it to the old list of squares

        sq_keys = arrange_by_visited(x, y, sq_keys, visited)

        # navigate according to the list
        {robot, obs_ahead} = move_with_priority(robot, sq_keys, obs_ahead, 0, false, cli_proc_name)

        # get co-ordinates of A
        {x_a, y_a, _} = Agent.get(:coords_store, fn map -> Map.get(map, :A) end)

        {x, y, _facing} = report(robot)

        #Update the goal store to delete the goal entry if A has reached a goal
        key_current = Integer.to_string(x) <> Atom.to_string(y)
        Agent.update(:goal_store, &List.delete(&1, String.to_atom(key_current)))

        #get the updated distance array
        distance_array = compare_with_store(distance_array)
        #IO.inspect(distance_array, label: "B's distance array")

        #Re-sort the list and change the goals
        # {distance_array, goal_x, goal_y}= if length(distance_array) > 0 do
        #   reorder_by_distance(x, y, distance_array)
        # else
        #   {distance_array, goal_x, goal_y}
        # end

        #IO.inspect(distance_array, label: "Distance array of B")

        # +ve implies east and -ve implies west
        diff_x = goal_x - x
        diff_y = goal_y - @robot_map_y_atom_to_num[y]

        {diff_x, diff_y} = if length(distance_array) == 0, do: {0,0}, else: {diff_x, diff_y}


        loop(robot, visited, diff_x, diff_y, goal_x, goal_y, obs_ahead, distance_array, cli_proc_name)

      true ->
        {robot, distance_array}
    end
  end

  def reorder_by_distance(r_x, r_y, distance_array) do
    distance_array = Enum.map(distance_array, fn {pos, d} ->
      s = Atom.to_string(pos)
      {g_x, g_y} = {String.at(s, 0), String.at(s, 1)}
      g_x = String.to_integer(g_x)
      g_y = String.to_atom(g_y)
      d = distance(g_x, @robot_map_y_atom_to_num[g_y], r_x, @robot_map_y_atom_to_num[r_y])
      {pos, d}

    end)

    distance_array = distance_array |> List.keysort(1)

    {pos, _} = Enum.at(distance_array, 0)
    # tup = {:"2a", 1}
    pos = Atom.to_string(pos)
    {goal_x, goal_y} = {String.at(pos, 0), String.at(pos, 1)}
    goal_x = String.to_integer(goal_x)
    goal_y = String.to_atom(goal_y)

    {distance_array, goal_x, @robot_map_y_atom_to_num[goal_y]}
  end

  def arrange_by_visited(x, y, sq_keys, visited) do
    # get a list of tuples with the corresponding directions
    coords =
      Enum.reduce(sq_keys, [], fn dir, acc ->
        coord = []
        coord = if dir == :north, do: {x, y + 1}, else: coord
        coord = if dir == :south, do: {x, y - 1}, else: coord
        coord = if dir == :east, do: {x + 1, y}, else: coord
        coord = if dir == :west, do: {x - 1, y}, else: coord
        acc ++ [coord]
      end)

    # co-ords are in the order of distance function
    # final list should be in the order of visited list
    dirs_in_order =
      Enum.reduce(visited, [], fn {x_v, y_v}, acc ->
        i = Enum.find_index(coords, fn {x, y} -> x == x_v and y == y_v end)

        if i != nil do
          {_, buff} = Enum.fetch(sq_keys, i)
          acc ++ [buff]
        else
          acc
        end
      end)

    # dirs_in_order => Directions which are arranged in old -> new

    sq_keys = sq_keys -- dirs_in_order
    sq_keys = sq_keys ++ dirs_in_order
    # sq_keys now has the keys with the visited ones at the end
    sq_keys
  end

  def check_for_existing(x, y, visited) do
    # function is working !
    # removes the x,y tuple from the list if it exists in it
    visited = Enum.reject(visited, fn {x_v, y_v} -> x_v == x and y_v == y end)
    # adds the tuple to the end of the visited list
    visited ++ [{x, y}]
  end

  def rotate(
        %CLI.Position{facing: facing} = robot,
        should_face,
        face_diff,
        obs_ahead,
        cli_proc_name
      ) do
    case should_face == facing do
      false ->
        parent = self()
        pid = spawn_link(fn -> roundabout(parent) end)
        Process.register(pid, :client_toyrobotB)

        if face_diff == -3 or face_diff == 1 do
          # rotate left
          robot = left(robot)
          obs_ahead = wait_and_send(robot, cli_proc_name, 0)
          rotate(robot, should_face, face_diff, obs_ahead, cli_proc_name)
        else
          # rotate right
          robot = right(robot)
          obs_ahead = wait_and_send(robot, cli_proc_name, 0)
          rotate(robot, should_face, face_diff, obs_ahead, cli_proc_name)
        end

      true ->
        # return the robot object/struct
        {robot, obs_ahead}
    end
  end

  def move_with_priority(
        %CLI.Position{facing: facing} = robot,
        sq_keys,
        obs_ahead,
        i,
        prev_loop,
        cli_proc_name
      ) do
    # rotate to the defined direction

    should_face = Enum.at(sq_keys, i)
    face_diff = @dir_to_num[facing] - @dir_to_num[should_face]

    {robot, obs_ahead} =
      if face_diff != 0,
        do: rotate(robot, should_face, face_diff, false, cli_proc_name),
        else: {robot, obs_ahead}

    {x_a, y_a, facing_a} = Agent.get(:coords_store, fn map -> Map.get(map, :A) end)
    {x, y, facing} = report(robot)
    {nxt_x, nxt_y} = calculate_next_position(x, y, facing)
    # IO.puts("Next X B: #{nxt_x} Next Y B: #{nxt_y}")
    # IO.puts("X A: #{x_a} Y A: #{y_a}")
    y_a = @robot_map_y_atom_to_num[y_a]
    # check if the robot is in the way
    # if it is, wait for 1 iteration
    if x_a == nxt_x and y_a == nxt_y and !obs_ahead do
      # wait_for_movement(nxt_x, nxt_y)
      #wait_for_movement(robot, cli_proc_name, 0)
      obs_ahead = true
    end

    # Get previous location of this robot
    prev = Agent.get(:previous_store_B, fn map -> Map.get(map, :prev) end, 1)


    #IO.inspect(prev)
    # If the robot is at the same place for two moves in a row
    # i.e. wait_for_movement() makes no difference
    # basically, the other robot has stopped in front of this one
    # then treat the other robot as an obstacle
    # and try to navigate around it
    obs_ahead =
      if prev != nil and !prev_loop do
        {prev_x, prev_y, prev_facing} = prev
        #IO.puts("prev_x = #{prev_x} prev_y = #{prev_y}  ")
        #IO.puts("x = #{x} y = #{y} ")

        if prev_x == x and prev_y == y do
          true
        else
          obs_ahead
        end
      else
        obs_ahead
      end
    if obs_ahead do
      i = i + 1
      #IO.puts("Entered the retry loop")
      move_with_priority(robot, sq_keys, obs_ahead, i, true, cli_proc_name)
    else
      wait_for_a()
      {x_a, y_a, facing_a} = Agent.get(:coords_store, fn map -> Map.get(map, :A) end, 10)
      {nxt_x, nxt_y} = calculate_next_position(x, y, facing)

      y_a = @robot_map_y_atom_to_num[y_a]

      robot_ahead =
        if x_a == nxt_x and y_a == nxt_y do
          true

        else
          false
        end

      # IO.inspect(robot_ahead, label: "Is the robot ahead of B")
      Agent.update(:previous_store_B, fn map -> Map.put(map, :prev, report(robot)) end)
      robot =
        if !robot_ahead do
          move(robot)
        else
          robot
        end

      Agent.update(:coords_store, fn map -> Map.put(map, :B, report(robot)) end)


      parent = self()
      pid = spawn_link(fn -> roundabout(parent) end)
      Process.register(pid, :client_toyrobotB)
      obs_ahead = wait_and_send(robot, cli_proc_name, 0)

      {robot, obs_ahead}
    end
  end

  def wait_for_a() do
    a_turn = Agent.get(:turns, fn map -> Map.get(map, :A) end)
    b_turn = Agent.get(:turns, fn map -> Map.get(map, :B) end)

    if a_turn == true and b_turn == false do
      wait_for_a()
    end
  end

  def wait_for_movement(robot, cli_proc_name, _) do
    # get the status of the turns
    a_turn = Agent.get(:turns, fn map -> Map.get(map, :A) end)
    b_turn = Agent.get(:turns, fn map -> Map.get(map, :B) end)

    if b_turn do
      obs_ahead = send_robot_status(robot, cli_proc_name)
      #Now update it to show that it is A's turn
      Agent.update(:turns, fn map -> Map.put(map, :A, true) end)
      Agent.update(:turns, fn map -> Map.put(map, :B, false) end)
    else
      wait_for_a()
    end
  end

  def wait_for_movement(nxt_x, nxt_y) do
    {x_b, y_b, _} = Agent.get(:coords_store, fn map -> Map.get(map, :B) end)

    if x_b == nxt_x and y_b == nxt_y do
      wait_for_movement(nxt_x, nxt_y)
    end
  end

  def calculate_next_position(x, y, facing) do
    y = @robot_map_y_atom_to_num[y]
    coord = {x, y}
    coord = if facing == :north, do: {x, y + 1}, else: coord
    coord = if facing == :south, do: {x, y - 1}, else: coord
    coord = if facing == :east, do: {x + 1, y}, else: coord
    coord = if facing == :west, do: {x - 1, y}, else: coord
    coord
  end

  def eliminate_out_of_bounds(squares, x, y) do
    {_, squares} = if x + 1 > 5, do: Keyword.pop(squares, :east), else: {:ok, squares}
    {_, squares} = if x - 1 < 1, do: Keyword.pop(squares, :west), else: {:ok, squares}
    {_, squares} = if y + 1 > 5, do: Keyword.pop(squares, :north), else: {:ok, squares}
    {_, squares} = if y - 1 < 1, do: Keyword.pop(squares, :south), else: {:ok, squares}
    squares
  end

  def distance(x1, y1, x2, y2) do
    abs(x1 - x2) + abs(y1 - y2)
  end

  def listen_from_robotA(parent) do
    receive do
      {:position, value} ->
        # IO.puts("I got a message: #{inspect value}")
        send(parent, {:positions, value})

      {:goal_reached, value} ->
        #IO.puts("Goal has been reached by A: #{inspect(value)}")
        send(parent, {:goal_reached, value})
    end

    listen_from_robotA(parent)
  end

  @doc """
  Send Toy Robot's current status i.e. location (x, y) and facing
  to the CLI Server process after each action is taken.
  Listen to the CLI Server and wait for the message indicating the presence of obstacle.
  The message with the format: '{:obstacle_presence, < true or false >}'.
  """
  def send_robot_status(%CLI.Position{x: x, y: y, facing: facing} = _robot, cli_proc_name) do
    send(cli_proc_name, {:toyrobotB_status, x, y, facing})
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

      iex> {:ok, robot} = CLI.ToyRobotB.place(2, :b, :west)
      iex> CLI.ToyRobotB.report(robot)
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
    %CLI.Position{
      robot
      | y:
          Enum.find(@robot_map_y_atom_to_num, fn {_, val} ->
            val == Map.get(@robot_map_y_atom_to_num, y) + 1
          end)
          |> elem(0)
    }
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
    %CLI.Position{
      robot
      | y:
          Enum.find(@robot_map_y_atom_to_num, fn {_, val} ->
            val == Map.get(@robot_map_y_atom_to_num, y) - 1
          end)
          |> elem(0)
    }
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
