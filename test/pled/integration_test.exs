defmodule Pled.IntegrationTest do
  use ExUnit.Case, async: true

  alias Pled.Commands.Encoder
  alias Pled.Commands.Decoder

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    # simulate pull
    example_path = "./priv/examples/plugin.json"
    File.mkdir_p!(Path.join(tmp_dir, "src"))
    File.cp(example_path, Path.join([tmp_dir, "src", "plugin.json"]))

    src_path = Path.join([tmp_dir, "src"])
    plugin_data = File.read!(Path.join(src_path, "plugin.json"))

    cwd = File.cwd!()
    File.cd!(tmp_dir)

    plugin_data
    |> Jason.decode!()
    |> Decoder.decode()

    File.cd!(cwd)

    {:ok, src_path: src_path}
  end

  test "decode/1 extracts 4 root files", %{src_path: src_path} do
    assert File.ls!(src_path) == [
             "plugin.json",
             "shared.html",
             "elements",
             "actions"
           ]
  end

  describe "decode/1 actions" do
    test "src/actions has 1 action", %{src_path: src_path} do
      actions_path = Path.join(src_path, "actions")
      assert File.ls!(actions_path) == ["generate-jwt-key-AEK"]
    end

    test "src/actions/action has only json and js in action ", %{src_path: src_path} do
      action_path = Path.join([src_path, "actions", "generate-jwt-key-AEK"])
      assert File.ls!(action_path) == ["server.js", "generate-jwt-key.json"]
    end

    test "src/actions/action/action.json doesn't have server key", %{src_path: src_path} do
      action_path = Path.join([src_path, "actions", "generate-jwt-key-AEK"])

      action_json =
        action_path
        |> Path.join("generate-jwt-key.json")
        |> File.read!()
        |> Jason.decode!()

      assert Map.has_key?(action_json["code"], "server") == false
    end
  end

  describe "decode/1 elements" do
    test "decode less files", %{src_path: src_path} do
      elements_path = Path.join(src_path, "elements")
      assert File.ls!(elements_path) == ["tiptap-AAC"]

      element_path = Path.join(elements_path, "tiptap-AAC")

      assert File.ls!(element_path) == [
               "reset.js",
               "preview.js",
               # ".key",
               "update.js",
               "initialize.js",
               "fields.txt",
               "actions",
               "AAC.json"
             ]

      # TODO: assert that JSON doesn't have code

      element_actions_path = Path.join(element_path, "actions")

      assert File.ls!(element_actions_path) == [
               "task-list-ABS.js",
               "table-split-cell-ACy.js",
               "h3-AAx.js",
               "horizontal-rule-ABO.js",
               "table-toggle-header-column-ACq.js",
               "align-text-ACd.js",
               "clear-contents-ABp.js",
               "italic-AAj.js",
               "table-delete-row-ACw.js",
               "set-hard-break-AGC.js",
               "unset-color-AFZ.js",
               "select-entire-block-AFi.js",
               "table-add-column-after-ACs.js",
               "table-add-row-after-ACu.js",
               "focus-ABr.js",
               "insert-content-ADG.js",
               "underline-ADB.js",
               "set-font-family-AFS.js",
               "set-color-AFX.js",
               "insert-table-ACl.js",
               "indent-item-ABH.js",
               "add-youtube-ADI.js",
               "table-merge-cells-ACz.js",
               "h5-AAz.js",
               "table-merge-or-split-ADA.js",
               "h1-AAp.js",
               "strikethrough-AAm.js",
               "insert-image-ACD.js",
               "highlight-ACi.js",
               "table-delete-column-ACx.js",
               "table-add-column-before-ACt.js",
               "numbered-list-ABE.js",
               "bold-AAh.js",
               "set-content-ACW.js",
               "outdent-item-ABI.js",
               "bullet-list-ABC.js",
               "h2-AAv.js",
               "table-add-row-before-ACv.js",
               "h6-ABA.js",
               "delete-table-ACr.js",
               "table-toggle-header-row-ACp.js",
               "clear-headings-AEf.js",
               "unset-font-family-AFU.js",
               "remove-link-ACR.js",
               "blockquote-ABK.js",
               "set-link-ACN.js",
               "h4-AAy.js",
               "code-block-ABN.js"
             ]

      # test "encode" do
      #   Encoder.encode()

      #   dist_path = File.cwd!() |> File.join("dist")
      #   File.ls!(dist_path) |> dbg()
    end
  end
end
