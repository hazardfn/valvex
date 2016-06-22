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
For more technical information view the technical docs [here](http://hazardfn.github.io/valvex/doc).

Usage
--------
Simply start valvex through the supervisor, it will then be registered
as `valvex` to be used throughout your application.

````erlang
Pid = valvex_sup:start_link().
````
Here is an example of how to create a queue at run time and push work to it then listen for the reply.

````erlang
%% Add a queue with the key randomqueue that has a threshold of 1, a
%% timeout of 10 seconds, a pushback of 10 seconds, a poll rate of 
%% 100ms and uses the valvex_queue_fifo_backend. there are various 
%% options you can supply to add to change the behaviour, read the API 
%% docs for more info.
%%
%% We shall use the message_event_handler which is not recommended as
%% order is not guaranteed and it can be hard to get the result of
%% your work - the below example should work but if not extend the
%% sleep.


Pid = valvex_sup:start_link(),
valvex:add_handler(valvex, valvex_message_event_handler, [self()]),

Key       = randomqueue,
Threshold = {threshold, 1},
Timeout   = {timeout, 10, seconds},
Pushback  = {pushback, 10, seconds},
Poll      = {poll_rate, 100, ms},
Backend   = valvex_queue_fifo_backend,
Queue     = {Key, Threshold, Timeout, Pushback, Poll, Backend},
valvex:add(valvex, Queue),
RandomFun = fun() ->
             timer:sleep(5000),
             {expected_reply, 5000}
            end,
valvex:push(valvex, Key, RandomFun),
flush(),
receive
  {result, {expected_reply, Value}} ->
    io:format("Value: ~p~n", [Value]);
  {timeout, Key} ->
    io:format("The timeout has been hit");
  {threshold_hit, _Q} ->
    io:format("The amount of work exceeded the threshold")
after
  15000 ->
    io:format("Some hard timeout was reached indicating something seriously went wrong")
end,
 valvex:remove_handler(valvex, valvex_message_event_handler, []).
````
Output:

````
Shell got {queue_started,{randomqueue,{threshold,1},
                                      {timeout,10,seconds},
                                      {pushback,10,seconds},
                                      {poll_rate,100,ms},
                                      valvex_queue_fifo_backend}}
Shell got {queue_consumer_started,
              {randomqueue,
                  {threshold,1},
                  {timeout,10,seconds},
                  {pushback,10,seconds},
                  {poll_rate,100,ms},
                  valvex_queue_fifo_backend}}
Shell got {queue_push,{randomqueue,{threshold,1},
                                   {timeout,10,seconds},
                                   {pushback,10,seconds},
                                   {poll_rate,100,ms},
                                   valvex_queue_fifo_backend},
                      #Fun<erl_eval.20.54118792>}
Shell got {push_complete,{randomqueue,{threshold,1},
                                      {timeout,10,seconds},
                                      {pushback,10,seconds},
                                      {poll_rate,100,ms},
                                      valvex_queue_fifo_backend},
                         #Fun<erl_eval.20.54118792>}
Value: 5000
ok
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

### `push (Identifier, Queue Key, Work) -> ok.`
---
#### Description:

Pushes work to the queue with the queue key you specified. Will not error if the queue does not exist.

#### Spec:

**Identifier:** Pid or registered atom of the valve server.

**Queue Key:** A unique atom identifying the queue.

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

### `pushback (Identifier, Queue Key) -> ok.`
---
#### Description:

Simply waits for the pushback limit of the specified queue and
responds {threshold_hit, _Q} via eventing.

#### Spec:

**Identifier:** Pid or registered atom of the valve server.

**Queue Key:** A unique atom identifying the queue.

### `notify (Identifier, Event) -> ok.`
---
#### Description:

Notifies any added handlers of an event.

#### Spec:

**Identifier:** Pid or registered atom of the valve server.

**Queue Key:** An event (see list of valid events in notes)

#### Notes:

Valid events:

* {queue_crossover, Q, NuQ} - Triggered when a crossover occurs, Q is
  the old queue and NuQ is the new queue.
* {queue_started, Q} - Triggered on start_link
* {queue_popped, Q} - Triggered when pop is called
* {queue_popped_r, Q} - Triggered when pop_r is called
* {queue_push, Q, Work} - Triggered when push is called, regardless of outcome
* {queue_push_r, Q, Work} - See push.
* {push_complete, Q, Work} - Triggered when the push operation was a success
* {push_to_locked_queue, Q, Work} - Triggered when there's an attempt
  to push to a locked queue
* {queue_removed, Key} - Triggered when a tombstoned queue is finally removed
* {queue_tombstoned, Q} - Triggered when a queue is marked to die
* {queue_locked, Q} - Triggered when a queue is locked
* {queue_unlocked, Q} - Triggered when a queue is unlocked
* {queue_consumer_started, Q} - Triggered when the consumer is started
* {queue_consumer_stopped, Q} - Triggered when the consumer is stopped
* {timeout, QKey} - Triggered when the work goes stale
* {result, Result} - Triggered when work is finally over
* {threshold_hit, Q} - Triggered when a push is attempted but there's
  already too many items.
