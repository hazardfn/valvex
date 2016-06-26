-module(valvex_worker).

-behaviour(gen_server).

-export([ start_link/1
        , stop/1
        , work/2
        ]).

-export([ code_change/3
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , init/1
        , terminate/2
        ]).

%%%=============================================================================
%%% API
%%%=============================================================================
-spec start_link(valvex:valvex_ref()) -> valvex:valvex_ref().
start_link(Valvex) ->
  {ok, Pid} = gen_server:start_link(?MODULE, Valvex, []),
  Pid.

work(Worker, Work) ->
  gen_server:cast(Worker, Work).

-spec stop(valvex:valvex_ref()) -> ok.
stop(Worker) ->
  gen_server:call(Worker, stop).

%%%=============================================================================
%%% Gen Server Callbacks
%%%=============================================================================
init(Valvex) ->
  {ok, #{ valvex => Valvex }}.

handle_cast({work, Work}, #{ valvex := Valvex } = S) ->
  Work(),
  gen_server:cast(Valvex, {work_finished, self()}),
  {noreply, S}.

handle_call(stop, _From, #{ valvex := Valvex } = S) ->
  valvex:notify(Valvex, {worker_stopped, self()}),
  {stop, normal, ok, S}.

handle_info(_Msg, S) ->
  {noreply, S}.

code_change(_OldVsn, S, _Extra) ->
  {ok, S}.

terminate(_Reason, _S) ->
  ok.
%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
