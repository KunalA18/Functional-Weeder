defmodule FWClientRobotA do
  # WEEDING ROBOT
  @doc """
  Team ID:          2339
  Author List:      Toshan Luktuke, Kunal Agarwal, Sagar Chotalia
  Filename:         task4c_client_robota.ex
  Theme:            Functional-Weeder
  Functions:        Too many to meaningfully list here
  Global Variables: @table_top_x, @table_top_y, @robot_map_y_atom_to_num, @dir_to_num, @robot_map_y_num_to_atom, @physical
  Agents:           :weeded_store, :main_goal_storeA, :continuous_turns, :seeding, :line_sensor
  """

  # max x-coordinate of table top
  @table_top_x 6
  # max y-coordinate of table top
  @table_top_y :f
  # mapping of y-coordinates
  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5, :f => 6}
  # maps directions to numbers
  @dir_to_num %{:north => 1, :east => 2, :south => 3, :west => 4}
  # maps y numbers to atoms
  @robot_map_y_num_to_atom %{1 => :a, 2 => :b, 3 => :c, 4 => :d, 5 => :e, 6 => :f}
  # If set to true, all LineFollower functions will work
  @physical false
  @obstacle false

  # Function Description
  @doc """
  Function Name:
  Input:
  Output:
  Logic:
  Example Call:
  """

  @doc """
  Places the robot to the default position of (1, A, North)

  Examples:

      iex> FWClientRobotA.place
      {:ok, %FWClientRobotA.Position{facing: :north, x: 1, y: :a}}
  """
  def place do
    {:ok, %FWClientRobotA.Position{}}
  end

  def place(x, y, _facing) when x < 1 or y < :a or x > @table_top_x or y > @table_top_y do
    {:failure, "Invalid position"}
  end

  def place(_x, _y, facing) when facing not in [:north, :east, :south, :west] do
    {:failure, "Invalid facing direction"}
  end

  @doc """
  Places the robot to the provided position of (x, y, facing),
  but prevents it to be placed outside of the table and facing invalid direction.

  Examples:

      iex> FWClientRobotA.place(1, :b, :south)
      {:ok, %FWClientRobotA.Position{facing: :south, x: 1, y: :b}}

      iex> FWClientRobotA.place(-1, :f, :north)
      {:failure, "Invalid position"}

      iex> FWClientRobotA.place(3, :c, :north_east)
      {:failure, "Invalid facing direction"}
  """
  def place(x, y, facing) do
    {:ok, %FWClientRobotA.Position{x: x, y: y, facing: facing}}
  end

  @doc """
  Provide START position to the robot as given location of (x, y, facing) and place it.
  """
  def start(x, y, facing) do
    place(x, y, facing)
  end

  @doc """
  Function Name:  process_start_message
  Description:    Processes the start string that is recieved from server and returns it in a tuple
  Input:          start_map -> A map containing string versions of the start locations of both robots
  Output:         Tuple of format {int, String, String}
  Logic:          Get the start tuple of A from the map, convert 'x' to integer, remove all spaces from 'y' and 'dir' parts and return it
  Example Call:   process_start_message(%{"A" => {"1","a ", " north"}, "B" => nil)
  """
  def process_start_message(start_map) do
    data = start_map["A"]
    x = Enum.at(data, 0) |> String.to_integer
    y = Enum.at(data, 1)
    y = Regex.replace(~r/ /, y, "") |> String.to_atom # Regex to remove all spaces in the string
    dir = Enum.at(data, 2)
    dir =  Regex.replace(~r/ /, dir, "") |> String.to_atom # Regex to remove all spaces in the string

    {x,y,dir}
  end

  @doc """
  Function Name:  wait_for_start
  Description:    Used to continuously ping the server every two seconds waiting for the start message from server
  Input:          start_map -> A map containing string versions of the start locations of both robots
                  channel -> Channel that has information for server communication
  Output:         None
  Logic:          If the start message recieved from the server has nil as the "A" value it will call itself and wait 2 seconds
  Example Call:   wait_for_start(start_map, channel)
  """
  def wait_for_start(start_map, channel) do
    Process.sleep(2000)
    {:ok, start_map} = FWClientRobotA.PhoenixSocketClient.get_start(channel)
    if Map.get(start_map, "A") == nil do
      wait_for_start(start_map, channel)
    else
      process_start_message(start_map)
    end
  end

  @doc """
  Starts agents used to store state
  These will be used by various processes later on in the program
  """
  def start_agents() do
    {:ok, agent} = Agent.start_link(fn -> [] end)
    Process.register(agent, :weeded_store)

    {:ok, pid_goals} = Agent.start_link(fn -> [] end)
    Process.register(pid_goals, :main_goal_storeA)

    {:ok, pid_uturn} = Agent.start_link(fn -> false end)
    Process.register(pid_uturn, :continuous_turns)

    {:ok, pid_seeding} = Agent.start_link(fn -> 1 end)
    Process.register(pid_seeding, :seeding)

    {:ok, pid_line_sensor} = Agent.start_link(fn -> {[0,0,0,0,0], 0} end)
    Process.register(pid_line_sensor, :line_sensor)
  end

  @doc """
  Main function to initiate the sequence of tasks to achieve by the Client Robot A,
  such as connect to the Phoenix server, get the robot A's start and goal locations to be traversed.
  Call the respective functions from this module and others as needed.
  You may create extra helper functions as needed.
  """
  def main(args) do
    # Start agents required by the program
    start_agents()

    # Connect to the server
    {:ok, _response, channel} = FWClientRobotA.PhoenixSocketClient.connect_server()

    # Function to get goal positions
    {:ok, goals_string} = FWClientRobotA.PhoenixSocketClient.get_goals(channel)

    # Update the goal positions in the main_store Agent
    Agent.update(:main_goal_storeA, fn list -> list ++ goals_string end)

    # Wait for user to click on start button
    {start_x, start_y, start_dir} = wait_for_start(%{A: nil, B: nil}, channel) #{1, :a, :north}

    # Start robot in the internal navigation system of the program
    {:ok, robot} = start(start_x, start_y, start_dir)

    # Convert the number 11, 22 etc. into goal positions
    goal_locs = calculate_goals(robot, goals_string)

    # Start main algorithm
    stop(robot, goal_locs, channel)

    # Send message that signifies work completion
    FWClientRobotA.PhoenixSocketClient.work_complete(channel)
  end

  @doc """
  Function Name:  calculate_goals
  Description:    Finds the closest out of the 4 possible node locations from a goal location and returns a list of all of them
                  return
  Input:          robot -> Robot Struct, goals_string -> List of goal locations obtained from the server
  Output:         List of node locations for the robot to visit -> [["1","b"], ["3","d"]...]
  Logic:          Iterate over each goal from the list, calculate four possible node locations, determine nearest one,
                  convert to desired format, add to list
  Example Call:   calculate_goals(robot, ["2", "11", "22"])
  """
  def calculate_goals(robot, goals_string) do
    #Arena description
    #####################
    # 21# 22# 23# 24# 25#
    #####################
    # 1 # 2 # 3 # 4 # 5 #
    #####################

    goal_locs = Enum.reduce(goals_string, [], fn s, acc ->
      {bl, br, tl, tr} = convert_goal_to_locations(s)
      # Now find the closest goal location to the robot
      {x, y} = find_minimum(robot, bl, br, tl, tr)
      y = @robot_map_y_num_to_atom[y] |> Atom.to_string
      x = Integer.to_string(x)
      acc ++ [[x,y]]
    end)
  end

  @doc """
  Function Name:  find_minimum
  Input:          robot -> Robot Struct
                  bl -> Tuple with bottom left positioned node relative to goal
                  br -> Tuple with bottom right positioned node relative to goal
                  tl -> Tuple with top left positioned node relative to goal
                  tr -> Tuple with top right positioned node relative to goal
  Output:         Returns the position with the minimum distance from the robot
  Logic:          Calculated by simple if-else statements, ans stores the result and this variable is always returned
  Example Call:   find_minimum(robot, {1,2}, {1,3}, {2,2}, {2,3})
  """
  def find_minimum(robot, bl, br, tl, tr) do
    {rx, ry, _} = report(robot)
    ry = @robot_map_y_atom_to_num[ry]
    d_bl = distance(rx, ry, elem(bl, 0), elem(bl, 1))
    d_br = distance(rx, ry, elem(br, 0), elem(br, 1))
    d_tl = distance(rx, ry, elem(tl, 0), elem(tl, 1))
    d_tr = distance(rx, ry, elem(tr, 0), elem(tr, 1))
    ans = bl
    ans = if d_bl <= d_br and d_bl <= d_tl and d_bl <= d_tr, do: bl, else: ans
    ans = if d_br <= d_bl and d_br <= d_tl and d_br <= d_tr, do: br, else: ans
    ans = if d_tl <= d_bl and d_tl <= d_br and d_tl <= d_tr, do: tl, else: ans
    ans = if d_tr <= d_bl and d_tr <= d_br and d_tr <= d_tl, do: tr, else: ans
  end

  @doc """
  Function Name:  convert_goal_to_locations
  Input:          loc -> This is a string number E.g. "11", "5"
  Output:         A tuple with the bottom left, bottom right, top left and top right positions relative to loc
  Logic:          First convert num to integer and then get its remainder+1 for x position and quotient+1 for y position
                  this will give bottom left position, add and subtract 1 to get the other three
  Example Call:   convert_goal_to_locations("3")
  """
  def convert_goal_to_locations(loc) do
    no = String.to_integer(loc) - 1
    x = rem(no, 5) + 1
    y = Integer.floor_div(no, 5) + 1

    bl = {x, y} # Bottom left
    br = {x + 1, y} # Bottom right
    tl = {x, y + 1} # Top left
    tr = {x + 1, y + 1} # Top right

    {bl, br, tl, tr}
  end

  @doc """
  Provide GOAL positions to the robot as given location of [(x1, y1),(x2, y2),..] and plan the path from START to these locations.
  Make a call to ToyRobot.PhoenixSocketClient.send_robot_status/2 to get the indication of obstacle presence ahead of the robot.
  """
  def stop(robot, goal_locs, channel) do

    FWClientRobotA.PhoenixSocketClient.coords_store_update(channel, report(robot))

    {r_x, r_y, _facing} = report(robot)

    # goal_loc format => [["3", "d"], ["2", "c"]]
    # Sort out the goal locs
    distance_array = sort_according_to_distance(r_x, r_y, goal_locs)

    if length(distance_array) == 0 do
      # send status of the start location
      {:obstacle_presence, obs_ahead} = send_robot_status(channel, robot)
    else
      # Feed the distance_array to a function which loops through the thing giving goal co-ordinates one by one
      robot = loop_through_goal_locs(distance_array, robot, goal_locs, channel)
      distance_array = get_deposition_positions(robot)

      robot = loop_through_goal_locs(distance_array, robot, goal_locs, channel)
      {robot, obs_ahead} = rotate_for_deposition(robot, channel)
      deposit()
      weeded_locs = Agent.get(:weeded_store, fn x -> x end)
      FWClientRobotA.PhoenixSocketClient.send_deposition_msg(channel, weeded_locs)
    end
  end

  @doc """
  Function Name:  deposit()
  Input:          None
  Output:         None
  Logic:          Used conditionally call the LineFollower.depo function, using @physical you can switch between physical and virtual movement
  Example Call:   deposit()
  """
  def deposit() do
    if @physical do
      FWClientRobotA.LineFollower.depo()
    end
  end

  @doc """
  Function Name:  rotate_for_deposition
  Input:          robot -> Robot Struct, channel -> Channel information for communicating with server
  Output:         robot, obs_ahead are returned in struct form
  Logic:          Checks its current location and accordingly rotates to face either east or south
  Example Call:   rotate_for_deposition(robot, channel)
  """
  def rotate_for_deposition(robot, channel) do
    # f --> east
    # else --> south
    {r_x, r_y, r_facing} = report(robot)
    should_face = if r_y == :f, do: :east, else: :south
    face_diff = @dir_to_num[r_facing] - @dir_to_num[should_face]
    {robot, obs_ahead} = rotate(robot, should_face, face_diff, false, 0, channel)
  end


  @doc """
  Function Name:  get_deposition_positions
  Input:          robot -> Robot Struct
  Output:         distance_array is a Keyword list of the closest deposition position to the robot
  Logic:
  Example Call:   get_deposition_positions(robot)
  """
  def get_deposition_positions(robot) do
    # 1-6f
    # 6a-f
    {r_x, r_y, _} = report(robot)
    #positions of nodes next to the deposition zone
    deps = [["1", "f"], ["2", "f"], ["3", "f"], ["4", "f"], ["5", "f"], ["6", "f"],
    ["6", "a"], ["6", "b"], ["6", "c"], ["6", "d"], ["6", "e"]]
    #create a distance array of the following
    distance_array =
      Enum.map(deps, fn [x, y] ->
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

      distance_array = distance_array |> List.keysort(1) |> List.first() |> List.wrap
  end

  @doc """
  Function Name:  loop_through_goal_locs
  Input:          distance_array -> Keyword List of goal positions arranged relative to distance from robot
                  robot -> Robot Struct
                  goal_locs -> List of goal positions of the robot
                  channel -> Channel used for communication with server
  Output:         robot -> Robot Struct
  Logic:          First it checks the length of distance_array then it loops through said distance_array by feeding its locations
                  one by one to the loop/10 function. On completion of traversal it initiates the seeding/weeding function
  Example Call:   loop_through_goal_locs([:"2a":3], robot, [["1","3"]], channel)
  """
  def loop_through_goal_locs(distance_array, robot, goal_locs, channel) do
    if length(distance_array) > 0 do
      # Extract the current position from the KeyWord List
      {pos, dis_a} = Enum.at(distance_array, 0)
      IO.inspect(distance_array, label: "Distance Array")

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

      # send status of the start location
      {:obstacle_presence, obs_ahead} = send_robot_status(channel, robot)
      {x, y, _facing} = report(robot)

      visited = []

      goal_y = @robot_map_y_atom_to_num[goal_y]

      # start the obstacle avoidance and navigation loop
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
          goal_locs,
          channel
        )
        # This implies that the robot has reached the goal location
        # If robot has reached goal, update the main_goal array
        {rx, ry, _} = report(robot)
        rtup = {rx, @robot_map_y_atom_to_num[ry]}
        goals_list = Agent.get(:main_goal_storeA, fn list -> list end)

        {distance_array, robot} =
          if goals_list != [] do
            IO.inspect(goals_list, label: "Goals List")

            {goals_list, _} = Enum.reduce(goals_list, {[], false}, fn s, {acc, detect} ->
              {bl, br, tl, tr} = convert_goal_to_locations(s)
              if (rtup == bl or rtup == br or rtup == tl or rtup == tr) and !detect do
                Agent.update(:weeded_store, fn list -> list ++ [s] end)
                {acc, true}
              else
                {acc ++ [s], detect}
              end
            end)

            IO.inspect(goals_list, label: "Goals List after reduction")

            Agent.update(:main_goal_storeA, fn list -> goals_list end)
            distance_array = sort_according_to_distance(robot, rx, ry, 0)
            IO.inspect({rx, ry}, label: "Current Location")
            IO.inspect(distance_array, label: "Distance array before weeding")

            # If robot has reached goal, activate seeding/weeding for square in the main_goal array
            weeded = Agent.get(:weeded_store, fn list -> list end) |> List.last

            {robot, distance_array, obstacle} = weeding(robot, weeded, distance_array, channel)
            send_robot_status(channel, robot)

            {goals_list, _} = Enum.reduce(goals_list, {[], false}, fn s, {acc, detect} ->
              {bl, br, tl, tr} = convert_goal_to_locations(s)
              if (rtup == bl or rtup == br or rtup == tl or rtup == tr) and !detect do
                Agent.update(:weeded_store, fn list -> list ++ [s] end)
                {acc, true}
              else
                {acc ++ [s], detect}
              end
            end)

            {rx, ry, _} = report(robot)

            distance_array = if !obstacle, do: sort_according_to_distance(robot, rx, ry, 0), else: distance_array
            Agent.update(:main_goal_storeA, fn list -> goals_list end)
            IO.inspect(distance_array, label: "Distance array after weeding")


            IO.puts("-----------------")
            {distance_array, robot}
        else
          distance_array = List.delete_at(distance_array, 0)
          IO.inspect(distance_array, label: "Deleted")
          {distance_array, robot}
        end



      if length(distance_array) > 0 do
        loop_through_goal_locs(distance_array, robot, goal_locs, channel)
      else
        robot
      end

    end
  end

  @doc """
  Function Name:  sort_according_to_distance
  Input:          robot -> Robot Struct
                  r_x -> Robot's current x coordinate
                  r_y -> Robot's current y coordinate
                  _ -> Unused variable
  Output:         Sorted distance_array Keyword List
  Logic:          Recalculates the distance_array from the goal positions stored in :main_goal_storeA
  Example Call:   sort_according_to_distance(robot, 2, :b, 0)
  """
  def sort_according_to_distance(robot, r_x, r_y, _) do
    goals_string = Agent.get(:main_goal_storeA, fn list -> list end)
    goal_locs = calculate_goals(robot, goals_string)
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

  @doc """
  Function Name:  sort_according_to_distance
  Input:          r_x -> Robot's current x coordinate
                  r_y -> Robot's current y coordinate
                  goal_locs -> List of goal positions E.g. [["1", "c"], ["2", "e"]]
  Output:
  Logic:          Recalculates the distance_array from the goal positions given to it in goal_locs
  Example Call:
  """
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

  @doc """
  Function Name:  loop

  Input:          robot ->    Robot struct
                  visited ->  List of previously visited positions on the grid
                  diff_x ->   Numerical difference between goal_x and robot_x (goal_x - x)
                  diff_y ->   Numerical difference between goal_y and robot_y (goal_y - y)
                  goal_x ->   Goal X of the Robot
                  goal_y ->   Goal Y of the Robot
                  obs_ahead ->Boolean value to show obstacle presence
                  distance_array -> List of goal positions arranged according to distance from robot
                  goal_locs ->  List of goal locations (Unused)
                  channel ->    Channel for communication with server

  Output:         {robot, distance_array}

  Logic:          Repeat the following steps until the diff_x and diff_y become 0:
                  1. Generate a list of all squares a robot can visit
                  2. Re-arrange the list of possibles squares (squares) by the absolute distance heuristic
                  3. Remove all out of bounds square
                  4. Send all the previously visited squares to the back of the list
                  5. If multiple are previously visited arrange the previously visited ones in order of visits [normal dirs, dir of old visited node, dir of recently visited node]
                  6. Move in the desired direction with move_with_priority

  Example Call:   loop(robot, [], 2, 3, 3, :c, false, distance_array, goal_locs, channel)
  """
  def loop(robot, visited, diff_x, diff_y, goal_x, goal_y, obs_ahead, distance_array, goal_locs, channel) do
    case diff_y == 0 and diff_x == 0 do
      false ->
        # say you visit an old square or you're at the old square
        # remove it from the list and add it to the end

        # add the square it is at to the list
        {x, y, _facing} = report(robot)

        # Update position in :coords_store
        FWClientRobotA.PhoenixSocketClient.coords_store_update(channel, report(robot))


        # NOTE: y and goal_y are NUMBERS HEREAFTER
        y = @robot_map_y_atom_to_num[y]
        visited = check_for_existing(x, y, visited)

        # generate the list of squares
        # arrange the list based on abs dist function
        # abs(goal_y - y) + abs(goal_x - x)
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

        # getting a corresponding list of keys
        sq_keys = Keyword.keys(squares)

        # list of visited squares [{1,1}, {1,3}, {1,2}]
        #                         less recent -> more recent
        # go through this list and search each element for matches
        # Add it to a buffer list [:north, :south]
        # add it to the old list of squares

        sq_keys = arrange_by_visited(x, y, sq_keys, visited)

        # navigate according to the list
        {robot, obs_ahead} = move_with_priority(robot, sq_keys, obs_ahead, 0, false, goal_locs, channel)

        {x, y, _facing} = report(robot)

        # +ve implies east and -ve implies west
        diff_x = goal_x - x
        diff_y = goal_y - @robot_map_y_atom_to_num[y]

        {diff_x, diff_y} = if length(distance_array) == 0, do: {0,0}, else: {diff_x, diff_y}

        loop(robot, visited, diff_x, diff_y, goal_x, goal_y, obs_ahead, distance_array, goal_locs, channel)

      true ->
        {robot, distance_array}
    end
  end

  @doc """
  Function Name:  weeding/4
  Input:          robot -> Robot Struct
                  weeded -> String number of plant that is currently being weeded
                  distance_array -> List of goal locations of the robot arranged relative to itself
  Output:         {robot, distance_array, false} -> If the robot is able to weed without any issues
                  {robot, distance_array, true}  -> If it encounters an obstacle while weeding and has to re-adjust goals
  Logic:          There are two conditions to weeding, if there is no obstalce in the way of the robot vs if there is an obstacle
                  General:
                  1. Get the next clockwise-node relative to the robot
                  2. Rotate to face said clockwise node
                  3. Get obstacle presence from sensor
                  No Obstacle:
                  1. Initialize servos to default position
                  2. Carry out weeding
                  3. Carry out normal line-following until next node
                  4. return {robot, distance_array, false}
                  With Obstacle:
                  1. Get the next anti-clockwise node
                  2. Add anti-clockwise node to the front of the distance_array
                  3. Add the weeded plant back to main_goal_storeA
                  4. return {robot, distance_array, true}
  Example Call:   weeding(robot, "22", distance_array, channel)
  """
  def weeding(robot, weeded, distance_array, channel) do
    #If the position the robot is at is a goal, then weed the plant

      IO.puts("Weeding Started")
      {x, y, facing} = report(robot)
      {{n_x, n_y}, n_facing} = get_clockwise_node(x, y, weeded)
      IO.inspect({n_x, n_y})
      # Rotate to face clockwise node
      should_face = n_facing
      face_diff = @dir_to_num[facing] - @dir_to_num[should_face]
      {:obstacle_presence, obs_ahead} = send_robot_status(channel, robot)
      {robot, obs_ahead} = rotate(robot, should_face, face_diff, obs_ahead, 0, channel)

      # Check obstacle, if it exists then carry out other behaviour
      {robot, distance_array, obstacle} =
        if obs_ahead do
        # Add previous clockwise node to distance_array and :main_goal_store
        {{n_x, n_y}, n_facing} = get_anticlockwise_node(x, y, weeded)
        d = distance(x, @robot_map_y_atom_to_num[y], n_x, n_y)
        n_y = @robot_map_y_num_to_atom[n_y] |> Atom.to_string
        n_x = Integer.to_string(n_x)
        pos = String.to_atom(n_x <> n_y)
        distance_array = [{pos, d}] ++ distance_array
        IO.inspect(distance_array, label: "Updated dist array after weeding fail")
        Agent.update(:main_goal_storeA, fn list -> [weeded] ++ list end)
        {robot, distance_array, true}
      else
        # Go to next clockwise node
        FWClientRobotA.PhoenixSocketClient.start_weeding(channel)
        x = Agent.get(:seeding, fn x -> x end)

        if @physical do
          # FWClientRobotA.LineFollower.test_servo_a(x * 60)
          FWClientRobotA.LineFollower.servo_initialize()
          FWClientRobotA.LineFollower.stop_seeder()
          FWClientRobotA.LineFollower.weeder()
        end

        if x < 3 do
          Agent.update(:seeding, fn x -> x + 1 end)
        else
          Agent.update(:seeding, fn x -> x - 1 end)

        end
        Process.sleep(1000)
        robot = move(robot)
        IO.inspect(report(robot),label: "Weeding Done")
        FWClientRobotA.PhoenixSocketClient.send_weeding_msg(channel, String.to_integer(weeded))
        FWClientRobotA.PhoenixSocketClient.stop_weeding(channel)
        {robot, distance_array, false}
      end

  end

  @doc """
  Function Name:  get_clockwise_node
  Input:          x -> Robot's x position
                  y -> Robot's y position
                  weeded -> location of the plant around which we get the clockwise node
  Output:         {ans, next_facing[{x,y}]} <- Tuple with {{1, 2}, :north} coords and direction
  Logic:          1. Convert the weeded location into the four corresponding goals,
                  2. Maps these goals to their next clockwise nodes
                  3. Maps goals according to the directions needed to face for traversal
                  4. Packages and returns this in tuple format
  Example Call:   get_clockwise_node(2, :b, "7")
  """
  def get_clockwise_node(x, y, weeded) do
    {bl, br, tl, tr} = convert_goal_to_locations(weeded)
    next_loc = %{bl => tl, br => bl, tl => tr, tr => br}
    next_facing = %{bl => :north, br => :west, tl => :east, tr => :south}
    y = @robot_map_y_atom_to_num[y]
    ans = next_loc[{x,y}]
    {ans, next_facing[{x,y}]}
  end

  @doc """
  Function Name:  get_anti-clockwise_node
  Input:          x -> Robot's x position
                  y -> Robot's y position
                  weeded -> location of the plant around which we get the anti-clockwise node
  Output:         {ans, next_facing[{x,y}]} <- Tuple with {{1, 2}, :north} coords and direction
  Logic:          1. Convert the weeded location into the four corresponding goals,
                  2. Maps these goals to their next anti-clockwise nodes
                  3. Maps goals according to the directions needed to face for traversal
                  4. Packages and returns this in tuple format
  Example Call:   get_anti-clockwise_node(2, :b, "7")
  """
  def get_anticlockwise_node(x, y, weeded) do
    {bl, br, tl, tr} = convert_goal_to_locations(weeded)
    next_loc = %{bl => br, br => tr, tl => bl, tr => tl}
    next_facing = %{bl => :west, br => :north, tl => :south, tr => :east}
    y = @robot_map_y_atom_to_num[y]
    ans = next_loc[{x,y}]
    {ans, next_facing[{x,y}]}
  end

  @doc """
  Function Name:  arrange_by_visited/4
  Input:          x -> Robot x
                  y -> Robot y
                  sq_keys -> List with directions the bot will try to travel in
                  visited -> List of visited nodes
  Output:         Arranges sq_keys with the previously visited ones at the end
  Logic:
  Example Call:   arrange_by_visited(1, :c, [:north, :east, :south, :west], visited)
  """
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

  @doc """
  Function Name:  check_for_existing
  Input:          x ->  Current robot x
                  y ->  Current robot y
                  visited -> List that stores old nodes visited by the robot
  Output:         visted -> List
  Logic:          Checks the visited list for x, y removes it if it exists and adds it to the back of the list
  Example Call:   check_for_existing(x, y, visited)
  """
  def check_for_existing(x, y, visited) do
    # removes the x,y tuple from the list if it exists in it
    visited = Enum.reject(visited, fn {x_v, y_v} -> x_v == x and y_v == y end)
    # adds the tuple to the end of the visited list
    visited ++ [{x, y}]
  end

  @doc """
  Function Name:  rotate/6
  Input:          robot -> Robot Struct
                  should_face -> Direction robot should face (:north)
                  face_diff -> Numerical difference between the direction it is facing and the one it should face (2)
                  obs_ahead -> Obstacle presence
                  goal_locs -> Contains goal locations
                  channel -> Channel for server communication
  Output:         Rotates the robot to face the desired directions, returns {robot, obs_ahead}
  Logic:          1. Check if should_face is equal to facing i.e. the robot is oriented in the desired direction
                  2. If it is not i.e. the robot still needs to rotate
                  3. Rotate left when face_diff is -3 or 1 and right otherwise, this lets us choose the quickest way to rotate between directions
                  4. After rotating left or right, send robot status and recursively call rotate until the robot faces the right direction
  Example Call:   rotate(robot, :west, 1, false, goal_locs, channel)
  """
  def rotate(
    %FWClientRobotA.Position{facing: facing} = robot,
        should_face,
        face_diff,
        obs_ahead,
        goal_locs,
        channel
      ) do
    case should_face == facing do
      false ->
        if face_diff == -3 or face_diff == 1 do
          # rotate left
          robot = left(robot)
          {:obstacle_presence, obs_ahead} = send_robot_status(channel, robot)
          rotate(robot, should_face, face_diff, obs_ahead, goal_locs, channel)
        else
          # rotate right
          robot = right(robot)
          {:obstacle_presence, obs_ahead} = send_robot_status(channel, robot)
          rotate(robot, should_face, face_diff, obs_ahead, goal_locs, channel)
        end

      true ->
        # return the robot object/struct
        {robot, obs_ahead}
    end
  end

  @doc """
  Function Name:  move_with_priority/7
  Input:          robot -> Robot struct (We extract the facing value from this)
                  sq_keys -> List containing directions the robot should try to move in ordered by priority
                  obs_ahead -> Indicates obstacle presence
                  i -> Signals which element of the sq_keys List to consider, increments at the end of each loop of move_with_priority
                  prev_loop ->
                  goal_locs -> Goal positions of the bot
                  channel -> For server communication
  Output:         Causes the bot to move one unit in a decided direction, returns {robot, obs_ahead}
  Logic:          1. Extract the direction at i from sq_keys
                  2. Rotate robot the that direction
                  3. Check if there is an obstacle in front of the robot
                  4. Receive the other robot's position from the server
                  5. Check if the other robot is in front of this one, if yes consider it as an obstacle
                  6. If there is an obstacle/robot ahead of it try moving to the next direction in the priority list by calling move_with_priority() with i+1
                  7. If no obstacle is ahead, check once again if a robot has moved ahead of it in this time
                  8. If there is a robot ahead then don't move
                  9. If there is no robot then move
  Example Call:   move_with_priority(robot, sq_keys, obs_ahead, 1, true, goal_locs, channel)
  """
  def move_with_priority(
    %FWClientRobotA.Position{facing: facing} = robot,
        sq_keys,
        obs_ahead,
        i,
        prev_loop,
        goal_locs,
        channel
      ) do
    # rotate to the defined direction

    should_face = Enum.at(sq_keys, i)
    face_diff = @dir_to_num[facing] - @dir_to_num[should_face]

    {robot, obs_ahead} =
      if face_diff != 0,
        do: rotate(robot, should_face, face_diff, false, goal_locs, channel),
        else: {robot, obs_ahead}

    {x_b, y_b, facing_b} = FWClientRobotA.PhoenixSocketClient.coords_store_get(channel)
    {x, y, facing} = report(robot)
    {nxt_x, nxt_y} = calculate_next_position(x, y, facing)

    y_b = @robot_map_y_atom_to_num[y_b]

    if (x_b == nxt_x and y_b == nxt_y and !obs_ahead) do #or (nxt_x == nxt_x_b and nxt_y == nxt_y_b) do
      #If B is ahead then treat it as an obstacle
      obs_ahead = true
    end

    # if not, continue

    # Get previous location of this robot
    # prev = Agent.get(:previous_store_A, fn map -> Map.get(map, :prev) end, 1)
    # prev = FWClientRobotA.PhoenixSocketClient.previous_store_get(channel)
    # If the robot is at the same place for two moves in a row
    # basically, the other robot has stopped in front of this one
    # then treat the other robot as an obstacle
    # and try to navigate around it
    # obs_ahead =
    #   if prev != nil and !prev_loop do
    #     {prev_x, prev_y, prev_facing} = prev
    #     if prev_x == x and prev_y == y do
    #       true
    #     else
    #       obs_ahead
    #     end
    #   else
    #     obs_ahead
    #   end

    if obs_ahead do
      i = i + 1
      move_with_priority(robot, sq_keys, obs_ahead, i, true, goal_locs, channel)
    else
      {x_b, y_b, facing_b} = FWClientRobotA.PhoenixSocketClient.coords_store_get(channel)
      {nxt_x, nxt_y} = calculate_next_position(x, y, facing)

      y_b = @robot_map_y_atom_to_num[y_b]

      robot_ahead =
        if x_b == nxt_x and y_b == nxt_y do
          true
        else
          false
        end

      # FWClientRobotA.PhoenixSocketClient.previous_store_update(channel, report(robot))

      robot =
        if !robot_ahead do
          move(robot)
        else
          robot
        end

      FWClientRobotA.PhoenixSocketClient.coords_store_update(channel, report(robot))

      {:obstacle_presence, obs_ahead} = send_robot_status(channel, robot)

      {robot, obs_ahead}
    end
  end

  @doc """
  Function Name:  send_robot_status
  Input:          channel -> For server communication
                  robot -> Robot Struct
  Output:         {:obstacle_presence, obs_ahead}
  Logic:          First the robot sends the status(current position) to the server, it then recieves an obstacle message which it overwrites
                  with the input it receives from the sensor, it then gets the status of the robot from the server i.e. whether it is stopped or not
                  if it is stopped then pingg the server every second until the robot starts
  Example Call:   send_robot_status(channel, robot)
  """
  def send_robot_status(channel, robot) do
    # Here send the status of the robot
    # Check server to see if robot has stopped
    # If obstacle detected, send message to the server
    {:obstacle_presence, obs_ahead} = FWClientRobotA.PhoenixSocketClient.send_robot_status(channel, robot)
    if @physical and @obstacle do
      obs_ahead = FWClientRobotA.LineFollower.detect_obstacle()
    end

    if obs_ahead do
      FWClientRobotA.PhoenixSocketClient.send_obstacle_presence(channel, robot)
    end

    # Code for stopping robot here
    # ....
    {:ok, status} = FWClientRobotA.PhoenixSocketClient.get_stopped(channel)

    if status do
      FWClientRobotA.PhoenixSocketClient.acknowledge_stop(channel)
      # Check function
      is_stopped(channel)
      FWClientRobotA.PhoenixSocketClient.acknowledge_stop(channel)
      FWClientRobotA.PhoenixSocketClient.wake_up(channel)
    end

    {:obstacle_presence, obs_ahead}
  end

  @doc """
  Function Name:  is_stopped
  Input:          channel -> For server communication
  Output:         None
  Logic:          Get the status of the robot every second until the robot becomes Active
  Example Call:   is_stopped(channel)
  """
  def is_stopped(channel) do
    Process.sleep(1000)
    {:ok, status} = FWClientRobotA.PhoenixSocketClient.get_stopped(channel)
    if status do
      is_stopped(channel)
    end
  end

  @doc """
  Function Name:  calculate_next_position
  Input:          x -> integer of robot's current position
                  y -> integer of robot's current position
                  facing -> Atom with the direction the robot is facing
  Output:         tuple of {x, y} ({int, int})
  Logic:          Depending on the direct add or subtract 1 from the appropriate coords
  Example Call:   calculate_nest_position(1, 2, :north)
  """
  def calculate_next_position(x, y, facing) do
    y = @robot_map_y_atom_to_num[y]
    coord = {x, y}
    coord = if facing == :north, do: {x, y + 1}, else: coord
    coord = if facing == :south, do: {x, y - 1}, else: coord
    coord = if facing == :east, do: {x + 1, y}, else: coord
    coord = if facing == :west, do: {x - 1, y}, else: coord
    coord
  end

  @doc """
  Function Name:  eliminate_out_of_bounds
  Input:          squares -> Keyword List of directions [:east, :west, :north, :south]
                  x -> Integer of robot's current position
                  y -> Integer of robot's current position
  Output:         squares -> Keyword List of directions with the ones out of bounds removed
  Logic:          Check the squares the robot can visit in all four directions and if they are out of bounds remove that direction from the list
  Example Call:   eliminate_out_of_bounds(squares, x, y)
  """
  def eliminate_out_of_bounds(squares, x, y) do
    {_, squares} = if x + 1 > @table_top_x, do: Keyword.pop(squares, :east), else: {:ok, squares}
    {_, squares} = if x - 1 < 1, do: Keyword.pop(squares, :west), else: {:ok, squares}
    {_, squares} = if y + 1 > @table_top_x, do: Keyword.pop(squares, :north), else: {:ok, squares}
    {_, squares} = if y - 1 < 1, do: Keyword.pop(squares, :south), else: {:ok, squares}
    squares
  end

  @doc """
  Function Name:  distance
  Input:          x1 -> int, y1 -> int, x2 -> int, y2 -> int
  Output:         absolute distance between the two coordinate positions
  Logic:          Get the abs of x1-x2 and add it with abs y1-y2
  Example Call:   distance(1, 3, 4, 2)
  """
  def distance(x1, y1, x2, y2) do
    abs(x1 - x2) + abs(y1 - y2)
  end


  @doc """
  Provides the report of the robot's current position

  Examples:

      iex> {:ok, robot} = FWClientRobotA.place(2, :b, :west)
      iex> FWClientRobotA.report(robot)
      {2, :b, :west}
  """
  def report(%FWClientRobotA.Position{x: x, y: y, facing: facing} = _robot) do
    {x, y, facing}
  end

  @directions_to_the_right %{north: :east, east: :south, south: :west, west: :north}
  @doc """
  Rotates the robot to the right
  """
  def right(%FWClientRobotA.Position{facing: facing} = robot) do
    if Agent.get(:continuous_turns, fn val -> val end) == true do
      # Backwards movement
      if @physical do
        FWClientRobotA.LineFollower.move_back()
      end

      IO.puts("U-Turn, move backwards")
    end

    if @physical do
      FWClientRobotA.LineFollower.turn_right
    end

    Agent.update(:continuous_turns, fn _val -> true end)
    %FWClientRobotA.Position{robot | facing: @directions_to_the_right[facing]}
  end

  @directions_to_the_left Enum.map(@directions_to_the_right, fn {from, to} -> {to, from} end)
  @doc """
  Rotates the robot to the left
  """
  def left(%FWClientRobotA.Position{facing: facing} = robot) do
    if Agent.get(:continuous_turns, fn val -> val end) == true do
      # Backwards movement
      if @physical do
        FWClientRobotA.LineFollower.move_back()
      end
      IO.puts("U-Turn, move backwards")
    end

    if @physical do
      FWClientRobotA.LineFollower.turn_left
    end

    Agent.update(:continuous_turns, fn _val -> true end)
    %FWClientRobotA.Position{robot | facing: @directions_to_the_left[facing]}
  end

  @doc """
  Moves the robot to the north, but prevents it to fall
  """
  def move(%FWClientRobotA.Position{x: _, y: y, facing: :north} = robot) when y < @table_top_y do
    if @physical do
      FWClientRobotA.LineFollower.start
    end

    Agent.update(:continuous_turns, fn _val -> false end)
    %FWClientRobotA.Position{ robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) + 1 end) |> elem(0)
    }
  end

  @doc """
  Moves the robot to the east, but prevents it to fall
  """
  def move(%FWClientRobotA.Position{x: x, y: _, facing: :east} = robot) when x < @table_top_x do
    if @physical do
      FWClientRobotA.LineFollower.start
    end

    Agent.update(:continuous_turns, fn _val -> false end)
    %FWClientRobotA.Position{robot | x: x + 1}
  end

  @doc """
  Moves the robot to the south, but prevents it to fall
  """
  def move(%FWClientRobotA.Position{x: _, y: y, facing: :south} = robot) when y > :a do
    if @physical do
      FWClientRobotA.LineFollower.start
    end

    Agent.update(:continuous_turns, fn _val -> false end)
    %FWClientRobotA.Position{ robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) - 1 end) |> elem(0)}
  end

  @doc """
  Moves the robot to the west, but prevents it to fall
  """
  def move(%FWClientRobotA.Position{x: x, y: _, facing: :west} = robot) when x > 1 do
    if @physical do
      FWClientRobotA.LineFollower.start
    end

    Agent.update(:continuous_turns, fn _val -> false end)
    %FWClientRobotA.Position{robot | x: x - 1}
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


