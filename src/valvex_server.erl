%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @author Howard Beard-Marlowe <howardbm@live.se>
%%% @copyright 2016 Howard Beard-Marlowe
%%% @version 1.0.2
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @doc Valvex Server
%%
%% The server is responsible for queue management as well
%% as sending events and pushback.

-module(valvex_server).

-behaviour(gen_server).

%% API exports
-export([ add/3
        , add_handler/3
        , remove/3
        , remove_handler/3
        , push/3
        , get_available_workers/1
        , get_queue_size/2
        , start_link/1
        , notify/2
        , pushback/2
        , update/3
        ]).

-export([ code_change/3
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , init/1
        , terminate/2
        ]).

-type valvex_state() :: #{ queues            => [valvex:valvex_queue()]
                         , queue_pids        => [tuple()]
                         , pushback          => true | false
                         , workers           => [pid()]
                         , event_server      => valvex:valvex_ref() | undefined
                         , available_workers => [pid()]
                         }.

%%======================================================================================================================
%% API functions
%%======================================================================================================================
%% @doc Starts a link to the valvex server
-spec start_link(valvex:valvex_options()) -> valvex:valvex_ref().
start_link(Options) ->
  {ok, Pid} = gen_server:start_link({local, valvex}, ?MODULE, Options, []),
  Pid.

%% @doc Adds a queue to valvex, there are some alternative options
%% that can be used to alter the behaviour of add.
%% @see valvex:add_option()
-spec add(valvex:valvex_ref(), valvex:valvex_queue(), valvex:add_option()) -> ok | valvex:unique_key_error().
add(Valvex, { _Key
            , {threshold, _Threshold}
            , {timeout, _Timeout, seconds}
            , {pushback, _Pushback, seconds}
            , {poll_rate, _Poll, ms}
            , _Backend
            } = Q, Option) ->
  do_add(Valvex, Q, Option).

%% @doc Removes a queue from valvex, there are some alternative options
%% that can be used to alter the behaviour of remove.
%% @see valvex:remove_option()
-spec remove(valvex:valvex_ref(), valvex:queue_key(), valvex:remove_option()) -> ok | valvex:key_find_error().
remove(Valvex, Key, Option) ->
  do_remove(Valvex, Key, Option).

%% @doc Pushes an item to a queue with a specific key.
-spec push( valvex:valvex_ref(), valvex:queue_key(), valvex:valvex_q_item()) -> ok.
push(Valvex, Key, Value) ->
  do_push(Valvex, Key, Value).

%% @doc Gets available workers, as in those that aren't currently
%% undertaking work.
-spec get_available_workers(valvex:valvex_ref()) -> valvex:valvex_workers().
get_available_workers(Valvex) ->
  do_get_workers(Valvex).

%% @doc Gets the current size of the queue with the given key.
-spec get_queue_size( valvex:valvex_ref(), valvex:queue_key()) -> non_neg_integer() | valvex:key_find_error().
get_queue_size(Valvex, Key) ->
  do_get_queue_size(Valvex, Key).

%% @doc Pushes back on the client forcing them to wait
%% this prevents spamming if enabled.
-spec pushback(valvex:valvex_ref(), valvex:queue_key()) -> ok.
pushback(Valvex, Key) ->
  do_pushback(Valvex, Key).

%% @doc Notifies all registered event handlers of an event
%% within valvex, read the readme for more info.
-spec notify( valvex:valvex_ref(), any()) -> ok.
notify(Valvex, Event) ->
  do_notify(Valvex, Event).

%% @doc Adds a handler which will receive events from valvex, view
%% the readme for more info on events.
-spec add_handler(valvex:valvex_ref(), module(), list()) -> ok.
add_handler(Valvex, Module, Args) ->
  do_add_handler(Valvex, Module, Args).

%% @doc Removes a handler so it will no longer receive events.
-spec remove_handler(valvex:valvex_ref(), module(), list()) -> ok.
remove_handler(Valvex, Module, Args) ->
  do_remove_handler(Valvex, Module, Args).

