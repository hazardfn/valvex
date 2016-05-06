%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc valve tests
%%% @copyright 2016 Howard Beard-Marlowe
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%_* Module declaration =======================================================
-module(valvex_queue_tests).

-export([ test_queue_sup_start_fifo/1
        , test_queue_sup_start_lifo/1
        , test_queue_push_fifo/1
        , test_queue_push_lifo/1
        , test_queue_push_r_fifo/1
        , test_queue_push_r_lifo/1
        , test_queue_consumer_fifo/1
        , test_queue_consumer_lifo/1
        , test_queue_tombstone_fifo/1
        , test_queue_tombstone_lifo/1
        , test_queue_lock_fifo/1
        , test_queue_lock_lifo/1
        ]).

-export([ all/0
        , all/1
        , suite/0
        , init_per_suite/1
        , init_per_testcase/2
        , end_per_suite/1
        , end_per_testcase/2
        ]).

%%%_* Includes =================================================================
-include_lib("common_eunit/include/common_eunit.hrl").
%%%_* Suite Callbacks ==========================================================
suite() ->
  [{timetrap, {seconds, 60}}].

init_per_suite(Config) ->
  Config ++
     [ {queues, [ { test_fifo
                  , {threshold, 3}
                  , {timeout, 10, seconds}
                  , {pushback, 10, seconds}
                  , {poll_timer, 100, ms}
                  , valvex_queue_fifo_backend
                  }
                , { test_lifo
                  , {threshold, 3}
                  , {timeout, 10, seconds}
                  , {pushback, 10, seconds}
                  , {poll_timer, 100, ms}
                  , valvex_queue_lifo_backend
                  }
                ]
       }
     ].
end_per_suite(Config) ->
  Config.

init_per_testcase(TestCase, Config) ->
  {ok, _VSupPid}      = valvex_sup:start_link(),
  QFifo               = get_queue_from_config(test_fifo, Config),
  QLifo               = get_queue_from_config(test_lifo, Config),
  ok                  = valvex:add(valvex, QFifo, manual_start),
  ok                  = valvex:add(valvex, QLifo, manual_start),
  ?MODULE:TestCase({init, Config}).

end_per_testcase(TestCase, Config)  ->
  valvex:remove(valvex, test_fifo, force_remove),
  valvex:remove(valvex, test_lifo, force_remove),
  gen_server:stop(whereis(valvex)),
  gen_server:stop(whereis(valvex_queue_sup)),
  gen_server:stop(whereis(valvex_sup)),
  ?MODULE:TestCase({'end', Config}).

all()      ->
  all(suite).
all(suite) ->
  [ test_queue_sup_start_fifo
  , test_queue_sup_start_lifo
  , test_queue_push_fifo
  , test_queue_push_lifo
  , test_queue_push_r_fifo
  , test_queue_push_r_lifo
  , test_queue_consumer_fifo
  , test_queue_consumer_lifo
  , test_queue_tombstone_fifo
  , test_queue_tombstone_lifo
  , test_queue_lock_fifo
  , test_queue_lock_lifo
  ].

%%%_ * Tests ===================================================================
test_queue_sup_start_fifo(suite)                         -> [];
test_queue_sup_start_fifo({init, Config})                -> Config;
test_queue_sup_start_fifo({'end', _Config})              -> ok;
test_queue_sup_start_fifo(doc)                           ->
  ["Test we can start the fifo queue supervised and the config is correct"];
test_queue_sup_start_fifo(Config) when is_list(Config)   ->
  ?assert(is_pid(whereis(valvex_sup))),
  ?assert(is_pid(whereis(valvex_queue_sup))),
  ?assert(is_pid(whereis(test_fifo))).

test_queue_sup_start_lifo(suite)                         -> [];
test_queue_sup_start_lifo({init, Config})                -> Config;
test_queue_sup_start_lifo({'end', _Config})              -> ok;
test_queue_sup_start_lifo(doc)                           ->
  ["Test we can start the lifo queue supervised and the config is correct"];
test_queue_sup_start_lifo(Config) when is_list(Config)   ->
  ?assert(is_pid(whereis(valvex_sup))),
  ?assert(is_pid(whereis(valvex_queue_sup))),
  ?assert(is_pid(whereis(test_lifo))).

test_queue_push_fifo(suite)                         -> [];
test_queue_push_fifo({init, Config})                -> Config;
test_queue_push_fifo({'end', _Config})              -> ok;
test_queue_push_fifo(doc)                           ->
  ["Test pushing to the queue creates a queue item and handles it correctly"];
