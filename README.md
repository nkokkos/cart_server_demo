# CartServer

I wanted to learn GenServer concepts really fast.

Watched this video and asked AI to devise a plan to learn:

**Elixir Full Course 39 - GenServer**
https://www.youtube.com/watch?v=a36lzSfzx8U

Most of it is a guided slop of AI generated stuff about GenServer. But I cleared most of it to get the gist using claude....  :-)

---

## Return Tuple Quick Reference

Every callback must end with one of these tuples. OTP reads it and decides what to do next.

### `init/1`

| Tuple | Meaning |
|---|---|
| `{:ok, state}` | Start with this state. |
| `{:ok, state, timeout}` | Start, fire `handle_info(:timeout)` after N ms of silence. |
| `{:stop, reason}` | Refuse to start. Supervisor reacts. |
| `:ignore` | Don't start. Supervisor does **not** restart. |

### `handle_call/3`

| Tuple | Meaning |
|---|---|
| `{:reply, result, state}` | Send result to caller, update state. Most common. |
| `{:noreply, state}` | Caller waits. You must call `GenServer.reply(from, val)` later. |
| `{:stop, reason, reply, state}` | Reply first, then shut down. |

### `handle_cast/2` and `handle_info/2`

| Tuple | Meaning |
|---|---|
| `{:noreply, state}` | Update state, keep running. The standard return. |
| `{:noreply, state, timeout}` | Same, plus arm an idle timeout. |
| `{:stop, reason, state}` | Update state, then shut down. |

### `:stop` Reasons

| Reason | Supervisor behaviour |
|---|---|
| `:normal` | Clean exit. Supervisor does **not** restart. |
| `:shutdown` | Orderly shutdown signal. Not restarted. |
| anything else | Treated as a crash. Supervisor **will** restart. |

> Use `:normal` when you deliberately stop a GenServer (e.g. a shutdown call).
> Use any other atom (like `:bad_state`) to signal a real crash and trigger the supervisor's restart logic.

---

## Plan to Learn GenServer

### Phase 1 — Conceptual Foundation

Before writing code, it is essential to understand why GenServers exist and their role in the Elixir ecosystem.

- **Understand State and Immutability** — Learn how GenServer allows you to safely share and modify data across processes in an immutable language.
- **The GenServer Behaviour** — Recognize that a GenServer is a behaviour (similar to an interface) included in the OTP libraries for writing stateful server processes.
- **Process Architecture** — Grasp the distinction between the calling process (which executes client functions) and the GenServer process (which owns the data and executes callbacks).

### Phase 2 — Basic Setup and Initialization

Start by building a simple module to get familiar with the boilerplate and lifecycle.

- **Create a Project** — Use `mix new` to start a new project (e.g. a "shopping cart" server).
- **Implement the Behaviour** — Use the `use GenServer` macro to adopt the behaviour in your module.
- **Start the Process** — Learn to use `GenServer.start_link/3`. This involves specifying the module, the initial state, and optionally a name (atom) for the process.
- **The `init` Callback** — Implement `init/1` to set up the initial state and perform any necessary startup logic.

### Phase 3 — Mastering Communication Patterns

GenServer communication is primarily handled through three core callbacks. Understanding the difference between them is critical.

- **Synchronous Calls (`handle_call`)** — Use this when you need a reply from the server (e.g. getting the total price of a cart). It blocks the caller until the response is received.
- **Asynchronous Casts (`handle_cast`)** — Use this for "fire and forget" messages where no response is needed (e.g. adding an item to a cart).
- **Generic Messages (`handle_info`)** — Use this to handle messages sent to the process that are not standard calls or casts, such as system notifications or timers.

### Phase 4 — Best Practices in Design

Refine your code by following idiomatic Elixir patterns to ensure maintainability.

- **Client vs. Server Separation** — Structure your module into two sections: client-facing functions (API for other modules) and callback functions (internal GenServer logic).
- **Encapsulation** — Keep implementation details (like the GenServer name or specific message formats) hidden within the module so external code just calls standard functions.
- **The `@impl true` Annotation** — Use this before callbacks to let the compiler and other developers know you are overriding behaviour functions.

### Phase 5 — Advanced State and Reliability

