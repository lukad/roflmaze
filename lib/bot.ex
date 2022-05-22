defmodule Bot do
  use GenServer

  require Logger

  defmodule State do
    defstruct goal: {0, 0},
              pos: {0, 0},
              walls: {false, false, false, false},
              visited: MapSet.new(),
              moves: [],
              backtracking: false
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %State{})
  end

  @impl true
  def init(%State{} = state) do
    host = Application.get_env(:bot, :host) |> to_charlist()
    {port, _} = Application.get_env(:bot, :port) |> Integer.parse()
    {:ok, _} = :gen_tcp.connect(host, port, [:binary, :inet6])
    {:ok, state}
  end

  @impl true
  def handle_info({:tcp, port, message}, state) do
    Logger.info("Received: #{message |> inspect()}" |> String.trim_trailing())

    state =
      message
      |> String.split("\n", trim: true)
      |> Enum.reduce(state, fn msg, acc -> handle_message(port, msg, acc) end)

    {:noreply, state}
  end

  defp handle_message(port, <<"motd", _::binary>>, state) do
    Logger.info("Joining")
    username = Application.get_env(:bot, :username)
    password = Application.get_env(:bot, :password)
    :ok = :gen_tcp.send(port, "join|#{username}|#{password}\n")
    :ok = :gen_tcp.send(port, "chat|FOO!\n")
    state
  end

  defp handle_message(_, <<"game", _::binary>>, state), do: state

  defp handle_message(_, <<"win", _::binary>>, _state), do: %State{}
  defp handle_message(_, <<"lose", _::binary>>, _state), do: %State{}

  defp handle_message(port, <<"pos|", numbers::binary>>, %State{visited: visited} = state) do
    {pos, walls} = parse_pos(numbers)

    visited = MapSet.put(visited, pos)
    state = %State{state | pos: pos, walls: walls, visited: visited}

    move = state |> possible_moves() |> next_move()
    {state, move} = state |> do_move(move)

    Logger.info(state |> inspect())

    Logger.info("Moving #{move}")
    :ok = :gen_tcp.send(port, "move|#{move}\n")

    state
  end

  defp handle_message(_port, <<"goal|", numbers::binary>>, state) do
    [x, y] = numbers |> String.split("|") |> Enum.map(&to_int/1)
    %State{state | goal: {x, y}}
  end

  defp do_move(%State{moves: moves} = state, {:ok, move}) do
    {%State{state | moves: [move | moves]}, move}
  end

  defp do_move(%State{moves: [move | rest]} = state, {:error, :stuck}) do
    {%State{state | backtracking: true, moves: rest}, opposite_move(move)}
  end

  defp opposite_move("up"), do: "down"
  defp opposite_move("right"), do: "left"
  defp opposite_move("down"), do: "up"
  defp opposite_move("left"), do: "right"

  defp parse_pos(numbers) do
    [x, y, n, e, s, w] = numbers |> String.split("|") |> Enum.map(&to_int/1)
    pos = {x, y}
    walls = {n != 1, e != 1, s != 1, w != 1}
    {pos, walls}
  end

  @spec next_move(list()) :: {:ok, binary()} | {:error, atom()}
  defp next_move([]), do: {:error, :stuck}
  defp next_move([x | _]), do: {:ok, x}

  @spec possible_moves(%State{}) :: list(binary())
  defp possible_moves(%{
         pos: {x, y},
         goal: goal,
         walls: {north, east, south, west},
         visited: visited
       }) do
    [
      {{x - 1, y}, west, "left"},
      {{x, y - 1}, north, "up"},
      {{x + 1, y}, east, "right"},
      {{x, y + 1}, south, "down"}
    ]
    |> Enum.filter(&elem(&1, 1))
    |> Enum.sort_by(fn {p, _, _} -> distance_squared(p, goal) end)
    |> Enum.reject(fn {p, _, _} -> MapSet.member?(visited, p) end)
    |> Enum.map(&elem(&1, 2))
  end

  defp to_int(s), do: s |> Integer.parse() |> elem(0)

  defp distance_squared({x1, y1}, {x2, y2}) do
    dx = x1 - x2
    dy = y1 - y2
    dx * dx + dy * dy
  end
end
