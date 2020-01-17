defmodule BinomialQueue.Node do
  @moduledoc false

  require Record

  Record.defrecord(:queue_node, [:order, :data, :rank, :children])

  #   defstruct [:order, :data, :rank, :children]

  @type t(data_type) ::
          record(
            :queue_node,
            order: any(),
            data: data_type,
            rank: non_neg_integer(),
            children: [t(data_type)]
          )

  @spec new(elem, any()) :: t(elem) when elem: any()
  def new(elem, order) do
    queue_node(
      order: order,
      data: elem,
      rank: 0,
      children: []
    )
  end

  @spec link(t(data_type), t(data_type)) :: t(data_type) when data_type: any()
  def link(one, other) do
    case {one, other} do
      {queue_node(order: min_one), queue_node(order: min_other)} when min_one < min_other ->
        queue_node(one,
          rank: queue_node(one, :rank) + 1,
          children: [other | queue_node(one, :children)]
        )

      _ ->
        queue_node(other,
          rank: queue_node(other, :rank) + 1,
          children: [one | queue_node(other, :children)]
        )
    end
  end
end
