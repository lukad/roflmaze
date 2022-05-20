defmodule Bot do
  use GenServer

  defstruct [:goal, :pos, :walls, :dir]

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, %Bot{
      goal: {0, 0},
      pos: {0, 0},
      walls: {true, true, true, true},
      dir: "up"
    })
  end

  @impl true
  def init(%Bot{} = state) do
    {:ok, _} = :gen_tcp.connect({94, 45, 241, 27}, 4000, [:binary])
    {:ok, state}
  end

  @impl true
  def handle_info({:tcp, port, message}, state) do
    Logger.info("Received: #{message}" |> String.trim_trailing())
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

    new_dir = next_move(dir, walls)
    state = %Bot{state | pos: pos, dir: new_dir, walls: walls}
    Logger.info("Moving #{new_dir}")
    :ok = :gen_tcp.send(port, "move|#{new_dir}\n")

    {:noreply, state}
  end

  defp handle_message(_port, <<"goal|", numbers::binary>>, state) do
    [x, y] = numbers |> String.split("|") |> Enum.map(&to_int/1)
    {:noreply, %Bot{state | goal: {x, y}}}
  end

  defp parse_pos(numbers) do
    [x, y, n, e, a, d] = numbers |> String.split("|") |> Enum.map(&to_int/1)
    pos = {x, y}
    walls = {n != 1, e != 1, a != 1, d != 1}
    {pos, walls}
  end

  defp next_move("up", {_, _, _, true}), do: "left"
  defp next_move("up", {false, true, _, _}), do: "right"
  defp next_move("up", {false, _, true, _}), do: "down"
  defp next_move("up", _), do: "up"

  defp next_move("right", {true, _, _, _}), do: "up"
  defp next_move("right", {_, false, true, _}), do: "down"
  defp next_move("right", {_, false, _, true}), do: "left"
  defp next_move("right", _), do: "right"

  defp next_move("down", {_, true, _, _}), do: "right"
  defp next_move("down", {_, _, false, true}), do: "left"
  defp next_move("down", {true, _, false, _}), do: "up"
  defp next_move("down", _), do: "down"

  defp next_move("left", {_, _, true, _}), do: "down"
  defp next_move("left", {true, _, _, false}), do: "up"
  defp next_move("left", {_, true, _, false}), do: "right"
  defp next_move("left", _), do: "left"

  defp to_int(s), do: s |> Integer.parse() |> elem(0)
end
