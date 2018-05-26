defmodule Flow.BlockTest do
  use ExUnit.Case

  alias Flow.Pattern
  alias Flow.Block
  alias Flow.IP

  test "real world example (requires internet connection)" do
    pattern = NYCBikeShares.data
              |> Pattern.start
              |> Pattern.establish

    {:ok, pid} = Pattern.get_stage(pattern, :filter)
    assert [
      %IP{value: [_station]}
    ] = GenStage.stream([pid], max_demand: 1)
        |> Enum.take(1)

    {:ok, pid} = Pattern.get_stage(pattern, :station_count)
    assert [
      %IP{value: _count}
    ] = GenStage.stream([pid], max_demand: 1)
        |> Enum.take(1)
  end

  test "hey, we could do routing this these" do
    pattern = %Pattern{
      blocks: [
        %Block{id: :generator, type: :producer, stream: Stream.iterate(%IP{value: 1}, &(%IP{&1 | value: &1.value + 1}))},
        %Block{id: :divide_and_conquer, fun: fn
          n when rem(n, 2) == 0 -> {:even, n}
          n when rem(n, 2) != 0 -> {:odd, n}
        end},
        %Block{id: :make_even, fun: &({:even, &1 + 1})},
        %Block{id: :pass_even, fun: &({:even, &1})}
      ],
      connections: [
        {:divide_and_conquer, :generator},
        {:make_even, {:divide_and_conquer, :odd}},
        {:pass_even, {:divide_and_conquer, :even}}
      ]
    }
    |> Pattern.start
    |> Pattern.establish

    {:ok, stage_1} = Pattern.get_stage(pattern, :make_even)
    {:ok, stage_2} = Pattern.get_stage(pattern, :pass_even)

    assert [
      2, 2, 4, 4, 6, 6, 8, 8, 10, 10
    ] == GenStage.stream([{stage_1, max_demand: 1}, {stage_2, max_demand: 1}])
         |> Enum.take(10)
         |> Enum.map(&(&1.value))
  end

  test "and with routing comes neat error handling" do
    pattern = %Pattern{
      blocks: [
        %Block{id: :generator, type: :producer, stream: Stream.cycle([5, 4, 3, 0, 2, 1]) |> Stream.map(&(%IP{value: &1}))},
        %Block{id: :at_fault, fun: &(1 / &1)}
      ],
      connections: [
        {:at_fault, :generator}
      ]
    }
    |> Pattern.start
    |> Pattern.establish

    {:ok, stage} = Pattern.get_stage(pattern, :at_fault)

    results = GenStage.stream([{stage, selector: &(&1.route == :ok), max_demand: 1}])
    |> Enum.take(5)
    |> Enum.map(&(&1.value))

    errors = GenStage.stream([{stage, selector: &(&1.route == :error), max_demand: 1}])
    |> Enum.take(1)

    assert [0.2, 0.25, 1/3, 0.5, 1.0] == results
    assert [
      %IP{
        value: 0,
        is_error: true,
        error: %{message: "bad argument in arithmetic expression"}
      }
    ] = errors
  end
end

