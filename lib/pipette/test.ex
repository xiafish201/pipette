defmodule Pipette.Test do
  @moduledoc """
  This module can be used in a test case and provides convenience functions to
  handle recipes in tests.

  Example

      defmodule FooTest do
        use ExUnit.Case
        use Pipette.Test

        test "recipe should add 1 to the input value" do
          assert run_recipe(AddOne.recipe(), 3) == 4
        end
      end

  """

  defmacro __using__(_) do
    quote do
      import Pipette.Test
    end
  end

  def load_recipe(recipe) do
    Pipette.Test.Controller.start(recipe)
  end

  def push(controller_pid, value) do
    Pipette.Test.Controller.push(controller_pid, value)
  end

  def await(controller_pid, outlet \\ :OUT) do
    Pipette.Test.Controller.await(controller_pid, outlet)
  end

  def await_value(controller_pid, outlet \\ :OUT) do
    %Pipette.IP{value: value} = await(controller_pid, outlet)
    value
  end

  def run_recipe(recipe_or_pid, value, outlet \\ :OUT)

  def run_recipe(%Pipette.Recipe{} = recipe, value, outlet) do
    recipe
    |> load_recipe
    |> run_recipe(value, outlet)
  end

  def run_recipe(pid, value, outlet) when is_pid(pid) do
    pid
    |> push(value)
    |> await_value(outlet)
  end
end