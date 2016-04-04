-module(valvex_queue_sup).
-behaviour(supervisor).

-export([ start_link/0 ]).
-export([ init/1 ]).

start_link([]) ->
  supervisor:start_link({local, Key}, ?MODULE, []).

start_child([Backend, Key, Q]) ->
  supervisor:start_child

init([Backend, Key, Q]) ->
  {ok
  , { #{ strategy  => one_for_one
       , intensity => 3
       , period    => 60
       }
    , [valvex_queue_child_specs([Backend, Key, Q])]
    }}.

valvex_queue_child_specs([Backend, Key, Q]) ->
  #{ id       => Key
   , start    => {valvex_queue, start_link, [Backend, valvex, Q]}
   , restart  => permanent
   , shutdown => 3600
   , type     => worker
   , modules  => [ Backend ]}.
