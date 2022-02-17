defmodule Task4CPhoenixServerWeb.PageControllerTest do
  use Task4CPhoenixServerWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end
end
