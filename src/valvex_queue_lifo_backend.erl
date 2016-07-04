%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @author Howard Beard-Marlowe <howardbm@live.se>
%%% @copyright 2016 Howard Beard-Marlowe
%%% @version 0.1.0
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @doc Valvex LIFO backend
%%
%% The fifo backend provides a last in first out behaviour for valvex
%% it uses a standard erlang queue - if this behaviour does not suit
%% your application or you wish to use a custom queue feel free
%% to create your own backend, be careful to ensure you adhere to
%% to the behaviour of a valvex queue and to include knowledge
%% of locking and tombstoning to your backend.

-module(valvex_queue_lifo_backend).

-behaviour(valvex_queue).
-behaviour(gen_server).

-export([ consume/5
        , crossover/2
        , get_state/1
        , is_consuming/1
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
        , code_change/3
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , terminate/2
        ]).

%%======================================================================================================================
%% Queue Callbacks
%%======================================================================================================================


%% @doc consumes once from the queue, usually used via start_consumer which
%% slurps from the queue per milliseconds as set in the poll_rate setting.
%% @see start_consumer
%% @see valvex:queue_poll_rate()
-spec consume( valvex:valvex_ref()
             , valvex:valvex_ref()
             , valvex:queue_backend()
             , valvex:queue_key()
             , non_neg_integer()) -> ok.
consume(Valvex, QPid, Backend, Key, Timeout) ->
  do_consume(Valvex, QPid, Backend, Key, Timeout).

%% @doc initiates a crossover, the replacement of the current queue settings
%% with a different arrangement.
-spec crossover( valvex:valvex_ref(), valvex:valvex_queue()) -> ok.
crossover(Q, NuQ) ->
  gen_server:cast(Q, {crossover, NuQ}),
  gen_server:cast(Q, restart_consumer).

-spec get_state( valvex:valvex_ref()) -> valvex_queue:queue_state().
get_state(Q) ->
  gen_server:call(Q, get_state).

%% @doc returns true if the consumer is active.
-spec is_consuming(valvex:valvex_ref()) -> true | false.
is_consuming(Q) ->
  gen_server:call(Q, is_consuming).

%% @doc returns true if the queue is locked, more details about what that means
%% exist in the readme.
-spec is_locked(valvex:valvex_ref()) -> true | false.
is_locked(Q) ->
  gen_server:call(Q, is_locked).

%% @doc returns true if the queue is queued for deletion, it will only be deleted
%% once empty and can only be guaranteed to be eventually empty when locked.
-spec is_tombstoned(valvex:valvex_ref()) -> true | false.
is_tombstoned(Q) ->
  gen_server:call(Q, is_tombstoned).

%% @doc lock the queue, refer to the readme for specifics as to what this means.
-spec lock(valvex:valvex_ref()) -> ok.
lock(Q) ->
  gen_server:cast(Q, lock).

%% @doc pop the queue, in the case of this backend it's last in first out.
-spec pop(valvex:valvex_ref()) -> valvex:valvex_q_item().
pop(Q) ->
  gen_server:call(Q, pop).

%% @doc pop_r is the reverse operation of whatever pop is, in this case it's
%% first in first out.
-spec pop_r(valvex:valvex_ref()) -> valvex:valvex_q_item().
pop_r(Q) ->
  gen_server:call(Q, pop_r).

%% @doc pushes a queue item to the queue. The item is placed at the end.
%% @see valvex:valvex_q_item()
-spec push(valvex:valvex_ref(), valvex:valvex_q_item()) -> ok.
push(Q, Value) ->
  gen_server:cast(Q, {push, Value}).

%% @doc pushes a queue item to the queue. The item is placed at the front.
%% @see valvex:valvex_q_item()
-spec push_r(valvex:valvex_ref(), valvex:valvex_q_item()) -> ok.
push_r(Q, Value) ->
  gen_server:cast(Q, {push_r, Value}).

%% @doc returns the current number of items in the queue.
-spec size(valvex:valvex_ref()) -> non_neg_integer().
size(Q) ->
  gen_server:call(Q, size).

%% @doc starts a timer that regularly calls the consume function
%% to facilitate constant slurping of the queue, how regularly
%% is determined by the poll_rate.
%% @see valvex:queue_poll_rate()
%% @see consume()
-spec start_consumer(valvex:valvex_ref()) -> ok.
start_consumer(Q) ->
  gen_server:cast(Q, start_consumer).

%% @doc starts a link with the queue gen_server.
-spec start_link(valvex:valvex_ref(), valvex:valvex_queue()) -> valvex:valvex_ref().
start_link(Valvex, { Key, _, _, _, _, _ } = Q) ->
  gen_server:start_link({local, Key}, ?MODULE, [Valvex, Q], []).

