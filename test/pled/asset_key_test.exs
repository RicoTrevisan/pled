defmodule Pled.AssetKeyTest do
  use ExUnit.Case
  alias Pled.AssetKey

  describe "generate_next/1" do
    test "returns AAA for empty list" do
      assert AssetKey.generate_next([]) == "AAA"
    end

    test "returns AAB when AAA exists" do
      assert AssetKey.generate_next(["AAA"]) == "AAB"
    end

    test "returns next sequential key" do
      assert AssetKey.generate_next(["AAA", "AAB", "AAC"]) == "AAD"
    end

    test "handles rollover from Z to next letter" do
      assert AssetKey.generate_next(["AAZ"]) == "ABA"
      assert AssetKey.generate_next(["AZZ"]) == "BAA"
    end

    test "ignores invalid keys and finds next after valid ones" do
      assert AssetKey.generate_next(["AAA", "invalid", "AAB", "123"]) == "AAC"
    end

    test "handles non-sequential existing keys" do
      assert AssetKey.generate_next(["AAC", "AAA", "AAE"]) == "AAF"
    end

    test "starts from AAA if all existing keys are invalid" do
      assert AssetKey.generate_next(["invalid", "123", "aa"]) == "AAA"
    end

    test "handles mixed case (ignores lowercase)" do
      assert AssetKey.generate_next(["aaa", "AAA", "bbb"]) == "AAB"
    end

    test "raises error when reaching ZZZ" do
      assert_raise RuntimeError, "Asset key space exhausted (reached ZZZ)", fn ->
        AssetKey.generate_next(["ZZZ"])
      end
    end
  end

  describe "generate_from_plugin_data/1" do
    test "returns AAA for empty plugin data" do
      assert AssetKey.generate_from_plugin_data(%{}) == "AAA"
    end

    test "returns AAA when assets key is missing" do
      assert AssetKey.generate_from_plugin_data(%{"other" => "data"}) == "AAA"
    end

    test "returns next key based on existing assets" do
      plugin_data = %{
        "assets" => %{
          "AAA" => %{"name" => "file1.js"},
          "AAB" => %{"name" => "file2.js"}
        }
      }

      assert AssetKey.generate_from_plugin_data(plugin_data) == "AAC"
    end

    test "handles empty assets map" do
      assert AssetKey.generate_from_plugin_data(%{"assets" => %{}}) == "AAA"
    end
  end

  describe "valid?/1" do
    test "returns true for valid 3-letter uppercase keys" do
      assert AssetKey.valid?("AAA") == true
      assert AssetKey.valid?("XYZ") == true
      assert AssetKey.valid?("BBB") == true
    end

    test "returns false for invalid keys" do
      assert AssetKey.valid?("AA") == false
      assert AssetKey.valid?("AAAA") == false
      assert AssetKey.valid?("aaa") == false
      assert AssetKey.valid?("A1A") == false
      assert AssetKey.valid?("12A") == false
      assert AssetKey.valid?(123) == false
      assert AssetKey.valid?(nil) == false
    end
  end

  describe "next/1" do
    test "returns next key in sequence" do
      assert AssetKey.next("AAA") == "AAB"
      assert AssetKey.next("AAB") == "AAC"
      assert AssetKey.next("AAY") == "AAZ"
    end

    test "handles rollover correctly" do
      assert AssetKey.next("AAZ") == "ABA"
      assert AssetKey.next("ABZ") == "ACA"
      assert AssetKey.next("AZZ") == "BAA"
      assert AssetKey.next("ZZY") == "ZZZ"
    end

    test "raises ArgumentError for invalid keys" do
      assert_raise ArgumentError, "Invalid asset key: AA", fn ->
        AssetKey.next("AA")
      end

      assert_raise ArgumentError, "Invalid asset key: aaa", fn ->
        AssetKey.next("aaa")
      end

      assert_raise ArgumentError, "Invalid asset key: 123", fn ->
        AssetKey.next("123")
      end
    end

    test "raises error when trying to increment ZZZ" do
      assert_raise RuntimeError, "Asset key space exhausted (reached ZZZ)", fn ->
        AssetKey.next("ZZZ")
      end
    end
  end

  describe "sequence generation" do
    test "generates correct sequence from AAA to ABA" do
      keys =
        Enum.reduce(1..27, ["AAA"], fn _, acc ->
          last = List.last(acc)

          if last == "ABA" do
            acc
          else
            acc ++ [AssetKey.next(last)]
          end
        end)

      expected = [
        "AAA",
        "AAB",
        "AAC",
        "AAD",
        "AAE",
        "AAF",
        "AAG",
        "AAH",
        "AAI",
        "AAJ",
        "AAK",
        "AAL",
        "AAM",
        "AAN",
        "AAO",
        "AAP",
        "AAQ",
        "AAR",
        "AAS",
        "AAT",
        "AAU",
        "AAV",
        "AAW",
        "AAX",
        "AAY",
        "AAZ",
        "ABA"
      ]

      assert keys == expected
    end

    test "generates correct sequence crossing multiple boundaries" do
      assert AssetKey.next("AZY") == "AZZ"
      assert AssetKey.next("AZZ") == "BAA"
      assert AssetKey.next("BAA") == "BAB"

      assert AssetKey.next("ZZX") == "ZZY"
      assert AssetKey.next("ZZY") == "ZZZ"
    end
  end
end
