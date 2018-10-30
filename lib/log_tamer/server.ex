defmodule LogTamer.Server do
  @name __MODULE__
  @timeout 30000

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  def die(server) do
    Process.send_after(server, :die, 0)
  end

  def log_capture_on(pid) do
    GenServer.call(@name, {:log_capture_on, pid}, @timeout)
  end

  def log_capture_off(ref) do
    GenServer.call(@name, {:log_capture_off, ref}, @timeout)
  end

  def init(:ok) do
    state = %{
      devices: {%{}, %{}},
      log_captures: %{},
      log_status: nil
    }

    {:ok, state}
  end

  def handle_call({:log_capture_on, pid}, _from, config) do
    ref = Process.monitor(pid)
    refs = Map.put(config.log_captures, ref, true)

    if map_size(refs) == 1 do
      status = Logger.remove_backend(:console)
      {:reply, ref, %{config | log_captures: refs, log_status: status}}
    else
      {:reply, ref, %{config | log_captures: refs}}
    end
  end

  def handle_call({:log_capture_off, ref}, _from, config) do
    Process.demonitor(ref, [:flush])
    config = remove_log_capture(ref, config)
    {:reply, :ok, config}
  end

  def handle_info(:die, config) do
    {:stop, :normal, config}
  end

  def handle_info({:DOWN, ref, _, _, _}, config) do
    config = remove_log_capture(ref, config)
    {:noreply, config}
  end

  defp remove_log_capture(ref, %{log_captures: refs} = config) do
    case Map.pop(refs, ref, false) do
      {true, refs} ->
        maybe_add_console(refs, config.log_status)
        %{config | log_captures: refs}

      {false, _refs} ->
        config
    end
  end

  defp maybe_add_console(refs, status) do
    if status == :ok and map_size(refs) == 0 do
      Logger.add_backend(:console, flush: true)
    end
  end
end
