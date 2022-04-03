defmodule ToyRobot.CLI do
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
    IO.puts("Welcome to the [[ Task 2 ]] Toy Robot simulator!")
    print_help_message()
    receive_command()
  end

  @commands %{
    "place"  => "Places the Robot into X,Y facing F (Default is 1, A, North). " <>
                "Where facing is: north, west, south or east. " <>
                "Format: \"place X, Y, F\".",
    "start"  => "Define start position of robot (Default is 1, A, North). Format: \"start X, Y, F\".",
    "stop"   => "Specify the goal position for the robot to stop at. " <>
                "And pass a process name that listens for each action of Toy Robot.",
    "report" => "The Toy Robot reports about its position.",
    "move"   => "Moves the robot one position forward.",
    "left"   => "Rotates the robot to the left.",
    "right"  => "Rotates the robot to the right.",
    "quit"   => "Quits the simulator."
  }

  @doc """
  Receive commands passed to the CLI, parse and execute it.
  """
  defp receive_command(robot \\ nil) do
    IO.gets("> ")
    |> String.trim
    |> String.downcase
    |> String.split(" ")
    |> execute_command(robot)
  end

  @doc """
  Execute the 'place' commmand when called with no parameters.
  Place the robot at default location of (1, A, NORTH).
  """
  defp execute_command(["place"], _robot) do
    {:ok, robot} = ToyRobot.place
    robot |> receive_command
  end

  @doc """
  Execute the 'place' commmand when called with parameters
  passed as: "\"place X, Y, F\"."
  Place the robot at given location of (X, Y, F).
  """
  defp execute_command(["place" | params], _robot) do
    {x, y, facing} = process_place_params(params)

    case ToyRobot.place(x, y, facing) do
      {:ok, robot} ->
        receive_command(robot)
      {:failure, message} ->
        IO.puts message
        receive_command()
    end
  end

  @doc """
  Execute the 'start' commmand when called with no parameters.
  Provide START position to the robot as default location of (1, A, NORTH).
  """
  defp execute_command(["start"], _robot) do
    {:ok, robot} = ToyRobot.start(1, :a, :north)
    robot |> receive_command
  end

  @doc """
  Execute the 'start' commmand when called with parameters
  passed as: "\"start X, Y, F\"."
  Provide START position to the robot as given location of (X, Y, F).
  """
  defp execute_command(["start" | params], _robot) do
    {x, y, facing} = process_place_params(params)

    case ToyRobot.start(x, y, facing) do
      {:ok, robot} ->
        receive_command(robot)
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
  defp execute_command(["stop" | params], robot) do
    {goal_x, goal_y} = process_end_params(params)

    # connect to the Phoenix Server URL (defined in config.exs) via socket.
    # once ensured that socket is connected, join the channel on the server with topic "robot:status".
    # get the channel's PID in return.
    {:ok, _response, channel} = ToyRobot.PhoenixSocketClient.connect_server()

    # invoke the Toy Robot's stop function, provide necessary parameters
    case robot |> ToyRobot.stop(goal_x, goal_y, channel) do
      {:ok, robot} ->
        receive_command(robot)
      {:failure, message} ->
        IO.puts message
        receive_command()
    end
  end

  defp execute_command(["left"], robot) do
    robot |> ToyRobot.left |> receive_command
  end

  defp execute_command(["right"], robot) do
    robot |> ToyRobot.right |> receive_command
  end

  defp execute_command(["move"], robot) do
    robot |> ToyRobot.move |> receive_command
  end

  defp execute_command(["report"], nil) do
    IO.puts "The robot has not been placed yet."
    receive_command()
  end

  defp execute_command(["report"], robot) do
    {x, y, facing} = robot |> ToyRobot.report
    IO.puts String.upcase("#{x},#{y},#{facing}")

    receive_command(robot)
  end

  defp execute_command(["quit"], _robot) do
    IO.puts "\nConnection lost"
  end

  defp execute_command(_unknown, robot) do
    IO.puts("\nInvalid command. I don't know what to do.")
    print_help_message()

    receive_command(robot)
  end

  defp process_place_params(params) do
    [x, y, facing] = params |> Enum.join("") |> String.split(",") |> Enum.map(&String.trim/1)
    {String.to_integer(x), String.to_atom(y), String.to_atom(facing)}
  end

  defp process_end_params(params) do
    [x, y] = params |> Enum.join("") |> String.split(",") |> Enum.map(&String.trim/1)
    {String.to_integer(x), String.to_atom(y)}
  end

  defp print_help_message do
    IO.puts("\nThe simulator supports following commands:\n")
    @commands
    |> Enum.map(fn({command, description}) -> IO.puts("  #{command} - #{description}") end)
    IO.puts("")
  end
end
