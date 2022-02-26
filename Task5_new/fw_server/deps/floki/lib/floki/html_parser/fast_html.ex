defmodule Floki.HTMLParser.FastHtml do
  @behaviour Floki.HTMLParser
  @moduledoc false

  @impl true
  def parse_document(html) do
    execute_with_module(fn module -> module.decode(html) end)
  end

  @impl true
  def parse_fragment(html) do
    execute_with_module(fn module -> module.decode_fragment(html) end)
  end

  defp execute_with_module(fun) do
    case Code.ensure_loaded(:fast_html) do
      {:module, module} ->
        case fun.(module) do
          {:ok, result} ->
            {:ok, result}

          {:error, _message} = error ->
            error
        end

      {:error, _reason} ->
        raise "Expected module :fast_html to be available."
    end
  end
end