Once basics are covered, explore more complex scenarios involving time and performance.

- **Introspection** — Practice using `:sys.get_state` and `GenServer.whereis` in the IEx shell to inspect your running process and its state.
- **Managing Timers** — Implement delayed logic using `Process.send_after/3`. Learn to manage these timers by storing their process IDs (PIDs) in your state and using `Process.cancel_timer/1` to prevent duplicate or stale messages.
- **Performance Awareness** — Understand that because a single GenServer process handles messages one at a time, it can become a bottleneck under extremely high load.

### Phase 6 — Practical Projects

To solidify your learning, build a **Shopping Cart Server** with the following features:

- **Add Item** — An asynchronous cast that prepends a map `(name, price, quantity)` to a list in the state.
- **Calculate Total** — A synchronous call that iterates through the cart state to sum prices multiplied by quantities.
- **Abandonment Reminders** — Use `handle_info` and timers to print a message if the user doesn't interact with the cart for a set duration.

---

> Once you are comfortable with these steps, you can move on to learning about **Supervisors**,
> which are used to start, monitor, and restart GenServer processes automatically.

---

## Final Code

```elixir
defmodule CartServer do
  use GenServer

  # ── Client API ────────────────────────────────────

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
      |> reset_reminder()
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

end
```

---

## Step-by-step Notes

### Step 1 — `use GenServer`

`use GenServer` injects all 8 callbacks with their default implementations. That's all it takes to get started.

---

### Step 2 — `start_link` and process registration

```elixir
def start_link(_opts) do
  GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
end
```

The `name: __MODULE__` option registers the process globally as `CartServer`. You never need to pass a PID around — just use the module name.

> Always use `start_link`, not `start`. It links the GenServer to its caller so a supervisor can detect crashes and restart the process.

```elixir
iex> CartServer.start_link([])
{:ok, #PID<0.110.0>}

iex> GenServer.whereis(CartServer)
#PID<0.110.0>    # confirmed: registered by name

iex> :sys.get_state(CartServer)
%{}              # initial state (empty map)
```

---

### Step 3 — `init/1`

```elixir
@impl true
def init(_args) do
  {:ok, %{cart: [], timer_pid: nil}}
end
```

`@impl true` tells the compiler this is an intentional callback override, not just a function with a matching name by accident. `init/1` runs once on startup and sets the initial state.

| Return tuple | What happens |
|---|---|
| `{:ok, state}` | Normal start. State is stored. GenServer is ready. |
| `{:ok, state, timeout}` | Start normally, but call `handle_info(:timeout, state)` if no message arrives within N ms. |
| `{:stop, reason}` | Refuse to start. Supervisor will react and may restart. |
| `:ignore` | Don't start. Supervisor does **not** restart. |

---

### Step 4 — `handle_call/3` (synchronous)

```elixir
def cart_total(), do: GenServer.call(__MODULE__, :total)

@impl true
def handle_call(:total, _from, state) do
  total =
    state.cart
    |> Enum.reduce(0, fn item, acc ->
      acc + item.price * item.qty
    end)
  {:reply, total, state}
end
```

Use `handle_call` when the caller needs a value back. Like a parking ticket machine — you press the button and wait for the ticket. The caller is blocking until a reply arrives.

When you return `{:noreply, state}` you tell the GenServer: "don't send a response yet, let the caller keep waiting" — you must then call `GenServer.reply(from, val)` manually later.

> Always pass `state` at the end — even if unchanged. The GenServer needs it to carry forward to the next message.

| Return tuple | What happens |
|---|---|
| `{:reply, result, state}` | Send result back to caller, update state. Normal case. |
| `{:reply, result, state, timeout}` | Same, but triggers `handle_info(:timeout)` if idle after N ms. |
| `{:noreply, state}` | Caller keeps blocking. You must call `GenServer.reply(from, val)` later. |
| `{:stop, reason, reply, state}` | Send the reply, then shut down the GenServer. |

---

### Step 5 — `handle_cast/2` (asynchronous)

```elixir
def add_item(item), do: GenServer.cast(__MODULE__, {:add_item, item})

@impl true
def handle_cast({:add_item, item}, state) do
  new_state = %{state | cart: [item | state.cart]}
  {:noreply, new_state}
end
```

