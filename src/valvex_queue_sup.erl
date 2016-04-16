-module(valvex_queue_sup).
-behaviour(supervisor).

-export([ start_link/0
        , start_child/1
        ]).
-export([ init/1 ]).
-export([ valvex_queue_child_specs/1 ]).

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

start_child([_Backend, _Key, _Q] = Args) ->
    supervisor:start_child(?MODULE, valvex_queue_child_specs(Args)).

init([]) ->
  {ok
  , { #{ strategy  => one_for_one
       , intensity => 3
       , period    => 60
       }
    , []
    }}.

valvex_queue_child_specs([Backend, Key, Q]) ->
  #{ id       => Key
   , start    => {valvex_queue, start_link, [Backend, valvex, Q]}
   , restart  => permanent
   , shutdown => 3600
   , type     => worker
   , modules  => [ Backend ]}.
