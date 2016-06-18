-module(valvex_queue_fifo_backend).

-behaviour(valvex_queue).
-behaviour(gen_server).

-export([ consume/5
        , is_locked/1
        , is_tombstoned/1
        , lock/1
        , pop/1
        , pop_r/1
        , push/2
        , push_r/2
        , size/1
        , start_consumer/1
        , start_link/2
        , stop_consumer/1
        , tombstone/1
        , unlock/1
        ]).

-export([ init/1
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , code_change/3
        , terminate/2
        ]).

%%==============================================================================
%% Queue Callbacks
%%==============================================================================
-spec start_link( valvex:valvex_ref()
                , valvex:valvex_queue()
                ) -> valvex:valvex_ref().
start_link(Valvex, { Key, _, _, _, _, _ } = Q) ->
  gen_server:start_link({local, Key}, ?MODULE, [Valvex, Q], []).

-spec pop(valvex:valvex_ref()) -> valvex:valvex_q_item().
pop(Q) ->
  gen_server:call(Q, pop).

-spec pop_r(valvex:valvex_ref()) -> valvex:valvex_q_item().
pop_r(Q) ->
  gen_server:call(Q, pop_r).

-spec push(valvex:valvex_ref(), valvex:valvex_q_item()) -> ok.
push(Q, Value) ->
  gen_server:cast(Q, {push, Value}).

-spec push_r(valvex:valvex_ref(), valvex:valvex_q_item()) -> ok.
push_r(Q, Value) ->
  gen_server:cast(Q, {push_r, Value}).

-spec tombstone(valvex:valvex_ref()) -> ok.
tombstone(Q) ->
  gen_server:cast(Q, tombstone).

-spec is_tombstoned(valvex:valvex_ref()) -> true | false.
is_tombstoned(Q) ->
  gen_server:call(Q, is_tombstoned).

-spec lock(valvex:valvex_ref()) -> ok.
lock(Q) ->
  gen_server:cast(Q, lock).

-spec unlock(valvex:valvex_ref()) -> ok.
unlock(Q) ->
  gen_server:cast(Q, unlock).

-spec is_locked(valvex:valvex_ref()) -> true | false.
is_locked(Q) ->
  gen_server:call(Q, is_locked).

-spec size(valvex:valvex_ref()) -> non_neg_integer().
size(Q) ->
  gen_server:call(Q, size).

-spec start_consumer(valvex:valvex_ref()) -> ok.
start_consumer(Q) ->
  gen_server:cast(Q, start_consumer).

-spec stop_consumer(valvex:valvex_ref()) -> ok.
stop_consumer(Q) ->
  gen_server:cast(Q, stop_consumer).

-spec consume( valvex:valvex_ref()
             , valvex:valvex_ref()
             , valvex:queue_backend()
             , valvex:queue_key()
             , non_neg_integer()) -> ok.
consume(Valvex, QPid, Backend, Key, Timeout) ->
  do_consume(Valvex, QPid, Backend, Key, Timeout).

%%==============================================================================
%% Gen Server Callbacks
%%==============================================================================

init([ Valvex
     , { Key
       , {threshold, Threshold}
       , {timeout, Timeout, seconds}
       , {pushback, Pushback, seconds}
       , {poll_rate, Poll, ms}
       , _Backend
       } = Q
     ]) ->
  valvex:notify(Valvex, {queue_started, Q}),
  {ok, #{ key        => Key
        , threshold  => Threshold
        , timeout    => Timeout
        , pushback   => Pushback
        , backend    => ?MODULE
        , size       => 0
        , poll_rate  => Poll
        , queue      => queue:new()
        , q          => Q
        , locked     => true
        , tombstoned => false
        , valvex     => Valvex
        , queue_pid  => self()
        , consumer   => undefined
        }}.

handle_call(pop, _From, #{ queue      := Q0
                         , q          := RawQ
                         , size       := Size
                         , tombstoned := Tombstone
                         , valvex     := Valvex
                         } = S) ->
  Value = queue:out(Q0),
  case Value of
    {{value, {_Work, _Timestamp}}, Q} ->
      valvex:notify(Valvex, {queue_popped, RawQ, Value}),
      {reply, Value, update_state(Q, Size-1, S)};
    {empty, _}                                ->
      case Tombstone of
        false -> {reply, Value, S};
        true  -> {reply, {empty, tombstoned}, S}
      end
  end;
handle_call(pop_r, _From, #{ queue      := Q0
                           , q          := RawQ
                           , size       := Size
                           , tombstoned := Tombstone
                           , valvex     := Valvex
                           } = S) ->
  Value = queue:out_r(Q0),
  case Value of
    {{value, {_Work, _Timestamp}}, Q} ->
      valvex:notify(Valvex, {queue_popped_r, RawQ, Value}),
      {reply, Value, update_state(Q, Size-1, S)};
    {empty, _}                                ->
      case Tombstone of
        false -> {reply, Value, S};
        true  -> {reply, {empty, tombstoned}, S}
      end
  end;