####################
# UNUSED FUNCTIONS #
####################

# def wait_for_b_choice() do
#   if Agent.get(:goal_choice, fn map -> Map.get(map, :B) end) == nil do
#     wait_for_b_choice()
#   end
# end

# def compare_with_store(distance_array, channel) do
#   key_list = Agent.get(:goal_storeA, fn list -> list end)
#   Enum.filter(distance_array, fn {key, _val} -> Enum.member?(key_list, key) end)
# end

# def wait_and_send(robot, channel, goal_locs) do
#   turn = FWClientRobotA.PhoenixSocketClient.turns_get(channel)
#   a_turn = turn["A"]
#   b_turn = turn["B"]
#   if (a_turn == true and b_turn == false) do

#     {:obstacle_presence, obs_ahead} = send_robot_status(channel, robot)

#     #Now update it to show that it is B's turn
#     msg = %{"A" => false, "B" => true}
#     FWClientRobotA.PhoenixSocketClient.turns_update(channel, msg)

#     obs_ahead
#   else
#     Process.sleep(500)
#     wait_and_send(robot, channel, goal_locs)
#   end
# end

# def wait_for_b(channel) do
#   turn = FWClientRobotA.PhoenixSocketClient.turns_get(channel)
#   a_turn = turn["A"]
#   b_turn = turn["B"]

