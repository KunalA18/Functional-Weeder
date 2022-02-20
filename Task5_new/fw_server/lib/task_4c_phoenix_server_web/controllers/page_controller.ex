defmodule FWServerWeb.PageController do
  use FWServerWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