Use `handle_cast` when the caller does not need a result. Like a radio broadcast — you send, they receive, no confirmation. Takes 2 arguments: the message and the current state. No sender — nobody is waiting for a reply.

```elixir
iex> CartServer.add_item(%{name: "apple", price: 1.99, qty: 3})
:ok                   # just :ok — no value sent back

iex> CartServer.cart_total()
5.97                  # 1.99 × 3 ✓

iex> CartServer.add_item(%{name: "pear", price: 2.33, qty: 2})
iex> CartServer.cart_total()
10.63
```

Pattern-match in the message tuple — `{:add_item, item}` — so one GenServer can handle many different cast messages cleanly. Add more `handle_cast` clauses as needed.

| Return tuple | What happens |
|---|---|
| `{:noreply, state}` | Update state, keep running. Standard return. |
| `{:noreply, state, timeout}` | Same, but triggers `handle_info(:timeout)` if idle after N ms. |
| `{:stop, reason, state}` | Update state, then shut down the GenServer. |

---

### Step 6 — `handle_info/2` (timers and everything else)

Handles any message not sent via `call` or `cast` — including timer messages from `Process.send_after`. Without a `handle_info`, unexpected messages log a warning.

Here we send an abandoned-cart reminder 10 seconds after an item is added:

```elixir
@impl true
def handle_cast({:add_item, item}, state) do
  new_state = %{state | cart: [item | state.cart]}
  Process.send_after(self(), :reminder, 10_000)   # fire :reminder after 10s
  {:noreply, new_state}
end

@impl true
def handle_info(:reminder, state) do
  IO.puts("Don't forget about those items!")
  {:noreply, state}
end
```

> **Problem:** adding 3 items fires 3 reminders. We only want one. We need to cancel the previous timer each time a new item is added — solved in step 7.

| Return tuple | What happens |
|---|---|
| `{:noreply, state}` | Handle the message, update state, keep running. Normal case. |
| `{:noreply, state, timeout}` | Same, plus arm an idle timeout. |
| `{:stop, reason, state}` | Handle the message, then shut down. |

---

### Step 7 — Fixing the reminder (cancel before restart)

Store the timer PID in state. Cancel it before starting a new one. One reminder, no matter how many items are added.

We already have `timer_pid: nil` in our state from `init`. A private helper checks whether a timer is already running and cancels it before starting a fresh one.

```elixir
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

defp reset_reminder(state) do
  if state.timer_pid, do: Process.cancel_timer(state.timer_pid)
  timer_pid = Process.send_after(self(), :reminder, 10_000)
  %{state | timer_pid: timer_pid}
end
```

```elixir
iex> CartServer.start_link([])
iex> CartServer.add_item(%{name: "orange", price: 2.53, qty: 2})
iex> CartServer.add_item(%{name: "orange", price: 2.53, qty: 2})
iex> CartServer.add_item(%{name: "orange", price: 2.53, qty: 2})
# Only one reminder fires — 10s after the last item was added.
```

> `Process.cancel_timer` takes the timer reference returned by `send_after`. Storing it in state is the standard pattern for cancellable timers.# CartServer

I wanted to learn GenServer concepts really fast.

Watched this video and asked AI to devise a plan to learn:

**Elixir Full Course 39 - GenServer**
https://www.youtube.com/watch?v=a36lzSfzx8U

Most of it is a guided slop of AI generated stuff about GenServer.
But I cleared most of it to get the gist using claude.. :-)

---

## Return Tuple Quick Reference

Every callback must end with one of these tuples. OTP reads it and decides what to do next.

### `init/1`

| Tuple | Meaning |
|---|---|
| `{:ok, state}` | Start with this state. |
| `{:ok, state, timeout}` | Start, fire `handle_info(:timeout)` after N ms of silence. |
| `{:stop, reason}` | Refuse to start. Supervisor reacts. |
| `:ignore` | Don't start. Supervisor does **not** restart. |

### `handle_call/3`

| Tuple | Meaning |
|---|---|
| `{:reply, result, state}` | Send result to caller, update state. Most common. |
| `{:noreply, state}` | Caller waits. You must call `GenServer.reply(from, val)` later. |
| `{:stop, reason, reply, state}` | Reply first, then shut down. |

