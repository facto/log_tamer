defmodule LogTamer do
  @name __MODULE__

  use GenServer

  alias Logger.Backends.Console

  alias LogTamer.Server

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  def cl, do: capture_log()
  def rl, do: release_log()
  def fl(opts \\ []), do: flush_log(opts)

  def capture_log do
    start()
    GenServer.call(@name, :capture_log)
  end

  def release_log do
    case GenServer.whereis(@name) do
      nil ->
        {:error, :not_started}
      pid when is_pid(pid) ->
        GenServer.call(@name, :release_log)
    end
  end

  def flush_log(opts \\ []) do
    case GenServer.whereis(@name) do
      nil ->
        {:error, :not_started}
      pid when is_pid(pid) ->
        GenServer.call(@name, {:flush_log, opts})
    end
  end

  def init(:ok) do
    {:ok, server_pid} = Server.start_link()

    initial_state = %{
      ref: nil,
      string_io: nil,
      contents: "",
      server_pid: server_pid
    }

    {:ok, initial_state}
  end

  def start(opts \\ []) do
    case start_link(opts) do
      {:ok, _pid} ->
        :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  def handle_call(:capture_log, _from, state) do
    # opts = Keyword.put_new(opts, :level, nil)
    {:ok, string_io} = StringIO.open("")

    _ = Process.whereis(:error_logger) && :gen_event.which_handlers(:error_logger)
    :ok = add_capture(string_io)
    ref = Server.log_capture_on(self())

    {:reply, :ok, %{state | ref: ref, string_io: string_io}}
  end


  def handle_call(:release_log, _from, %{ref: ref, string_io: string_io} = state) do
    contents = try do
                 :ok = Logger.flush()
                 :ok = Server.log_capture_off(ref)
                 :ok = remove_capture(string_io)
               catch
                 _kind, _reason ->
                   _ = StringIO.close(string_io)
                   # :erlang.raise(kind, reason, __STACKTRACE__)
               else
                 :ok ->
                   {:ok, content} = StringIO.close(string_io)
                   elem(content, 1)
               end

    output(contents)

    Process.send_after(self(), :die, 0)

    {:reply, :ok, %{state | contents: contents, ref: nil, string_io: nil}}
  end

  def handle_call({:flush_log, opts}, _from, %{contents: contents, string_io: string_io} = state) do
    new_contents = StringIO.flush(string_io)
    contents = contents <> new_contents

    {to_use, remainder} = calc_output(contents, opts)

    output(to_use)

    {:reply, :ok, %{state | contents: remainder}}
  end

  def handle_info(:die, state) do
    {:stop, :normal, state}
  end

  def init_proxy(pid, parent) do
    case :gen_event.add_sup_handler(Logger, {Console, pid}, {Console, [device: pid]}) do
      :ok ->
        ref = Process.monitor(parent)
        :proc_lib.init_ack(:ok)

        receive do
          {:DOWN, ^ref, :process, ^parent, _reason} -> :ok
          {:gen_event_EXIT, {Console, ^pid}, _reason} -> :ok
        end

      {:EXIT, reason} ->
        :proc_lib.init_ack({:error, reason})

      {:error, reason} ->
        :proc_lib.init_ack({:error, reason})
    end
  catch
    :exit, :noproc -> :proc_lib.init_ack(:noproc)
  end

  def terminate(_, %{server_pid: server_pid}) do
    Server.die(server_pid)
  end

  # PRIVATE ##################################################

  defp add_capture(pid) do
    case :proc_lib.start(__MODULE__, :init_proxy, [pid, self()]) do
      :ok ->
        :ok

      :noproc ->
        raise "cannot capture_log/2 because the :logger application was not started"

      {:error, reason} ->
        mfa = {__MODULE__, :add_capture, [pid]}
        exit({reason, mfa})
    end
  end

  defp remove_capture(pid) do
    case :gen_event.delete_handler(Logger, {Console, pid}, :ok) do
      :ok ->
        :ok

      {:error, :module_not_found} = error ->
        mfa = {__MODULE__, :remove_capture, [pid]}
        exit({error, mfa})
    end
  end

  defp calc_output(contents, opts) do
    case Keyword.get(opts, :limit, :infinity) do
      :infinity ->
        {contents, ""}
      limit ->
        newline = detect_newline(contents)
        lines = String.split(contents, newline)
        {to_use, remainder} = Enum.split(lines, limit)
        {Enum.join(to_use, newline), Enum.join(remainder, newline)}
    end
  end

  defp detect_newline(contents) do
    cond do
      Regex.match?(~r/\r\n/, contents) -> "\r\n"
      Regex.match?(~r/\r/, contents) -> "\r"
      Regex.match?(~r/\n/, contents) -> "\n"
      true -> ""
    end
  end

  defp output(contents) do
    IO.write(contents)
  end
end
