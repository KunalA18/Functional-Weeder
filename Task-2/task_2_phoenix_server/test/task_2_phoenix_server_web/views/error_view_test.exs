defmodule Task2PhoenixServerWeb.ErrorViewTest do
  use Task2PhoenixServerWeb.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  test "renders 404.html" do
    assert render_to_string(Task2PhoenixServerWeb.ErrorView, "404.html", []) == "Not Found"
  end

  test "renders 500.html" do
    assert render_to_string(Task2PhoenixServerWeb.ErrorView, "500.html", []) == "Internal Server Error"
  end
end
