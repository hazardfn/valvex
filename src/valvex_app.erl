%%%---------------------------------------------------------------------------------------------------------------------
%% @doc Valvex rebar3 app
%% @end
%%%---------------------------------------------------------------------------------------------------------------------

-module(valvex_app).

-behaviour(application).

%% Application callbacks
-export([start/0, start/2, stop/1]).

%%======================================================================================================================
%% API
%%======================================================================================================================

start() ->
  application:start(valvex).
start(_StartType, _StartArgs) ->
  case application:get_all_env(valvex) of
     []      -> valvex_sup:start_link();
    _Options ->
     {ok, Queues}          = get_setting(valvex, queues),
     {ok, EventHandlers}   = get_setting(valvex, event_handlers),
     {ok, Workers}         = get_setting(valvex, workers),
     {ok, PushbackEnabled} = get_setting(valvex, pushback_enabled),
     valvex_sup:start_link([ {queues, Queues}
                           , {pushback_enabled, PushbackEnabled}
                           , {workers, Workers}
                           , {event_handlers, EventHandlers}
                           ])
  end.
%%----------------------------------------------------------------------------------------------------------------------
stop(_State) ->
    ok.

%%======================================================================================================================
%% Internal functions
%%======================================================================================================================

get_setting(App, Par) ->
  application:get_env(App, Par).

%%%_* Emacs ============================================================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
