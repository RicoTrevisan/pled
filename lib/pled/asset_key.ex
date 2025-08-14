defmodule Pled.AssetKey do
  @moduledoc """
  Generates sequential asset keys for Bubble.io plugins.

  Keys follow the pattern AAA, AAB, AAC, ..., AAZ, ABA, ABB, etc.
  """

  @doc """
  Generates the next available asset key based on existing keys.

  ## Examples

      iex> Pled.AssetKey.generate_next([])
      "AAA"

      iex> Pled.AssetKey.generate_next(["AAA"])
      "AAB"

      iex> Pled.AssetKey.generate_next(["AAA", "AAB", "AAC"])
      "AAD"

      iex> Pled.AssetKey.generate_next(["AAZ"])
      "ABA"
  """
  def generate_next(existing_keys) when is_list(existing_keys) do
    existing_keys
    |> find_next_sequential_key()
  end

  @doc """
  Generates the next available asset key from plugin data.

  ## Examples

      iex> Pled.AssetKey.generate_from_plugin_data(%{"assets" => %{"AAA" => %{}}})
      "AAB"

      iex> Pled.AssetKey.generate_from_plugin_data(%{})
      "AAA"
  """
  def generate_from_plugin_data(plugin_data) when is_map(plugin_data) do
    existing_keys = Map.keys(plugin_data["assets"] || %{})
    generate_next(existing_keys)
  end

  # Private functions

  defp find_next_sequential_key([]) do
    "AAA"
  end

  defp find_next_sequential_key(existing_keys) do
    # Filter to only include valid 3-letter uppercase keys
    valid_keys =
      existing_keys
      |> Enum.filter(&valid_key?/1)
      |> Enum.sort()

    case valid_keys do
      [] ->
        "AAA"

      keys ->
        last_key = List.last(keys)
        increment_key(last_key)
    end
  end

  defp valid_key?(key) when is_binary(key) do
    String.match?(key, ~r/^[A-Z]{3}$/)
  end

  defp valid_key?(_), do: false

  defp increment_key(key) when is_binary(key) and byte_size(key) == 3 do
    key
    |> String.to_charlist()
    |> increment_charlist()
    |> List.to_string()
  end

  defp increment_charlist([c1, c2, c3]) do
    cond do
      c3 < ?Z ->
        # Simple case: just increment the last character
        [c1, c2, c3 + 1]

      c3 == ?Z and c2 < ?Z ->
        # Carry over to middle character
        [c1, c2 + 1, ?A]

      c3 == ?Z and c2 == ?Z and c1 < ?Z ->
        # Carry over to first character
        [c1 + 1, ?A, ?A]

      c3 == ?Z and c2 == ?Z and c1 == ?Z ->
        # Overflow: wrap around to AAA (or could raise an error)
        # This gives us 17,576 possible keys (26^3)
        raise "Asset key space exhausted (reached ZZZ)"
    end
  end

  @doc """
  Checks if a key is valid (3 uppercase letters).

  ## Examples

      iex> Pled.AssetKey.valid?("AAA")
      true

      iex> Pled.AssetKey.valid?("AA")
      false

      iex> Pled.AssetKey.valid?("aaa")
      false

      iex> Pled.AssetKey.valid?("A1A")
      false
  """
  def valid?(key) do
    valid_key?(key)
  end

  @doc """
  Returns the next key in sequence after the given key.

  ## Examples

      iex> Pled.AssetKey.next("AAA")
      "AAB"

      iex> Pled.AssetKey.next("AAZ")
      "ABA"

      iex> Pled.AssetKey.next("AZZ")
      "BAA"
  """
  def next(key) when is_binary(key) do
    if valid_key?(key) do
      increment_key(key)
    else
      raise ArgumentError, "Invalid asset key: #{key}"
    end
  end
end
