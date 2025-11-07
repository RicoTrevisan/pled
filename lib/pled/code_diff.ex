defmodule Pled.CodeDiff do
  @moduledoc """
  Compares two `Pled.CodeBlock` structs and reports whether the underlying code
  meaningfully changed.

  The module prefers AST fingerprints when both blocks parsed successfully and
  automatically falls back to raw text comparisons (plus diagnostics) when ASTs
  are unavailable.
  """

  alias Pled.CodeBlock

  defmodule Result do
    @moduledoc false
    @enforce_keys [:strategy, :changed?]
    defstruct strategy: :text,
              changed?: false,
              summary: nil,
              diagnostics: [],
              details: %{}
  end

  @doc """
  Produces a diff `Result` between two code blocks.
  """
  @spec compare(CodeBlock.t(), CodeBlock.t()) :: Result.t()
  def compare(%CodeBlock{} = left, %CodeBlock{} = right) do
    diagnostics = left.diagnostics ++ right.diagnostics

    cond do
      CodeBlock.ast?(left) and CodeBlock.ast?(right) ->
        changed? = CodeBlock.fingerprint(left) != CodeBlock.fingerprint(right)

        %Result{
          strategy: :ast,
          changed?: changed?,
          summary: if(changed?, do: "AST changed", else: "AST identical"),
          diagnostics: diagnostics,
          details: %{
            left_fingerprint: CodeBlock.fingerprint(left),
            right_fingerprint: CodeBlock.fingerprint(right)
          }
        }

      true ->
        changed? = left.raw != right.raw

        %Result{
          strategy: :text,
          changed?: changed?,
          summary: if(changed?, do: "Source changed", else: "Source identical"),
          diagnostics: diagnostics,
          details: %{
            left_hash: left.raw_hash,
            right_hash: right.raw_hash,
            snippet: text_snippet(left.raw, right.raw)
          }
        }
    end
  end

  defp text_snippet(left, right) do
    %{
      left_preview: preview(left),
      right_preview: preview(right)
    }
  end

  defp preview(value) do
    value
    |> String.replace("\n", "\\n")
    |> truncate(120)
  end

  defp truncate(value, max) when byte_size(value) <= max, do: value
  defp truncate(value, max), do: String.slice(value, 0, max) <> "…"
end