%% @doc Updates a queue after a crossover
%% @private
-spec update(valvex:valvex_ref(), valvex:queue_key(), valvex:valvex_queue()) -> ok.
update(Valvex, Key, Q) ->
  do_update(Valvex, Key, Q).

%%======================================================================================================================
%% Gen Server Callbacks
%%======================================================================================================================
%% @doc Inititalizes valvex with predefined queues, settings and
%% event handlers
-spec init([tuple()]) -> {ok, valvex_state()}.
init([ {queues, Queues}
     , {pushback_enabled, Pushback}
     , {workers, WorkerCount}
     , {event_handlers, EventHandlers}
     ]) ->
  process_flag(trap_exit, true),
  gen_server:cast(self(), {init, Queues, Pushback, WorkerCount, EventHandlers}),
  {ok, #{ queues            => []
        , queue_pids        => []
        , pushback          => false
        , workers           => []
        , event_server      => undefined
        , available_workers => []
        }};
%% @doc starts the server with default settings.
init([]) ->
  process_flag(trap_exit, true),
  Workers = start_workers(10),
  {ok, EventServer} = gen_event:start_link(),
  {ok, #{ queues            => []
        , queue_pids        => []
        , pushback          => false
        , workers           => Workers
        , event_server      => EventServer
        , available_workers => Workers
        }}.

%% @doc see the "see also" section for a list of synchronous operations
%% @see add()
%% @see get_available_workers()
%% @see remove()
%% @see add_handler()
%% @see remove_handler()
%% @see update()
handle_call({get_queue, Key}, _From, #{ queue_pids := Queues } = S) ->
  case lists:keyfind(Key, 1, Queues) of
    false ->
      {reply, {error, key_not_found}, S};
    {Key, _Backend} = Queue ->
      lager:info("get_queue found: ~p", [Queue]),
      {reply, Queue, S}
  end;
handle_call({get_raw_queue, Key}, _From, #{ queue_pids := Queues
                                          , queues     := RawQueues
                                          } = S) ->
  case lists:keyfind(Key, 1, Queues) of
    false ->
      {reply, {error, key_not_found}, S};
    {Key, _Backend} ->
      RawQ = lists:keyfind(Key, 1, RawQueues),
      lager:info("get_raw_queue found: ~p", [RawQ]),
      {reply, RawQ, S}
  end;
handle_call({add, { Key
                  , _Threshold
                  , _Timeout
                  , _Pushback
                  , _Poll
                  , Backend
                  } = Q, Option}, _From, #{ queues       := Queues
                                          , queue_pids   := QPids
                                          } = S) ->
  NewQueues = lists:append(Queues, [Q]),
  valvex_queue_sup:start_child([Backend, Key, Q]),
  if
    Option /= manual_start ->
      valvex_queue:start_consumer(Backend, Key);
    true -> ok
  end,
  NewQPids  = lists:append(QPids, [{Key, Backend}]),
  lager:info("queue added: ~p", [Q]),
  {reply, ok, S#{ queues     := NewQueues
                , queue_pids := NewQPids
                }};
