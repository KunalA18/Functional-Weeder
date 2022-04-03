defmodule CLI do
  def main(args) do
    args |> parse_args |> process_args
  end

  def parse_args(args) do
    {params, _, _} =  OptionParser.parse(args, switches: [help: :boolean])
    params
  end

  def process_args([help: true]) do
    print_help_message()
  end

  def process_args(_) do
    IO.puts("Welcome to the [[ Task 3 ]] Toy Robot simulator!")
    print_help_message()
    receive_command()
  end

  @commands %{
    "place"  => "Places the RobotA into XA,YA facing FA (Default is 1, A, North). " <>
                "Also places the RobotB into XB, YB facing FB (Default is 5, E, South)." <>
                "Where facing is: north, west, south or east. " <>
                "Format: \"place XA, YA, FA | XB, YB, FB\".",
    "start"  => "Define start position of robot (Default is 1, A, North for toy_robotA and 5, E, SOUTH for toy_robotB)." <>
                " Format: \"start XA, YA, FA | XB, YB, FB\".",
    "stop"   => "Specify the goal positions for the robots to visit nodes at. " <>
                "And pass a process name that listens for each action of Toy Robot." <>
                "Format: \"stop X1, Y1 | X2, Y2 | X3, Y3 \".",
    "report" => "The Toy Robot reports about its position.",
    "quit"   => "Quits the simulator."
  }

  @doc """
  Receive commands passed to the CLI, parse and execute it.
  """
  defp receive_command(robotA, robotB) do
    IO.gets("> ")
    |> String.trim
    |> String.downcase
    |> String.split(" ")
    |> execute_command(robotA, robotB)
  end

  defp receive_command do
    IO.gets("> ")
    |> String.trim
    |> String.downcase
    |> String.split(" ")
    |> execute_command(:a, :b)
  end

  @doc """
  Execute the 'place' commmand when called with no parameters.
  Place the robot at default location of (1, A, NORTH).
  """
  defp execute_command(["place"], _, _) do
    {:ok, robotA} = CLI.ToyRobotA.place
    {:ok, robotB} = CLI.ToyRobotB.place
    receive_command(robotA, robotB)
  end

  @doc """
  Execute the 'place' commmand when called with parameters
  passed as: "\"place X, Y, F\"."
  Place the robot at given location of (X, Y, F).
  """
  defp execute_command(["place" | params], _, _) do
    [{x_A, y_A, facing_A}, {x_B, y_B, facing_B}] = process_place_params(params)

    case CLI.ToyRobotA.place(x_A, y_A, facing_A) do
      {:ok, robotA} ->
        case CLI.ToyRobotB.place(x_B, y_B, facing_B) do
          {:ok, robotB} ->
            receive_command(robotA, robotB)
          {:failure, message} ->
            IO.puts message
            receive_command()
        end
      {:failure, message} ->
        IO.puts message
        receive_command()
    end
  end

  @doc """
  Execute the 'start' commmand when called with no parameters.
  Provide START position to the robot as default location of (1, A, NORTH).
  """
  defp execute_command(["start"], _, _) do
    {:ok, robotA} = CLI.ToyRobotA.start(1, :a, :north)
    {:ok, robotB} = CLI.ToyRobotB.start(5, :e, :south)
    receive_command(robotA, robotB)
  end

  @doc """
  Execute the 'start' commmand when called with parameters
  passed as: "\"start X, Y, F\"."
  Provide START position to the robot as given location of (X, Y, F).
  """
  defp execute_command(["start" | params], _, _) do
    [{x_A, y_A, facing_A}, {x_B, y_B, facing_B}] = process_place_params(params)

    case CLI.ToyRobotA.place(x_A, y_A, facing_A) do
      {:ok, robotA} ->
        case CLI.ToyRobotB.place(x_B, y_B, facing_B) do
          {:ok, robotB} ->
            receive_command(robotA, robotB)
          {:failure, message} ->
            IO.puts message
            receive_command()
        end
      {:failure, message} ->
        IO.puts message
        receive_command()
    end
  end

  @doc """
  Execute the 'stop' commmand when called with parameters
  passed as: "\"stop X, Y\"."
  Provide STOP position to the robot as given location of (X, Y).
  """
  defp execute_command(["stop" | params], robotA, robotB) do
    goal_locs = process_end_params(params)

    # file object to read obstacle locations from given .txt file
    obs_data = File.read!("obstacles.txt")

    # parse the .txt file data to get list of obstacle locations
    list_obs = obs_data |> String.trim |> String.replace(" | ", "\n") |> String.split("\n")
    list_obs = Enum.map(list_obs, fn params -> String.split(params, " ") |> process_obs_params end)
    # IO.inspect(list_obs)

    # file object to write each action taken by Toy Robot
    {:ok, out_file} = File.open("task_3_output.txt", [:write])

    # spawn and register CLI server process
    # with 'listen_from_client' callback function
    pid = spawn_link(fn -> listen_from_client([], list_obs, out_file) end)
    Process.register(pid, :cli_robot_state)

    # spawn and register process for Toy Robot B
    # with a call to 'stop' function of 'CLI.ToyRobotB.stop/4'
    pid_toy_robotB = spawn_link(fn -> init_toyrobotB(robotA, robotB, goal_locs, :cli_robot_state) end)
    Process.register(pid_toy_robotB, :init_toyrobotB)

    # invoke the Toy Robot A's stop function, provide necessary parameters
    case robotA |> CLI.ToyRobotA.stop(goal_locs, :cli_robot_state) do
      {:ok, robotA} ->
        receive_command(robotA, robotB)
      {:failure, message} ->
        IO.puts message
        receive_command()
      _ -> receive_command()
    end
  end

  def init_toyrobotB(robotA, robotB, goal_locs, cli_proc_name) do

    # invoke the Toy Robot B's stop function, provide necessary parameters
    case robotB |> CLI.ToyRobotB.stop(goal_locs, cli_proc_name) do
      {:ok, robotB} ->
        receive_command(robotA, robotB)
      {:failure, message} ->
        IO.puts message
        receive_command()
      _ -> receive_command()
    end

  end

  @doc """
  Listen to 'toy_robotA.ex' client and receives Toy Robot's current status
  after every action taken by the Toy Robot.
  Indicate the presence of obstacle to the ToyRobot client process,
  if located ahead of robot's current position and facing
  Write the action taken with position of robot to a text (.txt) file.
  """
  def listen_from_client(state, list_obs, out_file) do
    receive do
      # Toy Robot A
      {:toyrobotA_status, robot_x, robot_y, robot_face} ->
        IO.puts("Received by CLI Server from Toy Robot A: #{robot_x}, #{robot_y}, #{robot_face}")
        IO.binwrite(out_file, "A => #{robot_x}, #{robot_y}, #{robot_face}\n")
        send(:client_toyrobotA, {:obstacle_presence, Enum.member?(list_obs, {robot_x, robot_y, robot_face})})
        listen_from_client([{robot_x, robot_y, robot_face} | state], list_obs, out_file)

      # Toy Robot B
      {:toyrobotB_status, robot_x, robot_y, robot_face} ->
        IO.puts("Received by CLI Server from Toy Robot B: #{robot_x}, #{robot_y}, #{robot_face}")
        IO.binwrite(out_file, "B => #{robot_x}, #{robot_y}, #{robot_face}\n")
        send(:client_toyrobotB, {:obstacle_presence, Enum.member?(list_obs, {robot_x, robot_y, robot_face})})
        listen_from_client([{robot_x, robot_y, robot_face} | state], list_obs, out_file)
    end
  end

  defp execute_command(["report"], robotA, robotB) do
    {x, y, facing} = robotA |> CLI.ToyRobotA.report
    IO.puts String.upcase("A => #{x},#{y},#{facing}")

    {x, y, facing} = robotB |> CLI.ToyRobotB.report
    IO.puts String.upcase("B => #{x},#{y},#{facing}")

    receive_command(robotA, robotB)
  end

  defp execute_command(["quit"], _robotA, _robotB) do
    IO.puts "\nConnection lost"
  end

  defp execute_command(_unknown, robotA, robotB) do
    IO.puts("\nInvalid command. I don't know what to do.")
    print_help_message()

    receive_command(robotA, robotB)
  end

  defp process_place_params(params) do
    [[x_A, y_A, facing_A], [x_B, y_B, facing_B]] = params
                    |> Enum.join("") |> String.split("|") |> Enum.map(fn(x) -> String.split(x, ",") end)
    # [x, y, facing] = params |> Enum.join("") |> String.split(",") |> Enum.map(&String.trim/1)
    [{String.to_integer(x_A), String.to_atom(y_A), String.to_atom(facing_A)},
      {String.to_integer(x_B), String.to_atom(y_B), String.to_atom(facing_B)}]
  end

  defp process_end_params(params) do
    goal_locations = params |> Enum.join("") |> String.split("|") |> Enum.map(fn(x) -> String.split(x, ",") end)
    goal_locations
    # {String.to_integer(x), String.to_atom(y)}
  end

  defp process_obs_params(params) do
    [x, y, facing] = params |> Enum.join("") |> String.split(",") |> Enum.map(&String.trim/1)
    {String.to_integer(x), String.to_atom(y), String.to_atom(facing)}
  end

  defp print_help_message do
    IO.puts("\nThe simulator supports following commands:\n")
    @commands
    |> Enum.map(fn({command, description}) -> IO.puts("  #{command} - #{description}") end)
    IO.puts("")
  end
end