test_queue_push_fifo(Config) when is_list(Config)   ->
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  FirstItem     = {FirstTestFun, self(), os:timestamp()},
  SecondItem    = {SecondTestFun, self(), os:timestamp()},
  gen_server:cast(test_fifo, unlock),
  valvex_queue:push(valvex_queue_fifo_backend, test_fifo, FirstItem),
  valvex_queue:push(valvex_queue_fifo_backend, test_fifo, SecondItem),
  ?assertEqual(2, valvex_queue:size(valvex_queue_fifo_backend, test_fifo)),
  ?assertMatch( {{value, FirstItem}, _}
              , valvex_queue:pop(valvex_queue_fifo_backend, test_fifo)
              ),
  ?assertMatch( {{value, SecondItem}, _}
              , valvex_queue:pop(valvex_queue_fifo_backend, test_fifo)
              ).

test_queue_push_lifo(suite)                         -> [];
test_queue_push_lifo({init, Config})                -> Config;
test_queue_push_lifo({'end', _Config})              -> ok;
test_queue_push_lifo(doc)                           ->
  ["Test pushing to the queue creates a queue item and handles it correctly"];
test_queue_push_lifo(Config) when is_list(Config)   ->
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  FirstItem     = {FirstTestFun, self(), os:timestamp()},
  SecondItem    = {SecondTestFun, self(), os:timestamp()},
  gen_server:cast(test_lifo, unlock),
  valvex_queue:push(valvex_queue_lifo_backend, test_lifo, FirstItem),
  valvex_queue:push(valvex_queue_lifo_backend, test_lifo, SecondItem),
  ?assertEqual(2, valvex_queue:size(valvex_queue_lifo_backend, test_lifo)),
  ?assertMatch( {{value, SecondItem}, _}
              , valvex_queue:pop(valvex_queue_lifo_backend, test_lifo)
              ),
  ?assertMatch( {{value, FirstItem}, _}
              , valvex_queue:pop(valvex_queue_lifo_backend, test_lifo)
              ).

test_queue_push_r_fifo(suite)                         -> [];
test_queue_push_r_fifo({init, Config})                -> Config;
test_queue_push_r_fifo({'end', _Config})              -> ok;
test_queue_push_r_fifo(doc)                           ->
  ["Test r-pushing to the queue creates a queue item and handles it correctly"];
test_queue_push_r_fifo(Config) when is_list(Config)   ->
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  FirstItem     = {FirstTestFun, self(), os:timestamp()},
  SecondItem    = {SecondTestFun, self(), os:timestamp()},
  gen_server:cast(test_fifo, unlock),
  valvex_queue:push_r(valvex_queue_fifo_backend, test_fifo, FirstItem),
  valvex_queue:push_r(valvex_queue_fifo_backend, test_fifo, SecondItem),
  ?assertEqual(2, valvex_queue:size(valvex_queue_fifo_backend, test_fifo)),
  ?assertMatch( {{value, FirstItem}, _}
              , valvex_queue:pop_r(valvex_queue_fifo_backend, test_fifo)
              ),
  ?assertMatch( {{value, SecondItem}, _}
              , valvex_queue:pop_r(valvex_queue_fifo_backend, test_fifo)
              ).

test_queue_push_r_lifo(suite)                         -> [];
test_queue_push_r_lifo({init, Config})                -> Config;
test_queue_push_r_lifo({'end', _Config})              -> ok;
test_queue_push_r_lifo(doc)                           ->
  ["Test r-pushing to the queue creates a queue item and handles it correctly"];
test_queue_push_r_lifo(Config) when is_list(Config)   ->
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  FirstItem     = {FirstTestFun, self(), os:timestamp()},
  SecondItem    = {SecondTestFun, self(), os:timestamp()},
  gen_server:cast(test_lifo, unlock),
  valvex_queue:push_r(valvex_queue_lifo_backend, test_lifo, FirstItem),
  valvex_queue:push_r(valvex_queue_lifo_backend, test_lifo, SecondItem),
  ?assertEqual(2, valvex_queue:size(valvex_queue_lifo_backend, test_lifo)),
  ?assertMatch( {{value, SecondItem}, _}
              , valvex_queue:pop_r(valvex_queue_lifo_backend, test_lifo)
              ),
  ?assertMatch( {{value, FirstItem}, _}
              , valvex_queue:pop_r(valvex_queue_lifo_backend, test_lifo)
              ).

