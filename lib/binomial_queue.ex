defmodule BinomialQueue do
  @moduledoc false

  defstruct [:queue]

  @type node(t) :: {t, non_neg_integer(), [node(t)]}
  @type queue(t) :: %__MODULE__{queue: [node(t)]}

  @spec new() :: queue(any())
  def new(), do: %__MODULE__{queue: []}

  @spec from_list([t]) :: queue(t) when t: any()
  def from_list(l), do: Enum.reduce(l, new(), fn val, queue -> insert(queue, val) end)

  @spec get_min(queue(t)) :: t | nil when t: any()
  def get_min(%__MODULE__{queue: []}), do: nil

  def get_min(queue) do
    {min, _, _} = Enum.min_by(queue.queue, fn {min, _, _} -> min end)
    min
  end

  @spec insert(queue(t), t) :: queue(t) when t: any
  def insert(queue, elem), do: insert_node(queue, {elem, 0, []})

  @spec delete_min(queue(t)) :: queue(t) when t: any
  def delete_min(%__MODULE__{queue: []} = q), do: q

  def delete_min(queue) do
    min = Enum.min_by(queue.queue, fn {min, _, _} -> min end)
    {data, _, children} = min

    meld_queues(
      %__MODULE__{queue: Enum.filter(queue.queue, fn {d, _, _} -> d !== data end)},
      %__MODULE__{queue: Enum.reverse(children)}
    )
  end

  @spec link(node(t), node(t)) :: node(t) when t: any()
  defp link(one, other) do
    case {one, other} do
      {{min_one, rank, children}, {min_other, _, _}} when min_one < min_other ->
        {min_one, rank + 1, [other | children]}

      {_, {min_other, rank, children}} ->
        {min_other, rank + 1, [one | children]}
    end
  end

  @spec insert_node(queue(t), node(t)) :: queue(t) when t: any()
  defp insert_node(queue, {_, rank, _} = node) do
    case queue.queue do
      [] ->
        %__MODULE__{queue: [node]}

      [{_, first_rank, _} | _] when rank < first_rank ->
        %__MODULE__{queue: [node | queue.queue]}

      [first | tail] ->
        linked = link(first, node)
        insert_node(%__MODULE__{queue: tail}, linked)
    end
  end

  @spec meld_queues(queue(t), queue(t)) :: queue(t) when t: any()
  defp meld_queues(%__MODULE__{queue: []}, q2), do: q2
  defp meld_queues(q1, %__MODULE__{queue: []}), do: q1

  defp meld_queues(
         %__MODULE__{queue: [{_, rank_q1, _}]} = q1,
         %__MODULE__{queue: [{_, rank_q2, _} | _]} = q2
       )
       when rank_q1 < rank_q2 do
    meld_queues(q2, q1)
  end

  defp meld_queues(%__MODULE__{queue: [{_, rank_q1, _} | _]} = q1, %__MODULE__{
         queue: [{_, rank_q2, _} = n2 | children]
       })
       when rank_q1 > rank_q2 do
    %__MODULE__{queue: [n2 | meld_queues(%__MODULE__{queue: children}, q1).queue]}
  end

  defp meld_queues(%__MODULE__{queue: [n1 | children_q1]}, %__MODULE__{queue: [n2 | children_q2]}) do
    insert_node(
      meld_queues(%__MODULE__{queue: children_q1}, %__MODULE__{queue: children_q2}),
      link(n1, n2)
    )
  end
end

defimpl Enumerable, for: BinomialQueue do
  def count(q), do: {:ok, rec_count(q)}

  defp rec_count(%BinomialQueue{queue: []}), do: 0

  defp rec_count(queue) do
    1 + (queue |> BinomialQueue.delete_min() |> rec_count())
  end

  def member?(%BinomialQueue{queue: []}, _value), do: {:ok, false}

  def member?(q, value) do
    case BinomialQueue.get_min(q) do
      ^value -> {:ok, true}
      _ -> q |> BinomialQueue.delete_min() |> member?(value)
    end
  end

  def slice(q) do
    {:ok, rec_count(q), &Enumerable.List.slice(Enum.to_list(q), &1, &2)}
  end

  def reduce(_, {:halt, acc}, _fun), do: {:halted, acc}
  def reduce(q, {:suspend, acc}, fun), do: {:suspended, acc, &reduce(q, &1, fun)}
  def reduce(%BinomialQueue{queue: []}, {:cont, acc}, _fun), do: {:done, acc}

  def reduce(q, {:cont, acc}, fun) do
    h = BinomialQueue.get_min(q)
    t = BinomialQueue.delete_min(q)
    reduce(t, fun.(h, acc), fun)
  end
end

defmodule BinomialQueue.Bench do
  def run() do
    l =
      1..1_000_000
      |> Enum.map(fn _x -> {:rand.uniform(2), :rand.uniform(1_000_000_000)} end)
      |> Enum.uniq()

    Benchee.run(
      %{
        "binomial" => fn ->
          Enum.reduce(l, BinomialQueue.new(), fn
            {1, v}, q -> BinomialQueue.insert(q, v)
            {2, _}, q -> BinomialQueue.delete_min(q)
          end)
        end,
        "list" => fn ->
          Enum.reduce(l, [], fn
            {1, v}, acc ->
              [v | acc]

            {2, _}, [] ->
              []

            {2, _}, acc ->
              [_h | t] = Enum.sort(acc)
              t
          end)
        end
      },
      time: 10,
      memory_time: 2
    )
  end
end
