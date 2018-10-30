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
  def fl, do: flush_log()

  def capture_log do
    start()
    GenServer.call(@name, :capture_log)
  end

  def release_log do
    GenServer.call(@name, :release_log)
  end

  def flush_log do
    GenServer.call(@name, :flush_log)
  end

  def init(:ok) do
    initial_state = %{
      ref: nil,
      string_io: nil,
      contents: nil
    }

    {:ok, initial_state}
  end

  def start(opts \\ []) do
    case start_link(opts) do
      {:ok, _pid} ->
        {:ok, _pid} = Server.start_link(opts)
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

    IO.puts(contents)

    {:reply, :ok, %{state | contents: contents, ref: nil, string_io: nil}}
  end

  def handle_call(:flush_log, _from, %{string_io: string_io} = state) do
    contents = StringIO.flush(string_io)

    IO.puts(contents)

    {:reply, :ok, state}
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
end