test_queue_consumer_fifo(suite)                         -> [];
test_queue_consumer_fifo({init, Config})                -> Config;
test_queue_consumer_fifo({'end', _Config})              -> ok;
test_queue_consumer_fifo(doc)                           ->
  ["Test the consumer works"];
test_queue_consumer_fifo(Config) when is_list(Config)   ->
  valvex_queue:start_consumer(valvex_queue_fifo_backend, test_fifo),
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  valvex:push(valvex, test_fifo, self(), FirstTestFun),
  valvex:push(valvex, test_fifo, self(), SecondTestFun),
  receive
    FirstItem ->
      ?assertEqual(FirstItem, "First Test Complete")
  end,
  receive
    SecondItem ->
      ?assertEqual(SecondItem, "Second Test Complete")
  end,
  valvex_queue:stop_consumer(valvex_queue_fifo_backend, test_fifo),
  ?assert(valvex_queue:is_locked(valvex_queue_fifo_backend, test_fifo)),
  valvex:push(valvex, test_fifo, self(), FirstTestFun),
  valvex:push(valvex, test_fifo, self(), SecondTestFun),
  timer:sleep(300),
  valvex_queue:unlock(valvex_queue_fifo_backend, test_fifo),
  ?assertEqual(0, valvex:get_queue_size(valvex, test_fifo)).

test_queue_consumer_lifo(suite)                         -> [];
test_queue_consumer_lifo({init, Config})                -> Config;
test_queue_consumer_lifo({'end', _Config})              -> ok;
test_queue_consumer_lifo(doc)                           ->
  ["Test the consumer works"];
test_queue_consumer_lifo(Config) when is_list(Config)   ->
  valvex_queue:start_consumer(valvex_queue_lifo_backend, test_lifo),
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  valvex:push(valvex, test_lifo, self(), FirstTestFun),
  valvex:push(valvex, test_lifo, self(), SecondTestFun),
  receive
    SecondItem ->
      ?assertEqual(SecondItem, "Second Test Complete")
  end,
  receive
    FirstItem ->
      ?assertEqual(FirstItem, "First Test Complete")
  end,
  valvex_queue:stop_consumer(valvex_queue_lifo_backend, test_lifo),
  valvex:push(valvex, test_lifo, self(), FirstTestFun),
  valvex:push(valvex, test_lifo, self(), SecondTestFun),
  timer:sleep(300),
  valvex_queue:unlock(valvex_queue_lifo_backend, test_lifo),
  ?assertEqual(0, valvex:get_queue_size(valvex, test_lifo)).

test_queue_tombstone_fifo(suite)                         -> [];
test_queue_tombstone_fifo({init, Config})                -> Config;
test_queue_tombstone_fifo({'end', _Config})              -> ok;
test_queue_tombstone_fifo(doc)                           ->
  ["Test that a tombstoned queue dies"];
test_queue_tombstone_fifo(Config) when is_list(Config)   ->
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  gen_server:cast(test_fifo, unlock),
  valvex:push(valvex, test_fifo, self(), FirstTestFun),
  valvex:push(valvex, test_fifo, self(), SecondTestFun),
  valvex:remove(valvex, test_fifo),
  ?assert(valvex_queue:is_tombstoned(valvex_queue_fifo_backend, test_fifo)),
  ?assert(is_process_alive(whereis(test_fifo))),
  valvex_queue:start_consumer(valvex_queue_fifo_backend, test_fifo),
  receive
    FirstItem ->
      ?assertEqual(FirstItem, "First Test Complete")
  end,
  receive
    SecondItem ->
      ?assertEqual(SecondItem, "Second Test Complete")
  end,
  timer:sleep(300),
  ?assertEqual(undefined, whereis(test_fifo)).

test_queue_tombstone_lifo(suite)                         -> [];
test_queue_tombstone_lifo({init, Config})                -> Config;
test_queue_tombstone_lifo({'end', _Config})              -> ok;
test_queue_tombstone_lifo(doc)                           ->
  ["Test that a tombstoned queue dies"];
