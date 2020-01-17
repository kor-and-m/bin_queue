defmodule BinomialQueue do
  @moduledoc false
  alias BinomialQueue.Node
  import BinomialQueue.Node, only: [queue_node: 1, queue_node: 2]

  defstruct [:queue]

  @type node(t) :: Node.t(t)
  @type queue(t) :: %__MODULE__{queue: [node(t)]}

  @spec new() :: queue(any())
  def new(), do: %__MODULE__{queue: []}

  @spec from_list([{t, any()}]) :: queue(t) when t: any()
  def from_list(l),
    do: Enum.reduce(l, new(), fn {val, order}, queue -> insert(queue, val, order) end)

  @spec update_min(queue(t), (t -> t)) :: queue(t) when t: any()
  def update_min(%__MODULE__{queue: []} = q, _f), do: q

  def update_min(q, f) do
    min = Enum.min_by(q.queue, fn queue_node(order: order) -> order end)
    queue_node(data: min_data) = min
    new_min = queue_node(min, data: f.(min_data))
    [new_min | Enum.filter(q.queue, fn m -> m !== min end)]
  end

  @spec get_min(queue(t)) :: t | nil when t: any()
  def get_min(%__MODULE__{queue: []}), do: nil

  def get_min(queue) do
    queue_node(data: min_data) =
      Enum.min_by(queue.queue, fn queue_node(order: order) -> order end)

    min_data
  end

  @spec insert(queue(t), t, any()) :: queue(t) when t: any
  def insert(queue, elem, order), do: insert_node(queue, Node.new(elem, order))

  @spec delete_min(queue(t)) :: queue(t) when t: any
  def delete_min(%__MODULE__{queue: []} = q), do: q

  def delete_min(queue) do
    data = Enum.min_by(queue.queue, fn queue_node(order: order) -> order end)

    meld_queues(
      %__MODULE__{queue: Enum.filter(queue.queue, fn q -> q !== data end)},
      %__MODULE__{queue: Enum.reverse(queue_node(data, :children))}
    )
  end

  @spec insert_node(queue(t), node(t)) :: queue(t) when t: any()
  defp insert_node(queue, queue_node(rank: rank) = node) do
    case queue.queue do
      [] ->
        %__MODULE__{queue: [node]}

      [queue_node(rank: first_rank) | _] when rank < first_rank ->
        %__MODULE__{queue: [node | queue.queue]}

      [first | tail] ->
        linked = Node.link(first, node)
        insert_node(%__MODULE__{queue: tail}, linked)
    end
  end

  @spec meld_queues(queue(t), queue(t)) :: queue(t) when t: any()
  def meld_queues(%__MODULE__{queue: []}, q2), do: q2
  def meld_queues(q1, %__MODULE__{queue: []}), do: q1

  def meld_queues(
        %__MODULE__{queue: [queue_node(rank: n1_rank) | _]} = q1,
        %__MODULE__{queue: [queue_node(rank: n2_rank) | _]} = q2
      )
      when n1_rank < n2_rank do
    meld_queues(q2, q1)
  end

  def meld_queues(%__MODULE__{queue: [queue_node(rank: n1_rank) | _]} = q1, %__MODULE__{
        queue: [queue_node(rank: n2_rank) = n2 | children]
      })
      when n1_rank > n2_rank do
    %__MODULE__{queue: [n2 | meld_queues(%__MODULE__{queue: children}, q1).queue]}
  end

  def meld_queues(%__MODULE__{queue: [n1 | children_q1]}, %__MODULE__{queue: [n2 | children_q2]}) do
    insert_node(
      meld_queues(%__MODULE__{queue: children_q1}, %__MODULE__{queue: children_q2}),
      Node.link(n1, n2)
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
