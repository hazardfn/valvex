# Overview | [Travis-CI](https://travis-ci.org/hazardfn/valvex_core) :: ![Build Status](https://travis-ci.org/hazardfn/valvex_core.svg)
--------
valveX is a rate-limiter written in erlang - it has a lot of tweakable
options to ensure you get the best solution. Valvex_core allows you to
include the functionality of valvex into your existing application, if
you want to run valvex as a standalone application amongst other
services see the standard valvex repo.

Features
--------
* Support for unlimited queues (within the erlang process limit)
* Each queue has independent state, allowing separate rules for each queue
* Choose from different queue types such as FIFO or LIFO
* Extensibility through the use of backends - each queue can use a
   different backend
* Queues are supervised and restarted
* Configurable threshold allowing for pushback under high load

Configuration
--------
Before you can use valvex you need to configure environment variables
in your sys.config or you can use the API to change the settings/add
queues at runtime.

Usage
--------
The best way to use valvex is to start the process and then register
it with a name, this makes it reachable from anywhere you need it.

````erlang
Pid = valvex:start_link([]),
erlang:register(valvex, Pid).
````
Here is an example of how to create a queue at run time and push work
to it then listen for the reply. (This assumes you registered the PID
with the name valvex as above).

````erlang
%% Add a queue with the key randomqueue
%% that has a threshold of 1 and a timeout
%% of 10 seconds, add is idempotent but there
%% is different behaviours if you supply a change
%% to the timeout or threshold
%% read further in the api docs for more info.
valvex:add(valvex, {randomqueue, 1, 10}),
RandomFun = fun() ->
             timer:sleep(1000),
             {expected_reply, 1000}
            end,
valvex:push(valvex, self(), randomqueue, RandomFun),
receive
  {expected_reply, Value} ->
    io:format(Value);
  {error, timeout} ->
    io:format("The timeout has been hit");
  {error, threshold_hit} ->
    io:format("The amount of work exceeded the threshold")
after
  15000 ->
    io:format("Some hard timeout was reached indicating something seriously went wrong")
end.
````

API
--------

This sections attempts to document the API and it's behaviour under certain scenarios.

### add (Identifier, {Queue Key, Threshold, Timeout, Queue Backend}, Option) -> ok | {error, key_not_unique}.
---
#### Description:

Adds a queue at runtime. An add/2 operation also exists removing the need for options.

#### Spec:

**Identifier:** Pid or registered atom of the valve server.

**Queue Key:** A unique atom identifying the queue.

**Threshold:** Count of work items allowed on the queue before it starts to push back.

**Timeout:** A value that indicates when the work this queue will receive has gone on too long - this value is also used as part of the pushback.

**Option:** An atom which can change how add works:

_crossover_on_existing_

_crossover_on_existing_force_remove_

**Queue Backend:** A module that uses the queue behaviour you need, there are some defaults:

_valvex_fifo_queue_backend_

_valvex_lifo_queue_backend_

Feel free to create your own with any additional features you may need.

#### Notes:

Add is an idempotent operation, if the queue already exists with the same settings and key you will get an ok back and nothing will change.

However, if you specify different settings with an existing key you will get an error stating your key is not unique. If you don't care about this you can specify the crossover_on_error option.

_crossover_on_existing:_

Instead of returning key_not_unique a crossover will be performed meaning the old queue will process it's existing items as it did before but accept no new ones and deactivate itself when it's finished while the new queue, with it's updated threshold and timeout, will accept all further work items.

_crossover_on_error_force_remove:_

This will immediately remove the old queue and any work it had queued up instead of a graceful crossover.

### remove (Identifier, Queue Key, Option) -> ok.
---
#### Description:

Triggers a queue removal at runtime. A remove/2 operation also exists removing the need for options.

#### Spec:

**Identifier:** Pid or registered atom of the valve server.

**Queue Key:** A unique atom identifying the queue.

**Option:** An atom that can change how remove works:

_force_remove_

_lock_queue_

#### Notes:

By default remove is an idempotent and safe operation, it will merely mark a queue for removal and only remove it when it has no remaining work - it can still continue to receive work however, this is by design to prevent crashes. If a queue marked for removal is continuing to receive work it will print a warning. You can specify options to change this behaviour.

_force_remove_:

Will remove the queue regardless of work left.

_lock_queue_:

Will remove as normal but prevent the queue from receiving new work.

### push (Identifier, Reply Identifier, Queue Key, Work) -> ok | {error, key_not_found}.
---
#### Description:

Pushes work to the queue with the queue key you specified. Will error if the key does not exist.

#### Spec:

**Identifier:** Pid or registered atom of the valve server.

**Reply Identifier:** Pid of the process that is awaiting the result of the work.

**Queue Key:** A unique atom identifying the queue you want to push work to.

**Work:** A fun() of stuff to do.