test_queue_tombstone_lifo(Config) when is_list(Config)   ->
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  gen_server:cast(test_lifo, unlock),
  valvex:push(valvex, test_lifo, self(), FirstTestFun),
  valvex:push(valvex, test_lifo, self(), SecondTestFun),
  valvex:remove(valvex, test_lifo),
  ?assert(valvex_queue:is_tombstoned(valvex_queue_lifo_backend, test_lifo)),
  ?assert(is_process_alive(whereis(test_lifo))),
  valvex_queue:start_consumer(valvex_queue_lifo_backend, test_lifo),
  receive
    SecondItem ->
      ?assertEqual(SecondItem, "Second Test Complete")
  end,
  receive
    FirstItem ->
      ?assertEqual(FirstItem, "First Test Complete")
  end,
  timer:sleep(300),
  ?assertEqual(undefined, whereis(test_lifo)).

test_queue_lock_fifo(suite)                         -> [];
test_queue_lock_fifo({init, Config})                -> Config;
test_queue_lock_fifo({'end', _Config})              -> ok;
test_queue_lock_fifo(doc)                           ->
  ["Test that a locked queue has expected behaviour"];
test_queue_lock_fifo(Config) when is_list(Config)   ->
  ?assert(valvex_queue:is_locked(valvex_queue_fifo_backend, test_fifo)),
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  valvex:push(valvex, test_fifo, self(), FirstTestFun),
  valvex:push(valvex, test_fifo, self(), SecondTestFun),
  timer:sleep(300),
  valvex_queue:unlock(valvex_queue_fifo_backend, test_fifo),
  ?assertEqual(0, valvex:get_queue_size(valvex, test_fifo)),
  ?assertEqual(false
              , valvex_queue:is_locked( valvex_queue_fifo_backend
                                      , test_fifo
                                      )
              ),
  valvex:push(valvex, test_fifo, self(), FirstTestFun),
  valvex:push(valvex, test_fifo, self(), SecondTestFun),
  ?assertEqual(2, valvex:get_queue_size(valvex, test_fifo)),
  valvex_queue:pop(valvex_queue_fifo_backend, test_fifo),
  ?assertEqual(1, valvex:get_queue_size(valvex, test_fifo)),
  valvex_queue:pop(valvex_queue_fifo_backend, test_fifo),
  ?assertEqual(0, valvex:get_queue_size(valvex, test_fifo)),
  valvex_queue:lock(valvex_queue_fifo_backend, test_fifo),
  ?assert(valvex_queue:is_locked(valvex_queue_fifo_backend, test_fifo)).

test_queue_lock_lifo(suite)                         -> [];
test_queue_lock_lifo({init, Config})                -> Config;
test_queue_lock_lifo({'end', _Config})              -> ok;
test_queue_lock_lifo(doc)                           ->
  ["Test that a locked queue has expected behaviour"];
test_queue_lock_lifo(Config) when is_list(Config)   ->
  ?assert(valvex_queue:is_locked(valvex_queue_lifo_backend, test_lifo)),
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  valvex:push(valvex, test_lifo, self(), FirstTestFun),
  valvex:push(valvex, test_lifo, self(), SecondTestFun),
  timer:sleep(300),
  valvex_queue:unlock(valvex_queue_lifo_backend, test_lifo),
  ?assertEqual(0, valvex:get_queue_size(valvex, test_lifo)),
  ?assertEqual(false
              , valvex_queue:is_locked( valvex_queue_lifo_backend
                                      , test_lifo
                                      )
              ),
  valvex:push(valvex, test_lifo, self(), FirstTestFun),
  valvex:push(valvex, test_lifo, self(), SecondTestFun),
  ?assertEqual(2, valvex:get_queue_size(valvex, test_lifo)),
  valvex_queue:pop(valvex_queue_lifo_backend, test_lifo),
  ?assertEqual(1, valvex:get_queue_size(valvex, test_lifo)),
  valvex_queue:pop(valvex_queue_lifo_backend, test_lifo),
  ?assertEqual(0, valvex:get_queue_size(valvex, test_lifo)),
  valvex_queue:lock(valvex_queue_lifo_backend, test_lifo),
  ?assert(valvex_queue:is_locked(valvex_queue_lifo_backend, test_lifo)).

%%%_* Internals ================================================================

get_queue_from_config(Key, Config) ->
  {queues, Queues} = lists:keyfind(queues, 1, Config),
  Q                = lists:keyfind(Key, 1, Queues),
  ?assertNotEqual(false, Q),
  ?assert(is_tuple(Q)),
  Q.

get_child_spec_from_Q({ Key
                      , _Threshold
                      , _Timeout
                      , _Pushback
                      , Backend
                      } = Q) ->
  [Backend, Key, Q].

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
