%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc valvex tests
%%% @copyright 2016 Howard Beard-Marlowe
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%_* Module declaration =======================================================
-module(valvex_tests).

-export([ test_add_options/1
        , test_remove_options/1
        , test_pushback/1
        , test_timeout/1
        , test_misc_api/1
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
  [{timetrap, {seconds, 10}}].

init_per_suite(Config) ->
  Config ++
     [ {queues, [ { test_fifo
                  , {threshold, 1}
                  , {timeout, 1, seconds}
                  , {pushback, 5, seconds}
                  , {poll_rate, 100, ms}
                  , valvex_queue_fifo_backend
                  }
                , { test_lifo
                  , {threshold, 300}
                  , {timeout, 1, seconds}
                  , {pushback, 5, seconds}
                  , {poll_rate, 100, ms}
                  , valvex_queue_lifo_backend
                  }
                ]
       }
     , {pushback_enabled, true}
     , {workers, 1}
     , {event_handlers, []}
     ].
end_per_suite(Config) ->
  Config.

init_per_testcase(TestCase, Config) ->
  {ok, _VSupPid}      = valvex_sup:start_link(Config),
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
  [ test_add_options
  , test_remove_options
  , test_timeout
  , test_pushback
  , test_misc_api
  ].

%%%_ * Tests ===================================================================
test_add_options(suite)                         -> [];
test_add_options({init, Config})                -> Config;
test_add_options({'end', _Config})              -> ok;
test_add_options(doc)                           ->
  ["Test all of the add options behave as intended"];
test_add_options(Config) when is_list(Config)   ->
  ?assertEqual({error, key_not_unique}, valvex:add(valvex, { test_lifo
                                                           , {threshold, 3}
                                                           , {timeout, 10, seconds}
                                                           , {pushback, 10, seconds}
                                                           , {poll_rate, 100, ms}
                                                           , valvex_queue_lifo_backend
                                                           }, undefined)),
  valvex:add_handler(valvex, valvex_message_event_handler, [self()]),
  ?assertEqual(ok,  valvex:add(valvex, { test_lifo
                                       , {threshold, 200}
                                       , {timeout, 10, seconds}
                                       , {pushback, 10, seconds}
                                       , {poll_rate, 100, ms}
                                       , valvex_queue_lifo_backend
                                       }, crossover_on_existing)),

  NuQ = { test_lifo
        , {threshold, 200}
        , {timeout, 10, seconds}
        , {pushback, 10, seconds}
        , {poll_rate, 100, ms}
        , valvex_queue_lifo_backend
        },
  receive
    {queue_crossover, _, _} ->
      ?assertEqual(NuQ, gen_server:call(valvex, {get_raw_queue, test_lifo}))
  end,
  valvex:add(valvex, { random_queue
                     , {threshold, 200}
                     , {timeout, 10, seconds}
                     , {pushback, 10, seconds}
                     , {poll_rate, 100, ms}
                     , valvex_queue_lifo_backend
                     }),
  receive
    {queue_started, _} ->
      ok
  end,
  valvex:remove_handler(valvex, valvex_message_event_handler, []).

test_remove_options(suite)                         -> [];
test_remove_options({init, Config})                -> Config;
test_remove_options({'end', _Config})              -> ok;
test_remove_options(doc)                           ->
  ["Test all of the remove options behave as intended"];
test_remove_options(Config) when is_list(Config)   ->
  ?assertEqual(ok, valvex:remove(valvex, test_lifo, force_remove)),
  ?assertEqual({error, key_not_found}, gen_server:call(valvex, {get_raw_queue, test_lifo})),
  ?assertEqual(ok, valvex_queue:stop_consumer(valvex_queue_fifo_backend, test_fifo)),
  ?assertEqual(ok, valvex:push(valvex, test_fifo, fun() -> timer:sleep(1000) end)),
  ?assertEqual(ok, valvex:remove(valvex, test_fifo, lock_queue)),
  ?assert(valvex_queue:is_locked(valvex_queue_fifo_backend, test_fifo)),
  ?assert(valvex_queue:is_tombstoned(valvex_queue_fifo_backend, test_fifo)),
  ?assertMatch( { test_fifo
                  , {threshold, 1}
                  , {timeout, 1, seconds}
                  , {pushback, 5, seconds}
                  , {poll_rate, 100, ms}
                  , valvex_queue_fifo_backend
                  }, gen_server:call(valvex, {get_raw_queue, test_fifo})),
  ?assertEqual(1, valvex:get_queue_size(valvex, test_fifo)),
  ?assertEqual(ok, valvex_queue:start_consumer(valvex_queue_fifo_backend, test_fifo)),
  valvex:add_handler(valvex, valvex_message_event_handler, [self()]),
  receive
    {queue_popped, _, _} ->
      ok
  end,
  receive
    {queue_removed, test_fifo} ->
      ?assertMatch({error, key_not_found}, gen_server:call(valvex, {get_raw_queue, test_fifo}))
  end,
  valvex:remove_handler(valvex, valvex_message_event_handler, []).

test_pushback(suite)                         -> [];
test_pushback({init, Config})                -> Config;
test_pushback({'end', _Config})              -> ok;
test_pushback(doc)                           ->
  ["Test that the client gets pushed back"];
test_pushback(Config) when is_list(Config)   ->
  ?assertEqual(ok, valvex_queue:stop_consumer(valvex_queue_fifo_backend, test_fifo)),
  ?assertEqual(ok, valvex:push(valvex, test_fifo, fun() -> timer:sleep(1000) end)),
  ?assertEqual(ok, valvex:push(valvex, test_fifo, fun() -> timer:sleep(1000) end)),
  valvex:add_handler(valvex, valvex_message_event_handler, [self()]),
  receive
    {threshold_hit, _Key} ->
      ok
  end,
  valvex:remove_handler(valvex, valvex_message_event_handler, []).

test_timeout(suite)                         -> [];
test_timeout({init, Config})                -> Config;
test_timeout({'end', _Config})              -> ok;
test_timeout(doc)                           ->
  ["Test that when all workers are busy and the timeout is hit the message is received"];
test_timeout(Config) when is_list(Config)   ->
  Seq      = lists:seq(0, 3),
  SleepFun = fun() -> timer:sleep(1000) end,
  PushFun  = fun(_N) ->
                 ?assertEqual(ok, valvex:push(valvex, test_lifo, SleepFun))             end,
  TimeoutFun = fun() ->
                   receive
                     {timeout, Key} = _Event->
                       ?assertEqual(test_lifo, Key);
                     Other -> Other
                   end
               end,
  lists:foreach(PushFun, Seq),
  valvex:add_handler(valvex, valvex_message_event_handler, [self()]),
  do_until(TimeoutFun, ok),
  valvex:remove_handler(valvex, valvex_message_event_handler, []).

test_misc_api(suite)                         -> [];
test_misc_api({init, Config})                -> Config;
test_misc_api({'end', _Config})              -> ok;
test_misc_api(doc)                           ->
  ["Test the smaller misc api functions"];
test_misc_api(Config) when is_list(Config)   ->
  ok.


do_until(Fun, Value) ->
  case Fun() of
    Value ->
      Value;
    _Other ->
      do_until(Fun, Value)
  end.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
