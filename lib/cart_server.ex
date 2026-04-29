defmodule CartServer do
  use GenServer

  # step 1 
  
  # Adding "use GenServer" is all it takes.   -- It injects all 8
  # callbacks with their default implementations

  # The init/1 callback runs on startup. Sets the initial state
  # {:ok, state}
  # Runs once on startup. Sets the initial state.


  # step 2 -----------------------------------------------------------------

  # ---- Client API ------
  def start_link(_opts) do 
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    # The third argument name: __MODULE__ registers the process globally as CartServer. This
    # means you never need to pass a PID around. -- just use the module name.
  end
   #iex -S mix

   # iex> CartServer.start_link([])
   #{:ok, #PID<0.110.0>}

   # iex> GenServer.whereis(CartServer)
   # #PID<0.110.0>                   # confirmed: registered by name

   #iex> :sys.get_state(CartServer)
   # %{}                              # our initial state (empty map)

   #Always use start_link — not start. It links the 
   #GenServer to its caller so a supervisor can detect crashes and restart the process.

   # -------------------------------------------------------------------------------------
   # step 3

   # @impl true tells the compiler this is an intentional callback override
   # not just a function with a matching name by accident
   # We do this because Genserver has 8 methods we need to implement and init is one of them
   @impl true
   def init(_args) do 
     {:ok,              %{cart: [],timer_pid: nil}}
     # always :ok,      # ^this is our state defined by the map
   end

   # init return tuples 
   # RETURN TUPLE 		WHAT HAPPENS
   #{:ok, state} 		Normal start. State is stored. Genserver is ready
   #{:ok, state, timeout} 	Start nornally, but call handle_info(:timeout, state) if no message
   # 				arrives within N ms
   #{:stop, reason}		Refuse to start. Supervisor will react and may restart 
   #:ignore



   #step 4
   #---------------- handle_call/3 -----------------------------------------------------
     

   #----client api ---->
   def cart_total(), do: GenServer.call(__MODULE__, :total)
   
   #handle_call/3 --synchronous messages 
   #Use when the caller needs a value back. Like a parking ticket machine. 
   #You press the button and wait for the ticket. 
   #handle_call takes 3 arguments: The message, the sender info (usually ignored), and the current
   #state. It must reply - the caller is blocking
 
   #---- call back ---->  
   @impl true
   def handle_call(:total, _from, state) do 
     total = 
       state.cart
          |> Enum.reduce(0, fn item, acc -> 
            acc + item.price * item.qty 
         end)

     {:reply, total, state} # send back total and always send back state
    end

    # In Elixir, a handle_call is synchronous by default. 
    # The Caller (the process that sent the message) is physically stuck waiting for a response.
    # Normally, you return {:reply, response, new_state}, 
    # and the GenServer sends the response immediately. However, 
    # When you return {:noreply, state}, you are telling the GenServer: 
    # "I'm done with the work for now, but do NOT send a response to the caller yet. Let them keep waiting."
    
    #handle_call return tuples:
    #Return tuple		        What happens
    #{:reply, result, state}		Send result back to caller, update state. Normal case.
    #{:reply, result, state, timeout}	Same, but triggers handle_info(:timeout) if idle after N ms.
    #{:noreply, state}			Caller keeps blocking. You must call GenServer.reply(from, val) later.
    #{:stop, reason, reply, state}	Send the reply, then shut down the GenServer.
    # NOTE: -->
    # Always pass state at the end — even if you didn't change it. 
    # The GenServer needs it to carry forward to the next message.
  
    #iex> CartServer.start_link([])
    #iex> CartServer.cart_total()
 

    # step 5
    #----------------- handle_cast/2 ---------------------------------

    #handle_cast/2 -- asynchronous messages
    #Use when the caller does not neet a result. Like a radio broadcast - you send, the receive, no 
    #confirmation 

    #handle_cast/2 takes 2 arguments: the message and the current state. No sender - there is nobody 
    #waiting for the reply

    #----- client api ----------------------------------------    
    def add_item(item), do: GenServer.cast(__MODULE__, {:add_item, ite})
    #--- callbacks --->
    @impl true
    def handle_cast({:add_item, item}, state) do 
      new_state = %{state | cart: [item | state.cart]}
      #prepend item to front of cart list 
      {:noreply, new_state} 
    end
    #iex> CartServer.add_item(%{name: "apple", price: 1.99, qty: 3})
    #:ok # just :ok — no value sent back

    #iex> CartServer.cart_total()
    #5.97 # 1.99 × 3 ✓

    #iex> CartServer.add_item(%{name: "pear", price: 2.33, qty: 2})
    #iex> CartServer.cart_total()
    #10.63
 
    #handle_cast return tuples
    #Return tuple		        What happens
    #{:noreply, state}			Update state, keep running. This is the standard return.
    #{:noreply, state, timeout}		Same, but triggers handle_info(:timeout) if idle after N ms.
    #{:stop, reason, state}		Update state, then shut down the GenServer.
    #Pattern-match in the message tuple — {:add_item, item} — 
    #so one GenServer can handle many different cast messages cleanly. 
    #Add more handle_cast clauses as needed.

    # Step 6   
    #----------------------  handle_info/2 - timers and everything else

    # handle_info/2 
    # Handles any message not sent via call or cast - including timer messages from Process.send_after.
    # Without a handle_info, unexpected messages log a warning. Let's use it to send an abandoned-cart
    # reminder 10 seconds after an item is added. 
   
    # In handle_cast - start a timer after adding an item
   
    # we redefine the handle_cast method. 
    @impl true
    def handle_cast({:add_item, item}, state) do 
      new_state = %{state | cart: [item | state.card]}
   
      Process.send_after(self(), :reminder, 10_000)  #<----- added this
     
      {:noreply, new_state}
    end 

     
    #handle_info receives the :reminder message 10s later
    
    @impl true
    def handle_info(:reminder, state) do 
      IO.puts("Don't forget about those items!!")
      {:noreply, state}
    end
    
    #Problem: adding 3 items fires 3 reminders. We only want one. 
    # We need to cancel the previous timer each time a new item is added — solved on the next step.
    # handle_info return tuples
    # Return tuple		 What happens
    # {:noreply, state}		 Handle the message, update state, keep running. Normal case.
    # {:noreply, state, timeout} Same, plus arm an idle timeout.
    # {:stop, reason, state}	 Handle the message, then shut down.



    #step 7 
    #-------------------------------- Fixing the reminder 
    #Store the timer PID in state. Cancel it before starting a new one. One reminder, no matter how 
    #many items are added.

    #We already have timer_pid: nil in our state from init. Now we write a private helper that checks
    #wheather a timer is already running and cancels it before starting a fresh one.

    
    #-----------client api--------------------------------------------
    

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  def add_item(item),    do: GenServer.cast(__MODULE__, {:add_item, item})
  def cart_total(),      do: GenServer.call(__MODULE__, :total)

  # ── Callbacks ─────────────────────────────────────

  @impl true
  def init(_args) do
    {:ok, %{cart: [], timer_pid: nil}}
  end

  @impl true
  def handle_call(:total, _from, state) do
    total = Enum.reduce(state.cart, 0, fn i, acc -> acc + i.price * i.qty end)
    {:reply, total, state}
  end

  @impl true
  def handle_cast({:add_item, item}, state) do
    new_state =
      %{state | cart: [item | state.cart]}
      |> reset_reminder()     # pipe updated state into helper
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:reminder, state) do
    IO.puts("Don't forget about those items!")
    {:noreply, %{state | timer_pid: nil}}
  end

  # ── Private helpers ───────────────────────────────

  defp reset_reminder(state) do
    if state.timer_pid, do: Process.cancel_timer(state.timer_pid)
    timer_pid = Process.send_after(self(), :reminder, 10_000)
    %{state | timer_pid: timer_pid}
  end
   
	#iex> CartServer.start_link([])
	#iex> CartServer.add_item(%{name: "orange", price: 2.53, qty: 2})
	#iex> CartServer.add_item(%{name: "orange", price: 2.53, qty: 2})
	#iex> CartServer.add_item(%{name: "orange", price: 2.53, qty: 2})

    # Process.cancel_timer takes the timer reference returned by send_after. 
    # Storing it in state is the standard pattern for cancellable timers.

end   


















end
