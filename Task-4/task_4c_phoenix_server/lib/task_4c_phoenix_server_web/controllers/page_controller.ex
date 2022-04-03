defmodule Task4CPhoenixServerWeb.PageController do
  use Task4CPhoenixServerWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
