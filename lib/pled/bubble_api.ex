defmodule Pled.BubbleApi do
  @moduledoc """
  API client for interacting with Bubble.io plugin endpoints.
  """

  @base_url "https://bubble.io/appeditor"

  @doc """
  Fetches plugin data from Bubble.io.
  
  Requires environment variables:
  - PLUGIN_ID: The ID of the plugin to fetch
  - COOKIE: Authentication cookie for Bubble.io
  
  Returns `{:ok, plugin_data}` on success or `{:error, reason}` on failure.
  """
  def fetch_plugin do
    with {:ok, plugin_id} <- get_env_var("PLUGIN_ID"),
         {:ok, cookie} <- get_env_var("COOKIE") do
      
      url = "#{@base_url}/get_plugin?id=#{plugin_id}"
      
      headers = [
        {"cookie", cookie},
        {"user-agent", "Pled/0.1.0"}
      ]
      
      case Req.get(url, headers: headers) do
        {:ok, %{status: 200, body: body}} ->
          {:ok, body}
        
        {:ok, %{status: status, body: body}} ->
          {:error, "HTTP #{status}: #{inspect(body)}"}
        
        {:error, reason} ->
          {:error, "Request failed: #{inspect(reason)}"}
      end
    end
  end
  
  defp get_env_var(name) do
    case System.get_env(name) do
      nil -> {:error, "Environment variable #{name} is not set"}
      value -> {:ok, value}
    end
  end
end