#   if a_turn == "false" and b_turn == "true" do
#     wait_for_b(channel)
#   end
# end


# def wait_for_movement(nxt_x, nxt_y) do
#   {x_b, y_b, _} = Agent.get(:coords_store, fn map -> Map.get(map, :B) end)
#   if x_b == nxt_x and y_b == nxt_y do
#     wait_for_movement(nxt_x, nxt_y)
#   end
# end

# @doc """
#   Function Name:  reorder_by_distance
#   Input:
#   Output:
#   Logic:
#   Example Call:
#   """
  # def reorder_by_distance(r_x, r_y, distance_array) do
  #   distance_array = Enum.map(distance_array, fn {pos, d} ->
  #     s = Atom.to_string(pos)
  #     {g_x, g_y} = {String.at(s, 0), String.at(s, 1)}
  #     g_x = String.to_integer(g_x)
  #     g_y = String.to_atom(g_y)
  #     d = distance(g_x, @robot_map_y_atom_to_num[g_y], r_x, @robot_map_y_atom_to_num[r_y])
  #     {pos, d}

  #   end)

  #   distance_array = distance_array |> List.keysort(1)

  #   {pos, _} = Enum.at(distance_array, 0)
  #   # tup = {:"2a", 1}
  #   pos = Atom.to_string(pos)
  #   {goal_x, goal_y} = {String.at(pos, 0), String.at(pos, 1)}
  #   goal_x = String.to_integer(goal_x)
  #   goal_y = String.to_atom(goal_y)

  #   {distance_array, goal_x, @robot_map_y_atom_to_num[goal_y]}
  # end
