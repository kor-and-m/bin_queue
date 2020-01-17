defmodule BinomialQueue.Bench do
  def run() do
    l = :rand.uniform(1_000_000_000)

    init_list = 1..100_000 |> Enum.map(fn _x -> :rand.uniform(1_000_000_000) end)

    init_binomial =
      1..100_000
      |> Enum.map(fn _x -> {:rand.uniform(1_000_000_000), :rand.uniform(1_000_000_000)} end)
      |> BinomialQueue.from_list()

    Benchee.run(
      %{
        "binomial insert" => fn -> BinomialQueue.insert(init_binomial, l, l) end,
        "list insert" => fn -> [l | init_list] end
      },
      time: 10,
      memory_time: 2
    )

    Benchee.run(
      %{
        "binomial delete" => fn -> BinomialQueue.delete_min(init_binomial) end,
        "list delete" => fn ->
          [_h | t] = Enum.sort(init_list)
          t
        end
      },
      time: 10,
      memory_time: 2
    )

    Benchee.run(
      %{
        "binomial delete insert" => fn ->
          val = BinomialQueue.get_min(init_binomial)
          BinomialQueue.delete_min(init_binomial)
          BinomialQueue.insert(init_binomial, val + 1, val)
        end,
        "binomial update" => fn -> BinomialQueue.update_min(init_binomial, fn x -> x + 1 end) end
      },
      time: 10,
      memory_time: 2
    )
  end
end
