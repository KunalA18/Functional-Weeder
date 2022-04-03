defmodule Task2PhoenixServerWeb.FindObstaclePresence do
  def is_obstacle_ahead?(x, y, face) do

    # file object to read obstacle locations from given .txt file
    obs_data = File.read!("obstacles.txt")

    # parse the .txt file data to get list of obstacle locations
    list_obs = obs_data |> String.trim |> String.replace(" | ", "\n") |> String.split("\n")
    list_obs = Enum.map(list_obs, fn params -> String.split(params, " ") |> process_params() end)

    Enum.member?(list_obs, {x, String.to_atom(y), String.to_atom(face)})
  end

  defp process_params(params) do
    [x, y, facing] = params |> Enum.join("") |> String.split(",") |> Enum.map(&String.trim/1)
    {String.to_integer(x), String.to_atom(y), String.to_atom(facing)}
  end
end
