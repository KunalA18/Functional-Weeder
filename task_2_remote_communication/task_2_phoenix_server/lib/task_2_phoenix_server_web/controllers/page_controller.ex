defmodule Task2PhoenixServerWeb.PageController do
  use Task2PhoenixServerWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
