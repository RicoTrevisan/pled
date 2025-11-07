defmodule Pled.CodeDiffTest do
  use ExUnit.Case, async: true

  alias Pled.{CodeBlock, CodeDiff}

  setup context do
    original = Application.get_env(:pled, :js_ast_runner)

    on_exit(fn ->
      if is_nil(original) do
        Application.delete_env(:pled, :js_ast_runner)
      else
        Application.put_env(:pled, :js_ast_runner, original)
      end
    end)

    if runner_tag = context[:js_runner] do
      Application.put_env(:pled, :js_ast_runner, runner_for(runner_tag))
    end

    :ok
  end

  @tag js_runner: :value_sensitive
  test "identical ASTs count as unchanged" do
    left = CodeBlock.from_source("function one() { return 1; }")
    right = CodeBlock.from_source("function one(){return 1}\n")

    result = CodeDiff.compare(left, right)

    assert result.strategy == :ast
    refute result.changed?
    assert result.summary == "AST identical"
  end

  @tag js_runner: :value_sensitive
  test "different AST fingerprints mark change" do
    left = CodeBlock.from_source("function one() { return 1; }")
    right = CodeBlock.from_source("function two() { return 2; }")

    result = CodeDiff.compare(left, right)

    assert result.strategy == :ast
    assert result.changed?
    assert result.summary == "AST changed"
  end

  @tag js_runner: :error
  test "falls back to text diff when parser unavailable" do
    left = CodeBlock.from_source("console.log('one')")
    right = CodeBlock.from_source("console.log('two')")

    result = CodeDiff.compare(left, right)

    assert result.strategy == :text
    assert result.changed?
    assert result.details.snippet.left_preview =~ "one"
    assert result.details.snippet.right_preview =~ "two"
    assert length(result.diagnostics) == 2
  end

  defp runner_for(:value_sensitive) do
    fn source, _opts ->
      {:ok,
       if String.contains?(source, "two") do
         %{"type" => "Program", "value" => 2}
       else
         %{"type" => "Program", "value" => 1}
       end}
    end
  end

  defp runner_for(:error) do
    fn _, _ -> {:error, %{reason: :dependency_missing, message: "boom", details: %{}}} end
  end

  defp runner_for(other), do: other
end
