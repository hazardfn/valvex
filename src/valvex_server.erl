-module(valvex_server).

-behaviour(gen_server).

%% API exports
-export([ add/3
        , remove/3
        , push/3
        , get_available_workers/1
        , get_queue_size/2
        , start_link/1
        , pushback/3
        ]).

-export([ code_change/3
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , init/1
        , terminate/2
        ]).

%%==============================================================================
%% API functions
%%==============================================================================
-spec start_link(valvex:valvex_options()) -> valvex:valvex_ref().
start_link(Options) ->
  {ok, Pid} = gen_server:start_link({local, valvex}, ?MODULE, Options, []),
  Pid.

-spec add( valvex:valvex_ref()
         , valvex:valvex_queue()
         , valvex:add_option()) -> ok | valvex:unique_key_error().
add(Valvex, { _Key
            , {threshold, _Threshold}
            , {timeout, _Timeout, seconds}
            , {pushback, _Pushback, seconds}
            , {poll_rate, _Poll, ms}
            , _Backend
            } = Q, Option) ->
  do_add(Valvex, Q, Option).

-spec remove( valvex:valvex_ref()
            , valvex:queue_key()
            , valvex:remove_option()
            ) -> ok | valvex:key_find_error().
remove(Valvex, Key, Option) ->
  do_remove(Valvex, Key, Option).

-spec push( valvex:valvex_ref()
          , valvex:queue_key()
          , valvex:valvex_q_item()
          ) -> ok.
push(Valvex, Key, Value) ->
  do_push(Valvex, Key, Value).

-spec get_available_workers(valvex:valvex_ref()) -> valvex:valvex_workers().
get_available_workers(Valvex) ->
  do_get_workers(Valvex).

-spec get_queue_size( valvex:valvex_ref()
                    , valvex:queue_key()
                    ) -> non_neg_integer() | valvex:key_find_error().
get_queue_size(Valvex, Key) ->
  do_get_queue_size(Valvex, Key).

-spec pushback( valvex:valvex_ref()
              , valvex:queue_key()
              , valvex:valvex_ref()
              ) -> ok.
pushback(Valvex, Key, Reply) ->
  do_pushback(Valvex, Key, Reply).

%%==============================================================================
%% Gen Server Callbacks
%%==============================================================================

init([ {queues, Queues}
     , {pushback_enabled, Pushback}
     , {workers, WorkerCount}
     ]) ->
  process_flag(trap_exit, true),
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
  {ok, #{ queues            => Queues
        , queue_pids        => lists:flatmap(QueueFun, Queues)
        , pushback          => Pushback
        , workers           => Workers
        , available_workers => Workers
        }};
init([]) ->
  process_flag(trap_exit, true),
  Workers = start_workers(10),
  {ok, #{ queues            => []
        , queue_pids        => []
        , pushback          => false
        , workers           => Workers
        , available_workers => Workers
        }}.

handle_call({get_queue, Key}, _From, #{ queue_pids := Queues } = S) ->
  ActiveQ = get_active_queues(Queues),
  case lists:keyfind(Key, 1, ActiveQ) of
    false ->
      {reply, {error, key_not_found}, S};
    {Key, _Backend} = Queue ->
      {reply, Queue, S}
  end;
handle_call({add, { Key
                  , _Threshold
                  , _Timeout
                  , _Pushback
                  , _Poll
                  , Backend
                  } = Q, Option}, _From, #{ queues     := Queues
                                          , queue_pids := QPids
                                          } = S) ->
  NewQueues = lists:append(Queues, [Q]),
  valvex_queue_sup:start_child([Backend, Key, Q]),
  if
    Option /= manual_start ->
      valvex_queue:start_consumer(Backend, Key);
    true -> ok
  end,
  NewQPids  = lists:append(QPids, [{Key, Backend}]),
  {reply, ok, S#{ queues     := NewQueues
                , queue_pids := NewQPids
                }};