%% @doc stops the regular consumption of the queue.
-spec stop_consumer(valvex:valvex_ref()) -> ok.
stop_consumer(Q) ->
  gen_server:cast(Q, stop_consumer).

%% @doc marks the queue for deletion.
-spec tombstone(valvex:valvex_ref()) -> ok.
tombstone(Q) ->
  gen_server:cast(Q, tombstone).

%% @doc unlocks the queue, for more information about what this means
%% consult the readme.
-spec unlock(valvex:valvex_ref()) -> ok.
unlock(Q) ->
  gen_server:cast(Q, unlock).

%%======================================================================================================================
%% Gen Server Callbacks
%%======================================================================================================================

%% @doc to initialize a queue the valvex reference to valvex_server
%% is required and a queue.
%% @see valvex:valvex_queue()
%% @see valvex:valvex_ref()
-spec init(list()) -> {ok, valvex_queue:queue_state()}.
init([ Valvex, { Key
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
        , locked     => false
        , tombstoned => false
        , valvex     => Valvex
        , queue_pid  => self()
        , consumer   => undefined
        , consuming  => false
        }}.

%% @doc see the "see also" list for a list of synchronous operations
%% @see pop()
%% @see pop_r()
%% @see is_locked()
%% @see is_tombstoned()
%% @see size()
handle_call(pop, _From, #{ queue      := Q0
                         , q          := RawQ
                         , size       := Size
                         , tombstoned := Tombstone
                         , valvex     := Valvex
                         } = S) ->
  Value = queue:out_r(Q0),
  evaluate_value(Valvex, Tombstone, Size, RawQ, Value, queue_popped, S);
handle_call(pop_r, _From, #{ queue      := Q0
                           , q          := RawQ
                           , size       := Size
                           , tombstoned := Tombstone
                           , valvex     := Valvex
                           } = S) ->
  Value = queue:out(Q0),
  evaluate_value(Valvex, Tombstone, Size, RawQ, Value, queue_popped_r, S);