handle_call(get_workers, _From, #{ available_workers := Workers } = S) ->
  lager:info("List of workers requested: ~p", [Workers]),
  {reply, Workers, S};
handle_call( {assign_work, {Work, Timestamp}, {Key, QPid, Backend}}
           , _From, #{ available_workers := Workers } = S) ->
  case Workers == [] of
    false ->
      [Worker | T] = Workers,
      Valvex = self(),
      WorkFun = fun() ->
                    valvex:notify(Valvex, {result, Work(), Key})
                end,
      valvex:notify(Valvex, {worker_assigned, Key, Worker, T}),
      valvex_worker:work(Worker, {work, WorkFun}),
      {noreply, S#{ available_workers := T }};
    true ->
      valvex:notify(self(), {work_requeued, Key, []}),
      valvex_queue:push_r(Backend, QPid, {Work, Timestamp}),
      {noreply, S}
  end;
handle_call({remove, Key}, _From, #{ queues     := Queues
                                   , queue_pids := QPids
                                   } = S) ->
  supervisor:terminate_child(valvex_queue_sup, Key),
  supervisor:delete_child(valvex_queue_sup, Key),
  {reply, ok, S#{ queues     := lists:keydelete(Key, 1, Queues)
                , queue_pids := lists:keydelete(Key, 1, QPids)
                }};
handle_call( {add_handler, Module, Args}
           , _From
           , #{ event_server := EventServer} = S
           ) ->
  lager:info("Handler added Module:~p, Args:~p", [Module, Args]),
  ok = gen_event:add_sup_handler(EventServer, Module, Args),
  {reply, ok, S};
handle_call( {remove_handler, Module, Args}
           , _From
           , #{ event_server := EventServer} = S
           ) ->
  lager:info("Handler removed Module:~p, Args:~p", [Module, Args]),
  ok = gen_event:delete_handler(EventServer, Module, Args),
  {reply, ok, S};
handle_call({update, Key, { Key
                          , _
                          , _
                          , _
                          , _
                          , Backend} = Q}, _From, #{ queues     := Queues
                                                  , queue_pids := QPids
                                                  } = S) ->
  lager:info("Queue options updated Key:~p, Update:~p", [Key, Q]),
  NewQueues = lists:append(lists:keydelete(Key, 1, Queues), [Q]),
  NewQPids  = lists:append(lists:keydelete(Key, 1, QPids), [{Key, Backend}]),
  {reply, ok, S#{ queues     := NewQueues
                , queue_pids := NewQPids }};