handle_call(get_workers, _From, #{ available_workers := Workers } = S) ->
  {reply, Workers, S};
handle_call( {assign_work, {Work, Reply, Timestamp}, {_Key, QPid, Backend}}
           , _From, #{ available_workers := Workers } = S) ->
  case Workers == [] of
    false ->
      [Worker | T] = Workers,
      WorkFun = fun() ->
                    case is_process_alive(Reply) of
                      true  -> Reply ! Work();
                      false -> caller_dead
                    end
                end,
      gen_server:cast(Worker, {work, WorkFun}),
      {noreply, S#{ available_workers := T }};
    true ->
      valvex_queue:push_r(Backend, QPid, {Work, Reply, Timestamp}),
      {noreply, S}
  end;
handle_call({remove, Key}, _From, #{ queues     := Queues
                                   , queue_pids := QPids
                                   } = S) ->
  {reply, ok, S#{ queues     := lists:keydelete(Key, 1, Queues)
                , queue_pids := lists:keydelete(Key, 1, QPids)
                }}.

handle_cast({pushback, Key, Reply}, #{ queues := Queues } = S) ->
  case lists:keyfind(Key, 1, Queues) of
    {Key, _, _, {Pushback, seconds}, _, _} ->
      spawn(fun() ->
                TimeoutMS = timer:seconds(Pushback),
                timer:sleep(TimeoutMS),
                Reply ! {error, threshold_hit}
            end),
      {noreply, S};
    false ->
      {noreply, S}
  end;
handle_cast({push, Key, Value}, #{queue_pids := Queues} = S) ->
  ActiveQ = get_active_queues(Queues),
  case lists:keyfind(Key, 1, ActiveQ) of
    false ->
      {noreply, S};
    {Key, Backend} ->
      valvex_queue:push(Backend, Key, Value),
      {noreply, S}
  end;
handle_cast({work_finished, WorkerPid}
           , #{ available_workers := Workers } = S) ->
  {noreply, S#{ available_workers := lists:append(Workers, [WorkerPid]) }}.

handle_info(_Info, S) ->
  {noreply, S}.

code_change(_Vsn, S, _Extra) ->
  {ok, S}.

terminate(_Reason, #{ queue_pids := _QPids
                    , workers    := _Workers
                    }) ->
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
      {error, key_not_unique}
  end;
do_add(Valvex, {Key, _, _, _, _, _} = Q, crossover_on_existing) ->
  case get_queue(Valvex, Key) of
    {error, key_not_found} ->
      do_add(Valvex, Q, undefined);
    {Key, Backend} ->
      do_add(Valvex, Q, undefined),
      valvex_queue:lock(Backend, Key),
      valvex_queue:tombstone(Backend, Key)
  end;
do_add(Valvex, {Key, _, _, _, _, _} = Q, crossover_on_existing_force_remove) ->
  case get_queue(Valvex, Key) of
    {error, key_not_found} ->
      do_add(Valvex, Q, undefined);
    {Key, _Backend} ->
      do_add(Valvex, Key, undefined),
      do_remove(Valvex, Key, force_remove)
  end;
do_add(Valvex, {Key, _, _, _, _, Backend} = Q, manual_start) ->
  case get_queue(Valvex, Key) of
    {error, key_not_found} ->
      gen_server:call(Valvex, {add, Q, manual_start});
    {Key, Backend} ->
      {error, key_not_unique}
  end.

do_remove(Valvex, Key, undefined) ->
  case get_queue(Valvex, Key) of
    {Key, Backend} ->
      valvex_queue:tombstone(Backend, Key);
    Error ->
      Error
  end;
do_remove(Valvex, Key, lock_queue) ->
  case get_queue(Valvex, Key) of
    {Key, Backend} ->
      valvex_queue:lock(Backend, Key),
      valvex_queue:tombstone(Backend, Key);
    Error ->
      Error
  end;
do_remove(Valvex, Key, force_remove) ->
  case get_queue(Valvex, Key) of
    {Key, _Backend}          ->
      supervisor:terminate_child(valvex_queue_sup, Key),
      gen_server:call(Valvex, {remove, Key});
    {error, key_not_found} = Error ->
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

do_pushback(Valvex, Key, Reply) ->
  gen_server:cast(Valvex, {pushback, Key, Reply}).

get_active_queues(Queues) ->
  lists:filter(fun({Key, Backend}) ->
                 valvex_queue:is_locked(Backend, Key) == false
               end, Queues).

start_workers(WorkerCount) ->
  lists:flatmap(fun(_) ->
                    [valvex_worker:start_link(self())]
                end, lists:seq(1, WorkerCount)).

%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
