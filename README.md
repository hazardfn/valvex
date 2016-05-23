# Overview | [![Travis-CI](https://travis-ci.org/hazardfn/valvex.svg)](https://travis-ci.org/hazardfn/valvex)
--------
valveX is a rate-limiter written in erlang - it has a lot of tweakable
options to ensure you get the best solution.

Features
--------
* Support for unlimited queues (within the erlang process limit)
* Each queue has independent state, allowing separate rules for each queue
* Choose from different queue types, FIFO and LIFO are supported out the box using erlangs queue - create your own if these don't appeal to you.
* Extensibility through the use of backends - each queue can use a different backend
* Queues are supervised and restarted
* Configurable threshold allowing for pushback under high load

Configuration
--------
Before you can use valvex you need to configure environment variables in your sys.config or you can use the API to change the settings/add queues at runtime.

Usage
--------
Simply start valvex through the supervisor, it will then be registered
as valvex to be used throughout your application.

````erlang
Pid = valvex_sup:start_link([]).
````
Here is an example of how to create a queue at run time and push work to it then listen for the reply.

````erlang
%% Add a queue with the key randomqueue that has a threshold of 1, a
timeout of 10 seconds, a pushback of 10 seconds, a poll rate of 100ms
%% and uses the valvex_queue_fifo_backend. there are various options you can supply to add to change the behaviour,
%% read the API docs for more info.

Pid = valvex_sup:start_link([]),

Key       = randomqueue,
Threshold = {threshold, 1},
Timeout   = {timeout, 10, seconds},
Pushback  = {pushback, 10, seconds},
Poll      = {poll_rate, 100, ms},
Backend   = valvex_queue_fifo_backend,
Queue     = {Key, Threshold, Timeout, Pushback, Poll, Backend},
valvex:add(valvex, Queue),
RandomFun = fun() ->
             timer:sleep(1000),
             {expected_reply, 1000}
            end,
valvex:push(valvex, Key, self(), RandomFun),
receive
  {expected_reply, Value} ->
    io:format("Value: ~p", [Value]);
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

### `add (Identifier, {Queue Key, Threshold, Timeout, Pushback, Poll, Queue Backend}, Option) -> ok | {error, key_not_unique}.`
---
#### Description:

Adds a queue at runtime. An add/2 operation also exists removing the need for options.

#### Spec:

**Identifier:** Pid or registered atom of the valve server.

**Queue Key:** A unique atom identifying the queue.

**Threshold:** Count of work items allowed on the queue before it starts to push back.

**Timeout:** A value that indicates when the work this queue will receive has gone on too long - this value is also used as part of the pushback.

**Pushback:** In the event of the threshold being hit valvex will wait x seconds before responding to the client, this prevents users from receiving an instant response decreasing the chance that they will constantly spam refresh your page causing more work / requests.

**Poll:** A value that indicates how often the queue should be polled.

**Option:** An atom which can change how add works:

`crossover_on_existing`

`crossover_on_existing_force_remove`

**Queue Backend:** A module that uses the queue behaviour you need, there are some defaults:

`valvex_fifo_queue_backend`

`valvex_lifo_queue_backend`

Feel free to create your own with any additional features you may need.

#### Notes:

The functionality of add differs depending on the option you supply, by default if you try to add a key that isn't unique you will receive an `{error, key_not_unique}` back.

`crossover_on_existing` will create your new queue regardless of key uniqueness and all future requests will go to that queue, the old one will be tombstoned and locked - this means it will process any work it has left using old values (Timeout, Pushback etc.) then kill itself. This is good when you want to change queue settings but not disturb ongoing requests.

`crossover_on_existing_force_remove` will add your new queue and immediately kill the old queue regardless of contents - this can be highly disruptive and is only useful in some corner cases.

### `remove (Identifier, Queue Key, Option) -> ok | {error, key_not_found}.`
---
#### Description:

Triggers a queue removal at runtime. A remove/2 operation also exists removing the need for options.

#### Spec:

**Identifier:** Pid or registered atom of the valve server.

**Queue Key:** A unique atom identifying the queue.

**Option:** An atom that can change how remove works:

`force_remove`

`lock_queue`

#### Notes:

By default remove is a safe operation, it will merely mark a queue for removal and only remove it when it has no remaining work - it can still continue to receive work however, this is by design to prevent crashes. If a queue marked for removal is continuing to receive work it will print a warning. You can specify options to change this behaviour.

`force_remove` will kill a queue regardless of it's contents, again please use this carefully.

`lock_queue` will remove as normal but prevent the queue from receiving new work, while in most cases safe your code can crash if you have forgot to remove all instances where the queue being removed is used.

### `push (Identifier, Queue Key, Reply Identifier, Work) -> ok.`
---
#### Description:

Pushes work to the queue with the queue key you specified. Will not error if the queue does not exist.

#### Spec:

**Identifier:** Pid or registered atom of the valve server.

**Queue Key:** A unique atom identifying the queue. 

**Reply Identifier:** Pid of the process that is awaiting the result of the work.

**Work:** A fun() of stuff to do.

### `get_available_workers (Identifier) -> [pid()].`
---
#### Description:

Gets a list of pid's that represent your available workers.

#### Spec:

**Identifier:** Pid or registered atom of the valve server.

### `get_available_workers_count (Identifier) -> non_neg_integer()`
---
#### Description:

Gets the number of workers currently available (not processing work).

#### Spec:

**Identifier:** Pid or registered atom of the valve server.

### `get_queue_size (Identifier, Queue Key) -> non_neg_integer() | {error, key_not_found}.`
---
#### Description:

Gets the current number of items in a specified queue.

#### Spec:

**Identifier:** Pid or registered atom of the valve server.

**Queue Key:** A unique atom identifying the queue. 

### `pushback (Identifier, Queue Key, Reply Identifier) -> ok.`
---
#### Description:

Simply waits for the pushback limit of the specified queue and responds {error, threshold_hit} to the Reply Identifier

#### Spec:

**Identifier:** Pid or registered atom of the valve server.

**Queue Key:** A unique atom identifying the queue. 

**Reply Identifier:** Pid of the process that is awaiting the result of the work.
