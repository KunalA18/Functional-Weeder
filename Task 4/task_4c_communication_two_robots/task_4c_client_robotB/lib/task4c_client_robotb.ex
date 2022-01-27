defmodule Task4CClientRobotB do
  # max x-coordinate of table top
  @table_top_x 6
  # max y-coordinate of table top
  @table_top_y :f
  # mapping of y-coordinates
  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5, :f => 6}
  # maps directions to numbers
  @dir_to_num %{:north => 1, :east => 2, :south => 3, :west => 4}

  @doc """
  Places the robot to the default position of (1, A, North)

  Examples:

      iex> Task4CClientRobotB.place
      {:ok, %Task4CClientRobotB.Position{facing: :north, x: 1, y: :a}}
  """
  def place do
    {:ok, %Task4CClientRobotB.Position{}}
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

      iex> Task4CClientRobotB.place(1, :b, :south)
      {:ok, %Task4CClientRobotB.Position{facing: :south, x: 1, y: :b}}

      iex> Task4CClientRobotB.place(-1, :f, :north)
      {:failure, "Invalid position"}

      iex> Task4CClientRobotB.place(3, :c, :north_east)
      {:failure, "Invalid facing direction"}
  """
  def place(x, y, facing) do
    {:ok, %Task4CClientRobotB.Position{x: x, y: y, facing: facing}}
  end

  @doc """
  Provide START position to the robot as given location of (x, y, facing) and place it.
  """
  def start(x, y, facing) do
    place(x, y, facing)
  end

  def process_start_message(start_map) do
    data = start_map["A"]
    x = Enum.at(data, 0) |> String.to_integer
    y = Enum.at(data, 1)
    y = Regex.replace(~r/ /, y, "") |> String.to_atom #Regex to remove all spaces in the string
    dir = Enum.at(data, 2)
    dir =  Regex.replace(~r/ /, dir, "") |> String.to_atom #Regex to remove all spaces in the string

    {x,y,dir}
  end

  def wait_for_start(start_map, channel) do
    Process.sleep(2000)
    {:ok, start_map} = Task4CClientRobotB.PhoenixSocketClient.get_start(channel)
    if Map.get(start_map, "B") == nil do
      wait_for_start(start_map, channel)
    else
      process_start_message(start_map)
    end
  end

  @doc """
  Main function to initiate the sequence of tasks to achieve by the Client Robot B,
  such as connect to the Phoenix server, get the robot B's start and goal locations to be traversed.
  Call the respective functions from this module and others as needed.
  You may create extra helper functions as needed.
  """
  def main (args) do
    #Connect to server
    {:ok, _response, channel} = Task4CClientRobotB.PhoenixSocketClient.connect_server()
    # IO.inspect(channel, "Channel")

    #function to get goal positions

    {:ok, goals_string} = Task4CClientRobotB.PhoenixSocketClient.get_goals(channel)
    goal_locs = calculate_goals(goals_string)
    IO.inspect(goal_locs, label: "Goal locations:")

    {start_x, start_y, start_dir} = wait_for_start(%{A: nil, B: nil}, channel) #{1, :a, :north}

    {:ok, robot} = start(start_x, start_y, start_dir)

    Task4CClientRobotB.PhoenixSocketClient.send_robot_status(channel, robot, goal_locs)

    stop(robot, goal_locs, channel)

    #We need to move all agents onto the server

    ###########################
    ## complete this funcion ##
    ###########################
  end

  def calculate_goals(goals_string) do
    #Arena description

    #########################
    # 31# 32# 33# 34# 35# 36#
    #########################
    # 1 # 2 # 3 # 4 # 5 # 6 #
    #########################

    goal_locs = Enum.reduce(goals_string, [], fn s, acc ->
      i = String.to_integer(s)
      last_digit = rem(i, 10)
      first_digit = Integer.floor_div(i, 10)
      convert_to_loc(first_digit, last_digit, acc)
    end)
  end

  def convert_to_loc(first_digit, last_digit, acc) do
    acc = if (first_digit == 0) do
      if last_digit <= 5 do
        x = Integer.to_string(last_digit)
        x = if x == "0", do: "5", else: x
        y = "a"
        acc ++ [[x,y]]
      else
        x = Integer.to_string(last_digit - 5)
        x = if x == "0", do: "5", else: x
        y = "b"
        acc ++ [[x,y]]
      end
    else
      if (first_digit == 1) do
        if last_digit <= 5 do
          x = Integer.to_string(last_digit)
          x = if x == "0", do: "5", else: x
          y = "c"
          acc ++ [[x,y]]
        else
          x = Integer.to_string(last_digit - 5)
          x = if x == "0", do: "5", else: x
          y = "d"
          acc ++ [[x,y]]
        end
      else
        if (first_digit == 2) do
          if last_digit <= 5 do
            x = Integer.to_string(last_digit)
            x = if x == "0", do: "5", else: x
            y = "e"
            acc ++ [[x,y]]
          else
            x = Integer.to_string(last_digit - 5)
            x = if x == "0", do: "5", else: x
            y = "f"
            acc ++ [[x,y]]
          end
        else
          acc
        end

      end
    end
  end


  def wait_for_agent() do
    if Process.whereis(:coords_store) == nil or Process.whereis(:goal_store) == nil or Process.whereis(:turns) == nil or Process.whereis(:goal_choice) == nil do
      wait_for_agent()
    end
  end
  @doc """
  Provide GOAL positions to the robot as given location of [(x1, y1),(x2, y2),..] and plan the path from START to these locations.
  Make a call to ToyRobot.PhoenixSocketClient.send_robot_status/2 to get the indication of obstacle presence ahead of the robot.
  """
  def stop(robot, goal_locs, channel) do
    # Wait for the Agent to be created
    # wait_for_agent()

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
      # send status of the start location
      {:obstacle_presence, obs_ahead} = Task4CClientRobotB.PhoenixSocketClient.send_robot_status(channel, robot, goal_locs)
    else
      Agent.update(:goal_choice, fn map -> Map.put(map, :B, {Enum.at(distance_array, 0)}) end)
      # Feed the distance_array to a function which loops through the thing giving goal co-ordinates one by one
      #loop_through_goal_locs(distance_array, robot, channel)
    end

    ###########################
    ## complete this funcion ##
    ###########################

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
  @doc """
  Provides the report of the robot's current position

  Examples:

      iex> {:ok, robot} = Task4CClientRobotB.place(2, :b, :west)
      iex> Task4CClientRobotB.report(robot)
      {2, :b, :west}
  """
  def report(%Task4CClientRobotB.Position{x: x, y: y, facing: facing} = _robot) do
    {x, y, facing}
  end

  @directions_to_the_right %{north: :east, east: :south, south: :west, west: :north}
  @doc """
  Rotates the robot to the right
  """
  def right(%Task4CClientRobotB.Position{facing: facing} = robot) do
    %Task4CClientRobotB.Position{robot | facing: @directions_to_the_right[facing]}
  end

  @directions_to_the_left Enum.map(@directions_to_the_right, fn {from, to} -> {to, from} end)
  @doc """
  Rotates the robot to the left
  """
  def left(%Task4CClientRobotB.Position{facing: facing} = robot) do
    %Task4CClientRobotB.Position{robot | facing: @directions_to_the_left[facing]}
  end

  @doc """
  Moves the robot to the north, but prevents it to fall
  """
  def move(%Task4CClientRobotB.Position{x: _, y: y, facing: :north} = robot) when y < @table_top_y do
    %Task4CClientRobotB.Position{ robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) + 1 end) |> elem(0)
    }
  end

  @doc """
  Moves the robot to the east, but prevents it to fall
  """
  def move(%Task4CClientRobotB.Position{x: x, y: _, facing: :east} = robot) when x < @table_top_x do
    %Task4CClientRobotB.Position{robot | x: x + 1}
  end

  @doc """
  Moves the robot to the south, but prevents it to fall
  """
  def move(%Task4CClientRobotB.Position{x: _, y: y, facing: :south} = robot) when y > :a do
    %Task4CClientRobotB.Position{ robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) - 1 end) |> elem(0)}
  end

  @doc """
  Moves the robot to the west, but prevents it to fall
  """
  def move(%Task4CClientRobotB.Position{x: x, y: _, facing: :west} = robot) when x > 1 do
    %Task4CClientRobotB.Position{robot | x: x - 1}
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
