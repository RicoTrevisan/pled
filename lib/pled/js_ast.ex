defmodule Pled.JsAst do
  @moduledoc """
  Thin wrapper around a Node-based parser that produces JavaScript AST JSON.

  Parsing is optional at runtime. When the Node script or its dependencies are
  missing, callers receive a structured error and can fall back to raw text
  comparisons.
  """

  @typedoc """
  Structured error returned when parsing fails.
  """
  @type parse_error :: %{
          reason: atom(),
          message: String.t(),
          details: map() | nil
        }

  @doc """
  Attempts to parse a JavaScript snippet and return the AST as a map.
  """
  @spec parse(String.t(), keyword()) :: {:ok, map()} | {:error, parse_error}
  def parse(source, opts \\ []) when is_binary(source) do
    runner = Application.get_env(:pled, :js_ast_runner, {__MODULE__, :node_runner})
    invoke_runner(runner, source, opts)
  end

  defp invoke_runner({module, fun}, source, opts) when is_atom(module) and is_atom(fun) do
    apply(module, fun, [source, opts])
  end

  defp invoke_runner(fun, source, opts) when is_function(fun, 2) do
    fun.(source, opts)
  end

  defp invoke_runner(_, _source, _opts) do
    {:error,
     %{
       reason: :invalid_runner,
       message: "Invalid js_ast runner configuration",
       details: %{}
     }}
  end

  @doc false
  def node_runner(source, opts) do
    script = parser_script()

    unless File.exists?(script) do
      return_error(:script_missing, "JS AST parser script not found", %{script: script})
    else
      payload =
        %{
          "code" => source,
          "module" => Keyword.get(opts, :module?, false),
          "filename" => Keyword.get(opts, :path)
        }
        |> Jason.encode!()
        |> Base.encode64()

      env = [{"NODE_ENV", "production"}, {"PLED_AST_PAYLOAD", payload}]

      case System.cmd(node_executable(), [script], env: env, stderr_to_stdout: true) do
        {raw_output, 0} ->
          handle_script_response(raw_output)

        {raw_output, status} ->
          return_error(:script_error, "Node parser exited with status #{status}", %{
            output: raw_output
          })
      end
    end
  rescue
    e in ErlangError ->
      return_error(:exec_failure, Exception.message(e), %{})
  end

  defp parser_script do
    :pled
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("js/parse_ast.js")
  end

  defp node_executable do
    System.get_env("NODE_BIN", "node")
  end

  defp handle_script_response(raw_output) do
    with {:ok, decoded} <- Jason.decode(raw_output) do
      case decoded do
        %{"ok" => true, "ast" => ast} ->
          {:ok, ast}

        %{"ok" => false} ->
          return_error(
            map_reason(decoded),
            Map.get(decoded, "message", "JS parser reported an error"),
            Map.get(decoded, "details", %{})
          )

        _ ->
          return_error(:unexpected_payload, "Unexpected payload from JS parser", %{
            payload: decoded
          })
      end
    else
      {:error, _} ->
        return_error(:invalid_json, "Failed to decode JS parser output", %{output: raw_output})
    end
  end

  defp map_reason(%{"error" => error}) when is_binary(error) do
    error
    |> String.replace(~r/[^a-zA-Z0-9_]+/, "_")
    |> String.downcase()
    |> String.to_atom()
  end

  defp map_reason(_), do: :unknown

  defp return_error(reason, message, details) do
    {:error, %{reason: reason, message: message, details: details}}
  end
end