handle_call(is_consuming, _From, #{ consumer := Consumer} = S) ->
  case Consumer of
    undefined -> {reply, false, S};
    _         -> {reply, true, S}
    end;
handle_call(is_locked, _From, #{ locked := Locked } = S) ->
  {reply, Locked, S};
handle_call(is_tombstoned, _From, #{ tombstoned := Tombstoned } = S) ->
  {reply, Tombstoned, S};
handle_call(size, _From, #{ size := Size } = S) ->
  {reply, Size, S};
handle_call(get_state, _From, S) ->
  {reply, S, S}.

%% @doc See the "see also" list for a list of asynchronous operations.
%% @see push()
%% @see push_r()
%% @see lock()
%% @see unlock()
%% @see tombstone()
%% @see crossover()
%% @see start_consumer()
%% @see stop_consumer()
handle_cast({push, {Work, _Timestamp} = Value}, #{ valvex    := Valvex
                                                 , q         := RawQ
                                                 , queue     := Q
                                                 } = S) ->
  valvex:notify(Valvex, {queue_push, RawQ}),
  evaluate_push(S, queue:in(Value, Q), Work);
handle_cast( {push_r, {Work, _Timestamp} = Value}, #{ valvex    := Valvex
                                                    , q         := RawQ
                                                    , queue     := Q
                                                    } = S) ->
  valvex:notify(Valvex, {queue_push_r, RawQ}),
  evaluate_push(S, queue:in_r(Value, Q), Work);
handle_cast(lock, #{ valvex := Valvex, q := RawQ } = S) ->
  valvex:notify(Valvex, {queue_locked, RawQ}),
  {noreply, S#{ locked := true }};
handle_cast(unlock, #{ valvex := Valvex, q := RawQ } = S) ->
  valvex:notify(Valvex, {queue_unlocked, RawQ}),
  {noreply, S#{ locked := false }};
handle_cast(tombstone, #{ valvex := Valvex, q := RawQ } = S) ->
  valvex:notify(Valvex, {queue_tombstoned, RawQ}),
  {noreply, S#{ tombstoned := true}};
handle_cast({crossover, NuQ}, #{ key      := Key
                               , valvex   := Valvex
                               , q        := RawQ
                               } = S) ->
  valvex:notify(Valvex, {queue_crossover, RawQ, NuQ}),
  valvex:update(Valvex, Key, NuQ),
  do_crossover(NuQ, S);
handle_cast(start_consumer, #{ valvex     := Valvex
                             , queue_pid  := QPid
                             , backend    := Backend
                             , key        := Key
                             , timeout    := Timeout
                             , poll_rate  := Poll
                             , q          := RawQ
                             , consumer   := TRef0
                             } = S) ->
  case TRef0 of
    undefined ->
      start_timer(Valvex, QPid, Backend, Key, Timeout, Poll, RawQ, S);
    _ ->
      {noreply, S}
  end;
handle_cast(restart_consumer, #{ valvex    := Valvex
                               , queue_pid := QPid
                               , backend   := Backend
                               , key       := Key
                               , timeout   := Timeout
                               , poll_rate := Poll
                               , q         := RawQ
                               , consumer  := TRef
                               } = S) ->
  case TRef of
    undefined -> {noreply, S};
    _         ->
      timer:cancel(TRef),
      start_timer(Valvex, QPid, Backend, Key, Timeout, Poll, RawQ, S)
  end;
handle_cast(stop_consumer, #{ consumer := TRef
                            , q        := RawQ
                            , valvex   := Valvex
                            } = S) ->
  timer:cancel(TRef),
  valvex:notify(Valvex, {queue_consumer_stopped, RawQ}),
  {noreply, S#{ consumer := undefined, consuming := false }}.

%% @doc Info messages are discarded.
handle_info(_Info, S) ->
  {noreply, S}.

%% @doc Restarts the consumer only during a code change as this may be
%% required if code within the consumer function has changed, it will
%% only be restarted if it was running at the point of change.
code_change(_Vsn, S, _Extra) ->
  gen_server:cast(self(), restart_consumer),
  {ok, S}.

%% @doc Performs cleanup by stopping the consumer and unregistering
%% the queues key if it remains registered for whatever reason.
terminate(_Reason, #{ consumer := Consumer
                    , key      := Key
                    }) ->
  cleanup(Consumer, Key).


%%%=====================================================================================================================
%%% Helpers
%%%=====================================================================================================================
cleanup(Consumer, Key) ->
  maybe_stop_consumer(Consumer),
  maybe_unregister_queue(whereis(Key), Key).

maybe_stop_consumer(undefined) ->
  ok;
maybe_stop_consumer(Consumer) ->
  timer:cancel(Consumer).

maybe_unregister_queue(undefined, _Key) ->
  ok;
maybe_unregister_queue(_Pid, Key) ->
  erlang:unregister(Key).

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
        valvex:notify(Valvex, {queue_removed, Key}),
        valvex:remove(Valvex, Key, force_remove);
      {empty, _} ->
        ok
    end
  catch _Error:_Reason ->
      do_consume(Valvex, QPid, Backend, Key, Timeout)
  end.

update_state(Q, Size, S) ->
  S#{ size := Size, queue := Q }.

evaluate_value(Valvex, Tombstone, Size, RawQ, Value, Event, S) ->
  case Value of
    {{value, {_Work, _Timestamp}}, Q} ->
      valvex:notify(Valvex, {Event, RawQ}),
      {reply, Value, update_state(Q, Size-1, S)};
    {empty, _}                                ->
      case Tombstone of
        false -> {reply, Value, S};
        true  -> {reply, {empty, tombstoned}, S}
      end
  end.

evaluate_push(#{ key       := Key
               , valvex    := Valvex
               , q         := RawQ
               , threshold := Threshold
               , size      := Size
               } = S, Q, _Work) ->
  case Size >= Threshold of
    true ->
      valvex:pushback(Valvex, Key),
      {noreply, S};
    false ->
      valvex:notify(Valvex, {push_complete, RawQ}),
      {noreply, update_state(Q, Size+1, S)}
  end.

do_crossover({ _Key
             , {threshold, Threshold}
             , {timeout, Timeout, seconds}
             , {pushback, Pushback, seconds}
             , {poll_rate, Poll, ms}
             , _Backend
             } = Q, S) ->
{noreply, S#{ threshold := Threshold
            , timeout   := Timeout
            , pushback  := Pushback
            , poll_rate := Poll
            , q         := Q}}.

start_timer(Valvex, QPid, Backend, Key, Timeout, Poll, RawQ, S) ->
  {ok, TRef} = timer:apply_interval( Poll
                                   , ?MODULE
                                   , consume
                                   , [Valvex, QPid, Backend, Key, Timeout]
                                   ),
  valvex:notify(Valvex, {queue_consumer_started, RawQ}),
  {noreply, S#{ consumer => TRef, consuming => true }}.

is_stale(Timeout, Timestamp) ->
  TimeoutMS = timer:seconds(Timeout),
  Diff      = timer:now_diff(erlang:timestamp(), Timestamp),
  Diff      > (TimeoutMS * 1000).
%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
