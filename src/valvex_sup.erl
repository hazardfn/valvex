-module(valvex_sup).
-behaviour(supervisor).

-export([ start_link/0 ]).
-export([ init/1 ]).

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
  {ok
  , { #{ strategy  => one_for_one
       , intensity => 3
       , period    => 60
       }
    , [ valvex_server_child_specs()
      , valvex_queue_sup_child_specs()
      ]
    }}.

valvex_server_child_specs() ->
  #{ id       => valvex
   , start    => {valvex, start_link, [[]]}
   , restart  => permanent
   , shutdown => 3600
   , type     => worker
   , modules  => [ valvex_server ]
   }.

valvex_queue_sup_child_specs() ->
  #{ id       => valvex_queue_sup
   , start    => {valvex_queue_sup, start_link, []}
   , restart  => permanent
   , shutdown => 3600
   , type     => supervisor
   , modules  => [ valvex_queue_sup ]
   }.
