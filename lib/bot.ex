defmodule Bot do
  use GenServer

  defstruct [:goal, :pos, :walls, :dir]

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, %Bot{
      goal: {0, 0},
      pos: {0, 0},
      walls: {true, true, true, true},
      dir: :north
    })
  end

  @impl true
  def init(%Bot{} = state) do
    {:ok, _} = :gen_tcp.connect({94, 45, 241, 27}, 4000, [:binary])
    {:ok, state}
  end

  @impl true
  def handle_info({:tcp, port, message}, state) do
    Logger.info("Received: #{message}")
    handle_message(port, message, state)
  end

  defp handle_message(port, <<"motd", _::binary>>, state) do
    Logger.info("Joining")
    username = Application.get_env(:bot, :username)
    password = Application.get_env(:bot, :password)
    :ok = :gen_tcp.send(port, "join|#{username}|#{password}\n")
    :ok = :gen_tcp.send(port, "chat|FOO!\n")
    {:noreply, state}
  end

  defp handle_message(port, <<"pos|", numbers::binary>>, %Bot{dir: dir} = state) do
    {pos, walls} = parse_pos(numbers)
    state = %Bot{state | pos: pos, walls: walls}

    {move, dir} = next_move(dir, walls)
    Logger.info("Dir #{state.dir}")
    state = %Bot{state | dir: dir}
    Logger.info("Moving #{move}")
    :ok = :gen_tcp.send(port, "move|#{move}\n")

    {:noreply, state}
  end

  defp handle_message(_port, <<"goal|", numbers::binary>>, state) do
    [x, y] = numbers |> String.split("|") |> Enum.map(&to_int/1)
    {:noreply, %Bot{state | goal: {x, y}}}
  end

  defp handle_message(_port, msg, state) do
    Logger.info("Unhandled: #{msg}")
    {:noreply, state}
  end

  defp parse_pos(numbers) do
    foo = [x, y, n, e, a, d] = numbers |> String.split("|") |> Enum.map(&to_int/1)
    pos = {x, y}
    walls = {n != 1, e != 1, a != 1, d != 1}
    Logger.warn(foo |> inspect())
    Logger.warn(walls |> inspect())
    {pos, walls}
  end

  defp next_move(:north, {_, true, _, _}), do: {"right", :east}
  defp next_move(:north, {false, _, _, true}), do: {"left", :west}
  defp next_move(:north, {false, _, true, _}), do: {"down", :south}
  defp next_move(:north, _), do: {"up", :north}

  defp next_move(:east, {_, _, true, _}), do: {"down", :south}
  defp next_move(:east, {true, false, _, _}), do: {"up", :north}
  defp next_move(:east, {_, false, _, true}), do: {"left", :west}
  defp next_move(:east, _), do: {"right", :east}

  defp next_move(:south, {_, _, _, true}), do: {"left", :west}
  defp next_move(:south, {_, true, false, _}), do: {"right", :east}
  defp next_move(:south, {true, _, false, _}), do: {"up", :north}
  defp next_move(:south, _), do: {"down", :south}

  defp next_move(:west, {true, _, _, _}), do: {"up", :north}
  defp next_move(:west, {_, _, true, false}), do: {"down", :south}
  defp next_move(:west, {_, true, _, false}), do: {"right", :east}
  defp next_move(:west, _), do: {"left", :west}

  defp to_int(s), do: s |> Integer.parse() |> elem(0)
end