handle_call(get_queues, _From, #{queues := Queues} = S) ->
  {reply, Queues, S}.

handle_cast({pushback, Key}, #{ queues := Queues } = S) ->
  case lists:keyfind(Key, 1, Queues) of
    {Key, _, _, {pushback, Pushback, seconds}, _, _} = Q ->
      Valvex = self(),
      spawn(fun() ->
                TimeoutMS = timer:seconds(Pushback),
                timer:sleep(TimeoutMS),
                notify(Valvex, {threshold_hit, Q})
            end),
      {noreply, S};
    false ->
      {noreply, S}
  end;
handle_cast({push, Key, Value}, #{queue_pids := Queues} = S) ->
  case lists:keyfind(Key, 1, Queues) of
    false ->
      {noreply, S};
    {Key, Backend} ->
      valvex_queue:push(Backend, Key, Value),
      {noreply, S}
    end;
handle_cast( {work_finished, WorkerPid}
           , #{ available_workers := Workers } = S) ->
  lager:info("Work has finished and a worker has been free'd: ~p", [WorkerPid]),
  {noreply, S#{ available_workers := lists:append(Workers, [WorkerPid]) }};
handle_cast({notify, Event}
           , #{ event_server := EventServer } = S
           ) ->
  lager:info("Event sent to subscribers: ~p", [Event]),
  gen_event:notify(EventServer, Event),
  {noreply, S};
handle_cast({init, Queues, Pushback, WorkerCount, EventHandlers}, _S) ->
  {ok, EventServer} = gen_event:start_link(),
  HandlerFun = fun({EventModule, Args}) ->
                   gen_event:add_handler(EventServer, EventModule, Args)
               end,
  lists:foreach(HandlerFun, EventHandlers),
  QueueFun = fun({ Key
                 , _Threshold
                 , _Timeout
                 , _Pushback
                 , _Poll
                 , Backend
                 } = Q) ->
                 valvex_queue_sup:start_child([Backend, Key, Q]),
                 valvex_queue:start_consumer(Backend, Key),
                 [{Key, Backend}]
             end,
  Workers = start_workers(WorkerCount),
  {noreply, #{ queues            => Queues
             , queue_pids        => lists:flatmap(QueueFun, Queues)
             , pushback          => Pushback
             , workers           => Workers
             , event_server      => EventServer
             , available_workers => Workers
             }}.

handle_info(_Info, S) ->
  {noreply, S}.

code_change(_Vsn, S, _Extra) ->
  {ok, S}.

terminate(_Reason, #{ workers := Workers, event_server := ES } = _S) ->
  StopWorkerFun = fun(Worker) ->
                      valvex_worker:stop(Worker)
                  end,
  lists:foreach(StopWorkerFun, Workers),
  gen_event:stop(ES),
  ok.

%%==============================================================================
%% Internal functions
%%==============================================================================

get_queue(Valvex, Key) ->
  gen_server:call(Valvex, {get_queue, Key}).

do_add(Valvex, {Key, _, _, _, _, _} = Q, undefined) ->
  case get_queue(Valvex, Key) of
    {error, key_not_found} ->
      gen_server:call(Valvex, {add, Q, undefined});
    _ ->
      lager:error("Attempted to add a non-unique key: ~p", [Key]),
      {error, key_not_unique}
  end;
do_add(Valvex, {Key, _, _, _, _, Backend} = Q, crossover_on_existing) ->
  case get_queue(Valvex, Key) of
    {error, key_not_found} ->
      do_add(Valvex, Q, undefined);
    {Key, Backend} ->
      valvex_queue:crossover(Backend, Key, Q);
    {_, _} ->
      lager:error("Attempted to switch backend/key - operation not supported"),
      {error, backend_key_crossover_not_supported}
  end;
do_add(Valvex, {Key, _, _, _, _, _} = Q, manual_start) ->
  case get_queue(Valvex, Key) of
    {error, key_not_found} ->
      gen_server:call(Valvex, {add, Q, manual_start});
    {Key, _} ->
      lager:error("Attempted to add a non-unique key: ~p", [Key]),
      {error, key_not_unique}
  end.

do_remove(Valvex, Key, undefined) ->
  case get_queue(Valvex, Key) of
    {Key, Backend} ->
      valvex_queue:tombstone(Backend, Key);
    {error, key_not_found} = Error ->
      lager:error("Attempted to remove a non-existing key: ~p", [Key]),
      Error
  end;
do_remove(Valvex, Key, lock_queue) ->
  case get_queue(Valvex, Key) of
    {Key, Backend} ->
      valvex_queue:lock(Backend, Key),
      valvex_queue:tombstone(Backend, Key);
    {error, key_not_found} = Error ->
      lager:error("Attempted to remove a non-existing key: ~p", [Key]),
      Error
  end;
do_remove(Valvex, Key, force_remove) ->
  case get_queue(Valvex, Key) of
    {Key, _Backend}          ->
      gen_server:call(Valvex, {remove, Key});
    {error, key_not_found} = Error ->
      lager:error("Attempted to remove a non-existing key: ~p", [Key]),
      Error
  end.

do_push(Valvex, Key, Value) ->
  gen_server:cast(Valvex, {push, Key, Value}).

do_get_workers(Valvex) ->
  gen_server:call(Valvex, get_workers).

do_get_queue_size(Valvex, Key) ->
  case get_queue(Valvex, Key) of
    {Key, Backend} ->
      valvex_queue:size(Backend, Key);
    Error ->
      Error
  end.

do_pushback(Valvex, Key) ->
  gen_server:cast(Valvex, {pushback, Key}).

do_notify(Valvex, Event) ->
  gen_server:cast(Valvex, {notify, Event}).

do_add_handler(Valvex, Module, Args) ->
  gen_server:call(Valvex, {add_handler, Module, Args}).

do_remove_handler(Valvex, Module, Args) ->
  gen_server:call(Valvex, {remove_handler, Module, Args}).

do_update(Valvex, Key, {_, _, _, _, _, Backend} = Q) ->
  case get_queue(Valvex, Key) of
    {error, key_not_found} ->
      lager:error("Attempted to update a non-existing queue"),
      {error, key_not_found};
    {Key, Backend} ->
      gen_server:call(Valvex, {update, Key, Q});
    _ ->
      lager:error("Attempted to switch backend/key - operation not supported"),
      {error, backend_key_crossover_not_supported}
  end.
start_workers(WorkerCount) ->
  lists:flatmap(fun(_) ->
                    [valvex_worker:start_link(self())]
                end, lists:seq(1, WorkerCount)).

%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