### `handle_cast/2` and `handle_info/2`

| Tuple | Meaning |
|---|---|
| `{:noreply, state}` | Update state, keep running. The standard return. |
| `{:noreply, state, timeout}` | Same, plus arm an idle timeout. |
| `{:stop, reason, state}` | Update state, then shut down. |

### `:stop` Reasons

| Reason | Supervisor behaviour |
|---|---|
| `:normal` | Clean exit. Supervisor does **not** restart. |
| `:shutdown` | Orderly shutdown signal. Not restarted. |
| anything else | Treated as a crash. Supervisor **will** restart. |

> Use `:normal` when you deliberately stop a GenServer (e.g. a shutdown call).
> Use any other atom (like `:bad_state`) to signal a real crash and trigger the supervisor's restart logic.

---

## Plan to Learn GenServer

### Phase 1 — Conceptual Foundation

Before writing code, it is essential to understand why GenServers exist and their role in the Elixir ecosystem.

- **Understand State and Immutability** — Learn how GenServer allows you to safely share and modify data across processes in an immutable language.
- **The GenServer Behaviour** — Recognize that a GenServer is a behaviour (similar to an interface) included in the OTP libraries for writing stateful server processes.
- **Process Architecture** — Grasp the distinction between the calling process (which executes client functions) and the GenServer process (which owns the data and executes callbacks).

### Phase 2 — Basic Setup and Initialization

Start by building a simple module to get familiar with the boilerplate and lifecycle.

- **Create a Project** — Use `mix new` to start a new project (e.g. a "shopping cart" server).
- **Implement the Behaviour** — Use the `use GenServer` macro to adopt the behaviour in your module.
- **Start the Process** — Learn to use `GenServer.start_link/3`. This involves specifying the module, the initial state, and optionally a name (atom) for the process.
- **The `init` Callback** — Implement `init/1` to set up the initial state and perform any necessary startup logic.

### Phase 3 — Mastering Communication Patterns

GenServer communication is primarily handled through three core callbacks. Understanding the difference between them is critical.

- **Synchronous Calls (`handle_call`)** — Use this when you need a reply from the server (e.g. getting the total price of a cart). It blocks the caller until the response is received.
- **Asynchronous Casts (`handle_cast`)** — Use this for "fire and forget" messages where no response is needed (e.g. adding an item to a cart).
- **Generic Messages (`handle_info`)** — Use this to handle messages sent to the process that are not standard calls or casts, such as system notifications or timers.

### Phase 4 — Best Practices in Design

Refine your code by following idiomatic Elixir patterns to ensure maintainability.

- **Client vs. Server Separation** — Structure your module into two sections: client-facing functions (API for other modules) and callback functions (internal GenServer logic).
- **Encapsulation** — Keep implementation details (like the GenServer name or specific message formats) hidden within the module so external code just calls standard functions.
- **The `@impl true` Annotation** — Use this before callbacks to let the compiler and other developers know you are overriding behaviour functions.

### Phase 5 — Advanced State and Reliability

Once basics are covered, explore more complex scenarios involving time and performance.

- **Introspection** — Practice using `:sys.get_state` and `GenServer.whereis` in the IEx shell to inspect your running process and its state.
- **Managing Timers** — Implement delayed logic using `Process.send_after/3`. Learn to manage these timers by storing their process IDs (PIDs) in your state and using `Process.cancel_timer/1` to prevent duplicate or stale messages.
- **Performance Awareness** — Understand that because a single GenServer process handles messages one at a time, it can become a bottleneck under extremely high load.

### Phase 6 — Practical Projects

To solidify your learning, build a **Shopping Cart Server** with the following features:

- **Add Item** — An asynchronous cast that prepends a map `(name, price, quantity)` to a list in the state.
- **Calculate Total** — A synchronous call that iterates through the cart state to sum prices multiplied by quantities.
- **Abandonment Reminders** — Use `handle_info` and timers to print a message if the user doesn't interact with the cart for a set duration.

---

> Once you are comfortable with these steps, you can move on to learning about **Supervisors**,
> which are used to start, monitor, and restart GenServer processes automatically.