handle_call(is_locked, _From, #{ locked := Locked } = S) ->
  {reply, Locked, S};
handle_call(is_tombstoned, _From, #{ tombstoned := Tombstoned } = S) ->
  {reply, Tombstoned, S};
handle_call(size, _From, #{ size := Size } = S) ->
  {reply, Size, S}.

handle_cast({push, {Work, _Timestamp} = Value}, #{ key       := Key
                                                         , valvex    := Valvex
                                                         , queue     := Q
                                                         , q         := RawQ
                                                         , threshold := Threshold
                                                         , size      := Size
                                                         , locked    := Locked
                                                         } = S) ->
  valvex:notify(Valvex, {queue_push, RawQ, Work}),
  case Locked of
    true  ->
      valvex:notify(Valvex, {push_to_locked_queue, RawQ, Work}),
      {noreply, S};
    false ->
      case Size >= Threshold of
        true ->
          valvex:pushback(Valvex, Key),
          {noreply, S};
        false ->
          valvex:notify(Valvex, {push_complete, RawQ, Work}),
          {noreply, update_state(queue:in(Value, Q), Size+1, S)}
      end
  end;
handle_cast( {push_r, {Work, _Timestamp} = Value}, #{ key       := Key
                                                     , valvex    := Valvex
                                                     , queue     := Q
                                                     , q         := RawQ
                                                     , threshold := Threshold
                                                     , size      := Size
                                                     , locked    := Locked
                                                     } = S) ->
  valvex:notify(Valvex, {queue_push_r, RawQ, Work}),
  case Locked of
    true  ->
      valvex:notify(Valvex, {push_to_locked_queue, RawQ, Work}),
      {noreply, S};
    false ->
      case Size >= Threshold of
        true ->
          valvex:pushback(Valvex, Key),
          {noreply, S};
        false ->
          valvex:notify(Valvex, {push_complete, RawQ, Work}),
          {noreply, update_state(queue:in_r(Value, Q), Size+1, S)}
      end
  end;
handle_cast(lock, #{ valvex := Valvex, q := RawQ } = S) ->
  valvex:notify(Valvex, {queue_locked, RawQ}),
  {noreply, S#{ locked := true }};
handle_cast(unlock, #{ valvex := Valvex, q := RawQ } = S) ->
  valvex:notify(Valvex, {queue_unlocked, RawQ}),
  {noreply, S#{ locked := false }};
handle_cast(tombstone, #{ valvex := Valvex, q := RawQ } = S) ->
  valvex:notify(Valvex, {queue_tombstoned, RawQ}),
  {noreply, S#{ tombstoned := true}};
handle_cast(start_consumer, #{ valvex     := Valvex
                             , queue_pid  := QPid
                             , backend    := Backend
                             , key        := Key
                             , timeout    := Timeout
                             , poll_rate  := Poll
                             , q          := RawQ
                             } = S) ->
  {ok, TRef} = timer:apply_interval( Poll
                                   , ?MODULE
                                   , consume
                                   , [Valvex, QPid, Backend, Key, Timeout]
                                   ),
  valvex:notify(Valvex, {queue_consumer_started, RawQ}),
  {noreply, S#{ consumer => TRef
              , locked   := false
              }};
handle_cast(stop_consumer, #{ consumer := TRef
                            , q        := RawQ
                            , valvex   := Valvex
                            } = S) ->
  timer:cancel(TRef),
  valvex:notify(Valvex, {queue_consumer_stopped, RawQ}),
  {noreply, S#{ consumer := undefined
              , locked   := true
              }}.

handle_info(_Info, S) ->
  {noreply, S}.

code_change(_Vsn, S, _Extra) ->
  {ok, S}.

terminate(_Reason, #{ consumer := Consumer
                    , key      := Key
                    }) ->

  case Consumer of
    undefined ->
      ok;
    _         ->
      timer:cancel(Consumer)
  end,

  case whereis(Key) of
    undefined ->
      ok;
    _         ->
    erlang:unregister(Key)
  end.

%%%=============================================================================
%%% Helpers
%%%=============================================================================
do_consume(Valvex, QPid, Backend, Key, Timeout) ->
  try
    QueueValue = gen_server:call(QPid, pop),
    case QueueValue of
      {{value, {Work, Timestamp}}, _Q} ->
        case is_stale(Timeout, Timestamp) of
          false ->
            gen_server:call(Valvex, { assign_work
                                    , {Work, Timestamp}
                                    , {Key, QPid, Backend}
                                    }
                           );
          true  ->
            valvex:notify(Valvex, {timeout, Key})
        end,
        do_consume(Valvex, QPid, Backend, Key, Timeout);
      {empty, tombstoned} ->
        valvex:remove(Valvex, Key, force_remove);
      {empty, _} ->
        ok
    end
  catch _Error:_Reason ->
      do_consume(Valvex, QPid, Backend, Key, Timeout)
  end.

update_state(Q, Size, S) ->
  S#{ size := Size, queue := Q }.

is_stale(Timeout, Timestamp) ->
  TimeoutMS = timer:seconds(Timeout),
  Diff      = timer:now_diff(erlang:timestamp(), Timestamp),
  Diff > (TimeoutMS * 1000).
%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
