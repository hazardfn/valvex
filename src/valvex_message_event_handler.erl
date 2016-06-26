-module(valvex_message_event_handler).
-behaviour(gen_event).

%% gen_event exports
-export([ init/1
        , handle_event/2
        , handle_call/2
        , handle_info/2
        , code_change/3
        , terminate/2
        ]).

%% API exports
-export([]).

%%==============================================================================
%% Gen Event API
%%==============================================================================
init([Pid]) ->
  {ok, #{ receiver => Pid }}.

handle_event({queue_started, _Q} = Event, #{ receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S};
handle_event({queue_popped, _Q} = Event, #{ receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S};
handle_event({queue_popped_r, _Q} = Event, #{ receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S};
handle_event({queue_push, _Q} = Event, #{ receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S};
handle_event({queue_push_r, _Q} = Event, #{ receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S};
handle_event({push_complete, _Q} = Event, #{ receiver := Pid} = S) ->
  Pid ! Event,
  {ok, S};
handle_event({push_to_locked_queue, _Q} = Event, #{ receiver := Pid} = S) ->
  Pid ! Event,
  {ok, S};
handle_event({queue_tombstoned, _Q} = Event, #{ receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S};
handle_event({queue_locked, _Q} = Event, #{ receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S};
handle_event({queue_unlocked, _Q} = Event, #{ receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S};
handle_event({queue_consumer_started, _Q} = Event, #{ receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S};
handle_event({queue_consumer_stopped, _Q} = Event, #{ receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S};
handle_event({timeout, _Key} = Event, #{ receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S};
handle_event({result, _Result, _Key} = Event, #{ receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S};
handle_event({threshold_hit, _Q} = Event, #{ receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S};
handle_event({work_requeued, _Key, _AvailableWorkers} = Event, #{ receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S};
handle_event({worker_assigned, _Key, _AvailableWorkers} = Event, #{ receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S};
handle_event({queue_crossover, _Q, _NuQ} = Event, #{ receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S};
handle_event({queue_removed, _Key} = Event, #{ receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S};
handle_event({worker_stopped, _Worker} = Event, #{receiver := Pid } = S) ->
  Pid ! Event,
  {ok, S}.


handle_info(_, State) ->
  {ok, State}.

handle_call(_, S) ->
  {ok, ok, S}.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

terminate(_Reason, _State) ->
  ok.

%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
