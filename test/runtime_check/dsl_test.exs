defmodule RuntimeCheck.DSLTest do
  use ExUnit.Case, async: true

  import RuntimeCheck.DSL

  alias RuntimeCheck.Check

  defp ok_check do
    send(self(), :ran_check)
    :ok
  end

  defp error_check, do: {:error, "Oops!"}

  defp ok_subcheck1 do
    send(self(), :ran_subcheck1)
    :ok
  end

  defp ok_subcheck2 do
    send(self(), :ran_subcheck2)
    :ok
  end

  describe "check/2" do
    test "with a function succeeds" do
      assert Check.run(check(:a_check, &ok_check/0)) == :ok
      assert_received :ran_check
    end

    test "with a function fails" do
      assert Check.run(check(:a_check, &error_check/0)) == :error
    end

    test "with an exception function fails" do
      assert Check.run(check(:a_check, fn -> raise "Oops!" end)) == :error
    end

    test "with a list of checks succeeds" do
      check =
        check(:a_check, [
          check(:subcheck1, &ok_subcheck1/0),
          check(:subcheck2, &ok_subcheck2/0)
        ])

      assert Check.run(check) == :ok
      assert_received :ran_subcheck1
      assert_received :ran_subcheck2
    end

    test "with a list of checks fails" do
      check =
        check(:a_check, [
          check(:subcheck, &error_check/0),
          check(:subcheck2, &ok_subcheck2/0)
        ])

      assert Check.run(check) == :error
      assert_received :ran_subcheck2
    end
  end

  describe "check/3" do
    test "succeeds" do
      check =
        check(:a_check, &ok_check/0, [
          check(:subcheck1, &ok_subcheck1/0),
          check(:subcheck2, &ok_subcheck2/0)
        ])

      assert Check.run(check) == :ok
      assert_received :ran_check
      assert_received :ran_subcheck1
      assert_received :ran_subcheck2
    end

    test "ignores nested checks" do
      check =
        check(:a_check, fn -> :ignore end, [
          check(:subcheck1, &ok_subcheck1/0),
          check(:subcheck2, &ok_subcheck2/0)
        ])

      assert Check.run(check) == :ok
      refute_received :ran_subcheck1
      refute_received :ran_subcheck2
    end

    test "with an error ignores nested checks" do
      check =
        check(:a_check, &error_check/0, [
          check(:subcheck1, &ok_subcheck1/0),
          check(:subcheck2, &ok_subcheck2/0)
        ])

      assert Check.run(check) == :error
      refute_received :ran_subcheck1
      refute_received :ran_subcheck2
    end

    test "fails" do
      check =
        check(:a_check, &ok_check/0, [
          check(:subcheck1, &ok_subcheck1/0),
          check(:subcheck2, &error_check/0)
        ])

      assert Check.run(check) == :error
      assert_received :ran_check
      assert_received :ran_subcheck1
    end
  end

  describe "feature_check/2" do
    setup do
      FunWithFlags.enable(:enabled_flag)
      :ok
    end

    test "with a function succeeds" do
      check = feature_check(:enabled_flag, &ok_check/0)

      assert Check.run(check) == :ok
      assert_received :ran_check
    end

    test "with a function fails" do
      check = feature_check(:enabled_flag, &error_check/0)

      assert Check.run(check) == :error
    end

    test "with a function and a disabled flag ignores the check" do
      check = feature_check(:disabled_flag, &ok_check/0)

      assert Check.run(check) == :ok
      refute_received :ran_check
    end

    test "with an error function and a disabled flag ignores the check" do
      check = feature_check(:disabled_flag, &error_check/0)

      assert Check.run(check) == :ok
    end

    test "with a list of checks succeeds" do
      check =
        feature_check(:enabled_flag, [
          check(:subcheck1, &ok_subcheck1/0),
          check(:subcheck2, &ok_subcheck2/0)
        ])

      assert Check.run(check) == :ok
      assert_received :ran_subcheck1
      assert_received :ran_subcheck2
    end

    test "with a list of checks fails" do
      check =
        feature_check(:enabled_flag, [
          check(:subcheck, &error_check/0),
          check(:subcheck2, &ok_subcheck2/0)
        ])

      assert Check.run(check) == :error
      assert_received :ran_subcheck2
    end

    test "with a disabled flag ignores nested checks" do
      check =
        feature_check(:disabled_flag, [
          check(:subcheck1, &ok_subcheck1/0),
          check(:subcheck2, &ok_subcheck2/0)
        ])

      assert Check.run(check) == :ok
      refute_received :ran_subcheck1
      refute_received :ran_subcheck2
    end

    test "runs when the flag is enabled for any gate" do
      actor = %RuntimeCheck.FlagActor{id: 1}
      FunWithFlags.enable(:enabled_flag_by_actor, for_actor: actor)

      check = feature_check(:enabled_flag_by_actor, &ok_check/0)

      assert Check.run(check) == :ok
      assert_received :ran_check
    end
  end

  describe "feature_check/3" do
    setup do
      FunWithFlags.enable(:enabled_flag)
      :ok
    end

    test "succeeds" do
      check =
        feature_check(:enabled_flag, &ok_check/0, [
          check(:subcheck1, &ok_subcheck1/0),
          check(:subcheck2, &ok_subcheck2/0)
        ])

      assert Check.run(check) == :ok
      assert_received :ran_check
      assert_received :ran_subcheck1
      assert_received :ran_subcheck2
    end

    test "with a disabled flag ignores the check and nested checks" do
      check =
        feature_check(:disabled_flag, &ok_check/0, [
          check(:subcheck1, &ok_subcheck1/0),
          check(:subcheck2, &ok_subcheck2/0)
        ])

      assert Check.run(check) == :ok
      refute_received :ran_check
      refute_received :ran_subcheck1
      refute_received :ran_subcheck2
    end

    test "ignores nested checks" do
      check =
        feature_check(:enabled_flag, fn -> :ignore end, [
          check(:subcheck1, &ok_subcheck1/0),
          check(:subcheck2, &ok_subcheck2/0)
        ])

      assert Check.run(check) == :ok
      refute_received :ran_subcheck1
      refute_received :ran_subcheck2
    end
  end

  describe "env_var/2" do
    setup do
      System.put_env("EXISTING_VAR", "123")
      System.put_env("EMPTY_VAR", "")
    end

    test "succeeds when the var exists" do
      assert Check.run(env_var("EXISTING_VAR")) == :ok
    end

    test "fails when the var doesn't exist" do
      assert Check.run(env_var("NON_EXISTENT_VAR")) == :error
    end

    test "fails when the var is empty" do
      assert Check.run(env_var("EMPTY_VAR")) == :error
    end

    test "succeeds when the var is empty and allow_empty is true" do
      assert Check.run(env_var("EMPTY_VAR", allow_empty: true)) == :ok
    end
  end

  describe "app_var/3" do
    setup do
      Application.put_env(:runtime_check, :existing_key, "value")
      Application.put_env(:runtime_check, :keys, subkey: :subvalue)
      Application.put_env(:runtime_check, :empty_key, "")
      Application.put_env(:runtime_check, :empty_key_path, key: "")
      Application.put_env(:runtime_check, :nil_key, nil)
      Application.put_env(:runtime_check, :nil_key_path, key: nil)

      :ok
    end

    test "succeeds when the key exists" do
      assert Check.run(app_var(:a_check, :runtime_check, :existing_key)) == :ok
    end

    test "succeeds when the keys exist" do
      assert Check.run(app_var(:a_check, :runtime_check, [:keys, :subkey])) == :ok
    end

    test "succeeds when the value is empty" do
      assert Check.run(app_var(:a_check, :runtime_check, :empty_key)) == :ok
    end

    test "succeeds when the value is empty with keys" do
      assert Check.run(app_var(:a_check, :runtime_check, [:empty_key_path, :key])) == :ok
    end

    test "fails when the key is missing" do
      assert Check.run(app_var(:a_check, :runtime_check, :missing_key)) == :error
    end

    test "fails when the value is nil" do
      assert Check.run(app_var(:a_check, :runtime_check, :nil_key)) == :error
    end

    test "fails when the key path is missing" do
      assert Check.run(app_var(:a_check, :runtime_check, [:keys, :not_a_key, :no])) == :error
    end

    test "fails when the key path is nil" do
      assert Check.run(app_var(:a_check, :runtime_check, [:nil_key_path, :key])) == :error
    end

    test "fails when the value is empty and it's rejected" do
      assert Check.run(app_var(:a_check, :runtime_check, :empty_key, reject: [""])) == :error
    end

    test "fails when the value is empty with keys and it's rejected" do
      assert Check.run(app_var(:a_check, :runtime_check, [:empty_key_path, :key], reject: [""])) ==
               :error
    end
  end
end
