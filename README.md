# CartServer

I wanted to learn genserver concepts really fast.

Watched this video and asked ai to devise a plan to learn 

Elixir Full Course 39 - Genserver
https://www.youtube.com/watch?v=a36lzSfzx8U

Most of it is a guided slop of ai generated stuff about genserver. 

But I cleared most of it to get the gist

### Return tuple quick reference

Every callback must end with one of these tuples. OTP reads it and decides what to do next.

### init/1
Tuple			Meaning
{:ok, state} 		Start with this state.

{:ok, state, timeout} 	Start, fire handle_info(:timeout) after N ms of silence.

{:stop, reason}		Refuse to start. Supervisor reacts

:ignore			Don't start. Supervisor does NOT restart.



handle_call/3
Tuple	Meaning
{:reply, result, state}	Send result to caller, update state. Most common.
{:noreply, state}	Caller waits. You must call GenServer.reply(from, val) later.
{:stop, reason, reply, state}	Reply first, then shut down.

handle_cast/2 and handle_info/2
Tuple	Meaning
{:noreply, state}	Update state, keep running. The standard return.
{:noreply, state, timeout}	Same, plus arm an idle timeout.
{:stop, reason, state}	Update state, then shut down.
:stop reasons

Reason	Supervisor behaviour
:normal	Clean exit. Supervisor does NOT restart.
:shutdown	Orderly shutdown signal. Not restarted.

anything else	Treated as a crash. Supervisor WILL restart.
Use :normal when you deliberately stop a GenServer (e.g. a shutdown call). 
Use any other atom (like :bad_state) to signal a real crash and trigger the supervisor's restart logic.


Plan to learn genserver 

Phase 1: Conceptual Foundation
Before writing code, it is essential to understand why GenServers exist and their role in the Elixir ecosystem.

    Understand State and Immutability: Learn how GenServer allows you to safely share and modify data across processes in an immutable language.
    The GenServer Behavior: Recognize that a GenServer is a behavior (similar to an interface) included in the OTP libraries for writing stateful server processes.
    Process Architecture: Grasp the distinction between the calling process (which executes client functions) and the GenServer process (which owns the data and executes callbacks).

Phase 2: Basic Setup and Initialization
Start by building a simple module to get familiar with the boilerplate and lifecycle.

    Create a Project: Use mix new to start a new project (e.g., a "shopping cart" server).
    Implement the Behavior: Use the use GenServer macro to adopt the behavior in your module.
    Start the Process: Learn to use GenServer.start_link/3. This involves specifying the module, the initial state, and optionally a name (atom) for the process.
    The init Callback: Implement init/1 to set up the initial state and perform any necessary startup logic.

Phase 3: Mastering Communication Patterns
GenServer communication is primarily handled through three core callbacks. Understanding the difference between them is critical.

    Synchronous Calls (handle_call): Use this when you need a reply from the server (e.g., getting the total price of a cart). It blocks the caller until the response is received.
    Asynchronous Casts (handle_cast): Use this for "fire and forget" messages where no response is needed (e.g., adding an item to a cart).
    Generic Messages (handle_info): Use this to handle messages sent to the process that are not standard calls or casts, such as system notifications or timers.

Phase 4: Best Practices in Design
Refine your code by following idiomatic Elixir patterns to ensure maintainability.

    Client vs. Server Separation: Structure your module into two sections: Client-facing functions (API for other modules) and Callback functions (internal GenServer logic).
    Encapsulation: Keep implementation details (like the GenServer name or specific message formats) hidden within the module so external code just calls standard functions.
    The @impl true Annotation: Use this before callbacks to let the compiler and other developers know you are overriding behavior functions.

Phase 5: Advanced State and Reliability
Once basics are covered, explore more complex scenarios involving time and performance.

Introspection: Practice using :sys.get_state and GenServer.whereis in the IEx shell to inspect your running process and its state.

Managing Timers: Implement delayed logic using Process.send_after/3. Learn to manage these timers by storing their process IDs (PIDs) in your state and using Process.cancel_timer/1 to prevent duplicate or stale messages.
Performance Awareness: Understand that because a single GenServer process handles messages one at a time, it can become a bottleneck under extremely high load.

Phase 6: Practical Projects
To solidify your learning, the sources suggest building a Shopping Cart Server with the following features:

    Add Item: An asynchronous cast that prepends a map (name, price, quantity) to a list in the state.
    Calculate Total: A synchronous call that iterates through the cart state to sum prices multiplied by quantities.
    Abandonment Reminders: Use handle_info and timers to print a message if the user doesn't interact with the cart for a set duration.

Once you are comfortable with these steps, you can move on to learning about Supervisors, which are used to start, monitor, and restart GenServer processes automatically


