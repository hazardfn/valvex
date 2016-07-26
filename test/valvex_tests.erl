%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc valvex tests
%%% @copyright 2016 Howard Beard-Marlowe
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%_* Module declaration =======================================================
-module(valvex_tests).

-export([ test_add/1
        , test_consumer/1
        , test_crossover/1
        , test_crossover_errors/1
        , test_get_available_workers/1
        , test_locking/1
        , test_pop/1
        , test_pop_r/1
        , test_pushback/1
        , test_remove/1
        , test_tombstone/1
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
  application:get_all_env(valvex) ++ Config.

end_per_suite(Config) ->
  Config.

init_per_testcase(TestCase, Config) ->
  valvex_test_forwarder:start_link(),
  HandlerPid = erlang:spawn(valvex_test_message_handler, loop, []),
  application:ensure_all_started(valvex),
  valvex:add_handler(valvex, valvex_message_event_handler, [HandlerPid]),
  ?MODULE:TestCase({init, Config}).

end_per_testcase(TestCase, Config)  ->
  application:stop(valvex),
  application:stop(cowboy),
  application:stop(lager),
  application:unload(lager),
  application:unload(cowboy),
  application:unload(valvex),
  gen_server:stop(valvex_test_forwarder),
  ?MODULE:TestCase({'end', Config}).

all() ->
  all(suite).
all(suite) ->
  [ test_add
  , test_consumer
  , test_crossover
  , test_crossover_errors
  , test_get_available_workers
  , test_locking
  , test_pop
  , test_pop_r
  , test_pushback
  , test_remove
  , test_tombstone
  ].

%%%_ * Tests ===================================================================
test_add(suite)                         -> [];
test_add({init, Config})                -> Config;
test_add({'end', _Config})              -> ok;
test_add(doc)                           ->
  ["Test we can add queues using the various options"];
test_add(Config) when is_list(Config)   ->
  Valvex = valvex,
  KeyLifo      = test_lifo,
  KeyFifo      = test_fifo,
  KeyNew       = test_new,
  KeyManual    = test_manual,
  NewConFun    = fun() ->
                     valvex_queue:is_consuming(valvex_queue_fifo_backend, KeyNew)
                 end,
  ManualConFun = fun() ->
                     valvex_queue:is_consuming(valvex_queue_fifo_backend, KeyManual)
                 end,
  %% Make sure the queues are started as expected
  ?assert(is_pid(whereis(KeyLifo))),
  ?assert(is_pid(whereis(KeyFifo))),
  %% Add a new queue
  ?assertEqual(ok, valvex:add(Valvex, { KeyNew
                                      , {threshold, 3000}
                                      , {timeout, 20, seconds}
                                      , {pushback, 20, seconds}
                                      , {poll_rate, 3000, ms}
                                      , valvex_queue_fifo_backend
                                      })),
  ?assert(is_pid(whereis(KeyNew))),
  ?assert(NewConFun()),
  %% Try adding it again and verify we get an error
  ?assertEqual({error, key_not_unique}, valvex:add(Valvex, { KeyNew
                                                           , {threshold, 3000}
                                                           , {timeout, 20, seconds}
                                                           , {pushback, 20, seconds}
                                                           , {poll_rate, 3000, ms}
                                                           , valvex_queue_fifo_backend
                                                           })),
  %% Add a manual_start queue and verify the consumer is dead
  ?assertEqual(ok, valvex:add(Valvex, { KeyManual
                                      , {threshold, 3000}
                                      , {timeout, 20, seconds}
                                      , {pushback, 20, seconds}
                                      , {poll_rate, 3000, ms}
                                      , valvex_queue_fifo_backend
                                      }, manual_start)),
  ?assertEqual(false, ManualConFun()).

test_consumer(suite)                         -> [];
test_consumer({init, Config})                -> Config;
test_consumer({'end', _Config})              -> ok;
test_consumer(doc)                           ->
  ["Test we can add queues using the various options"];
test_consumer(Config) when is_list(Config)   ->
  Valvex  = valvex,
  KeyLifo = test_lifo,
  KeyFifo = test_fifo,
  WorkFun = fun() -> timer:sleep(3000) end,
  LifoSizeFun = fun() -> valvex:get_queue_size(Valvex, KeyLifo) end,
  FifoSizeFun = fun() -> valvex:get_queue_size(Valvex, KeyFifo) end,
  LifoPushFun = fun(_N) -> valvex:push(Valvex, KeyLifo, WorkFun) end,
  FifoPushFun = fun(_N) -> valvex:push(Valvex, KeyFifo, WorkFun) end,
  %% Make sure the queues are started as expected
  ?assert(is_pid(whereis(KeyLifo))),
  ?assert(is_pid(whereis(KeyFifo))),
  %% Ensure the consumer is started
  ?assert(valvex_queue:is_consuming(valvex_queue_lifo_backend, KeyLifo)),
  ?assert(valvex_queue:is_consuming(valvex_queue_fifo_backend, KeyFifo)),
  %% Push some work and monitor to ensure the queue returns to 0
  Seq = lists:seq(0, 10),
  lists:foreach(LifoPushFun, Seq),
  lists:foreach(FifoPushFun, Seq),
  ?assertEqual(ok, do_until(LifoSizeFun, 0, 999999)),
  ?assertEqual(ok, do_until(FifoSizeFun, 0, 999999)),
  %% Ensure stopping the consumer twice doesn't cause errors
  ?assertEqual(ok, valvex_queue:stop_consumer(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(ok, valvex_queue:stop_consumer(valvex_queue_fifo_backend, KeyFifo)),
  ?assertEqual(ok, valvex_queue:stop_consumer(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(ok, valvex_queue:stop_consumer(valvex_queue_fifo_backend, KeyFifo)),
  ?assertEqual(false, valvex_queue:is_consuming(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(false, valvex_queue:is_consuming(valvex_queue_fifo_backend, KeyFifo)),
  %% Ensure starting the consumer twice doesn't cause errors
  ?assertEqual(ok, valvex_queue:start_consumer(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(ok, valvex_queue:start_consumer(valvex_queue_fifo_backend, KeyFifo)),
  ?assertEqual(ok, valvex_queue:start_consumer(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(ok, valvex_queue:start_consumer(valvex_queue_fifo_backend, KeyFifo)),
  ?assertEqual(true, valvex_queue:is_consuming(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(true, valvex_queue:is_consuming(valvex_queue_fifo_backend, KeyFifo)).

test_crossover(suite)                         -> [];
test_crossover({init, Config})                -> Config;
test_crossover({'end', _Config})              -> ok;
test_crossover(doc)                           ->
  ["Test we can change queue settings"];
test_crossover(Config) when is_list(Config)   ->
  Valvex = valvex,
  KeyLifo = test_lifo,
  KeyFifo = test_fifo,
  RawLifoFun = fun() ->
                   gen_server:call(Valvex, {get_raw_queue, KeyLifo})
               end,
  RawFifoFun = fun() ->
                   gen_server:call(Valvex, {get_raw_queue, KeyFifo})
               end,
  %% Make sure the queues are started as expected
  ?assert(is_pid(whereis(KeyLifo))),
  ?assert(is_pid(whereis(KeyFifo))),
  %% Get the raw queues for comparison
  RawQLifo = RawLifoFun(),
  RawQFifo = RawFifoFun(),
  %% Set new parameters and initiate a crossover
  UpdatedQLifo = { KeyLifo
                 , {threshold, 3000}
                 , {timeout, 20, seconds}
                 , {pushback, 20, seconds}
                 , {poll_rate, 3000, ms}
                 , valvex_queue_lifo_backend
                 },
  ?assertNotEqual(RawQLifo, UpdatedQLifo),
  UpdatedQFifo = { KeyFifo
                 , {threshold, 3000}
                 , {timeout, 20, seconds}
                 , {pushback, 20, seconds}
                 , {poll_rate, 3000, ms}
                 , valvex_queue_fifo_backend
                 },
  ?assertNotEqual(RawQFifo, UpdatedQFifo),
  valvex:add(Valvex, UpdatedQLifo, crossover_on_existing),
  valvex:add(Valvex, UpdatedQFifo, crossover_on_existing),
  %% Verify the queues are updated
  ?assertEqual(ok, do_until(RawLifoFun, UpdatedQLifo, 999999)),
  ?assertEqual(ok, do_until(RawFifoFun, UpdatedQFifo, 999999)).

test_crossover_errors(suite)                         -> [];
test_crossover_errors({init, Config})                -> Config;
test_crossover_errors({'end', _Config})              -> ok;
test_crossover_errors(doc)                           ->
  ["Check that certain types of crossovers are not allowed"];
test_crossover_errors(Config) when is_list(Config)   ->
  Valvex = valvex,
  KeyLifo = test_lifo,
  KeyFifo = test_fifo,
  RawLifoFun = fun() ->
                   gen_server:call(Valvex, {get_raw_queue, KeyLifo})
               end,
  RawFifoFun = fun() ->
                   gen_server:call(Valvex, {get_raw_queue, KeyFifo})
               end,
  %% Make sure the queues are started as expected
  ?assert(is_pid(whereis(KeyLifo))),
  ?assert(is_pid(whereis(KeyFifo))),
  %% Get the raw queues for comparison
  RawQLifo = RawLifoFun(),
  RawQFifo = RawFifoFun(),
  %% Set new illegal parameters and initiate a crossover
  UpdatedKeyQLifo = { test_lifo_new
                    , {threshold, 3000}
                    , {timeout, 20, seconds}
                    , {pushback, 20, seconds}
                    , {poll_rate, 3000, ms}
                    , valvex_queue_lifo_backend
                    },
  UpdatedBackendQLifo = { test_lifo
                        , {threshold, 3000}
                        , {timeout, 20, seconds}
                        , {pushback, 20, seconds}
                        , {poll_rate, 3000, ms}
                        , valvex_queue_fifo_backend
                        },
  UpdatedBothQLifo = { test_lifo_other
                     , {threshold, 3000}
                     , {timeout, 20, seconds}
                     , {pushback, 20, seconds}
                     , {poll_rate, 3000, ms}
                     , valvex_queue_fifo_backend
                     },
  ?assertNotEqual(RawQLifo, UpdatedKeyQLifo),
  ?assertNotEqual(RawQLifo, UpdatedBackendQLifo),
  ?assertNotEqual(RawQLifo, UpdatedBothQLifo),
  UpdatedKeyQFifo = { test_fifo_new
                    , {threshold, 3000}
                    , {timeout, 20, seconds}
                    , {pushback, 20, seconds}
                    , {poll_rate, 3000, ms}
                    , valvex_queue_fifo_backend
                    },
  UpdatedBackendQFifo = { test_fifo
                        , {threshold, 3000}
                        , {timeout, 20, seconds}
                        , {pushback, 20, seconds}
                        , {poll_rate, 3000, ms}
                        , valvex_queue_lifo_backend
                        },
  UpdatedBothQFifo = { test_fifo_other
                     , {threshold, 3000}
                     , {timeout, 20, seconds}
                     , {pushback, 20, seconds}
                     , {poll_rate, 3000, ms}
                     , valvex_queue_lifo_backend
                     },
  ?assertNotEqual(RawQFifo, UpdatedKeyQFifo),
  ?assertNotEqual(RawQFifo, UpdatedBackendQFifo),
  ?assertNotEqual(RawQFifo, UpdatedBothQFifo),
  %% Trigger the update and hope for errors in some of the cases
  %% A new key is basically a request for a new queue, it will be handled
  %% as such
  ?assertEqual( ok
              , valvex:add(Valvex, UpdatedKeyQLifo, crossover_on_existing)),
  %% A new backend is tricky to crossover without losing data so this is
  %% not supported
  ?assertEqual( {error, backend_key_crossover_not_supported}
              , valvex:add(Valvex, UpdatedBackendQLifo, crossover_on_existing)),
  %% Updating both is basically a request for a new queue.
  ?assertEqual( ok
              , valvex:add(Valvex, UpdatedBothQLifo, crossover_on_existing)),

  %% A new key is basically a request for a new queue, it will be handled
  %% as such
  ?assertEqual( ok
              , valvex:add(Valvex, UpdatedKeyQFifo, crossover_on_existing)),
  %% A new backend is tricky to crossover without losing data so this is
  %% not supported
  ?assertEqual( {error, backend_key_crossover_not_supported}
              , valvex:add(Valvex, UpdatedBackendQFifo, crossover_on_existing)),
  %% Updating both is basically a request for a new queue.
  ?assertEqual( ok
              , valvex:add(Valvex, UpdatedBothQFifo, crossover_on_existing)),

  %% Verify the queues are the same as when we started
  ?assertEqual(ok, do_until(RawLifoFun, RawQLifo, 999999)),
  ?assertEqual(ok, do_until(RawFifoFun, RawQFifo, 999999)).

test_get_available_workers(suite)                         -> [];
test_get_available_workers({init, Config})                -> Config;
test_get_available_workers({'end', _Config})              -> ok;
test_get_available_workers(doc)                           ->
  ["Test get available workers api call"];
test_get_available_workers(Config) when is_list(Config)   ->
  Valvex   = valvex,
  [Worker] = valvex:get_available_workers(Valvex),
  ?assert(is_pid(Worker)),
  ?assert(erlang:is_process_alive(Worker)),
  ?assertEqual(1, valvex:get_available_workers_count(Valvex)).

test_locking(suite)                         -> [];
test_locking({init, Config})                -> Config;
test_locking({'end', _Config})              -> ok;
test_locking(doc)                           ->
  ["Test locking mechanisms"];
test_locking(Config) when is_list(Config)   ->
  Valvex      = valvex,
  KeyLifo     = test_lifo,
  KeyFifo     = test_fifo,
  WorkFun     = fun() ->
                    timer:sleep(1000)
                end,
  LifoConFun  = fun() ->
                    valvex_queue:is_consuming(valvex_queue_lifo_backend, KeyLifo)
                end,
  LifoSizeFun = fun() ->
                    valvex:get_queue_size(Valvex, KeyLifo)
                end,
  FifoConFun  = fun() ->
                    valvex_queue:is_consuming(valvex_queue_fifo_backend, KeyFifo)
                end,
  FifoSizeFun = fun() ->
                    valvex:get_queue_size(Valvex, KeyFifo)
                end,
  %% Make sure the queues are started as expected
  ?assert(is_pid(whereis(KeyLifo))),
  ?assert(is_pid(whereis(KeyFifo))),
  %% Lock both the queues
  ?assertEqual(ok, valvex_queue:lock(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(ok, valvex_queue:lock(valvex_queue_fifo_backend, KeyFifo)),
  ?assert(valvex_queue:is_locked(valvex_queue_lifo_backend, KeyLifo)),
  ?assert(valvex_queue:is_locked(valvex_queue_fifo_backend, KeyFifo)),
  %% Check pushing to a locked queue leaves it empty
  ?assertEqual(ok, valvex:push(Valvex, KeyLifo, WorkFun)),
  ?assertEqual(ok, valvex:push(Valvex, KeyFifo, WorkFun)),
  ?assertEqual(0, valvex:get_queue_size(Valvex, KeyLifo)),
  ?assertEqual(0, valvex:get_queue_size(Valvex, KeyFifo)),
  %% Test we can unlock the queues
  ?assertEqual(ok, valvex_queue:unlock(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(ok, valvex_queue:unlock(valvex_queue_fifo_backend, KeyFifo)),
  ?assertEqual(false, valvex_queue:is_locked(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(false, valvex_queue:is_locked(valvex_queue_fifo_backend, KeyFifo)),
  %% Test once they are unlocked they can be pushed to
  ?assertEqual(ok, valvex_queue:stop_consumer(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(ok, valvex_queue:stop_consumer(valvex_queue_fifo_backend, KeyFifo)),
  ?assertEqual(ok, do_until(LifoConFun, false, 999999)),
  ?assertEqual(ok, do_until(FifoConFun, false, 999999)),
  ?assertEqual(ok, valvex:push(Valvex, KeyLifo, WorkFun)),
  ?assertEqual(ok, valvex:push(Valvex, KeyFifo, WorkFun)),
  ?assertEqual(ok, do_until(LifoSizeFun, 1, 999999)),
  ?assertEqual(ok, do_until(FifoSizeFun, 1, 999999)).

test_pop(suite)                         -> [];
test_pop({init, Config})                -> Config;
test_pop({'end', _Config})              -> ok;
test_pop(doc)                           ->
  ["Test pop works and pops in the expected order"];
test_pop(Config) when is_list(Config)   ->
  Valvex       = valvex,
  KeyLifo       = test_lifo,
  KeyFifo       = test_fifo,
  LifoSizeFun = fun() ->
                    valvex:get_queue_size(Valvex, KeyLifo)
                end,
  FifoSizeFun = fun() ->
                    valvex:get_queue_size(Valvex, KeyFifo)
                end,
  FirstWorkFun  = fun() -> 1 end,
  SecondWorkFun = fun() -> 2 end,
  %% Make sure the queues are started as expected
  ?assert(is_pid(whereis(KeyLifo))),
  ?assert(is_pid(whereis(KeyFifo))),
  %% Stop the consumer so we can pop manually
    ?assertEqual(ok, valvex_queue:stop_consumer(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(ok, valvex_queue:stop_consumer(valvex_queue_fifo_backend, KeyFifo)),
  ?assertEqual(false, valvex_queue:is_consuming(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(false, valvex_queue:is_consuming(valvex_queue_fifo_backend, KeyFifo)),
  %% Push work to the queues
  ?assertEqual(ok, valvex:push(Valvex, KeyLifo, FirstWorkFun)),
  ?assertEqual(ok, valvex:push(Valvex, KeyLifo, SecondWorkFun)),
  ?assertEqual(ok, valvex:push(Valvex, KeyFifo, FirstWorkFun)),
  ?assertEqual(ok, valvex:push(Valvex, KeyFifo, SecondWorkFun)),
  ?assertEqual(ok, do_until(LifoSizeFun, 2, 999999)),
  ?assertEqual(ok, do_until(FifoSizeFun, 2, 999999)),
  %% Pop queues and check correct order
  ?assertMatch({{value, {SecondWorkFun, _}}, _}, valvex_queue:pop(valvex_queue_lifo_backend, KeyLifo)),
  ?assertMatch({{value, {FirstWorkFun, _}}, _}, valvex_queue:pop(valvex_queue_lifo_backend, KeyLifo)),
  ?assertMatch({{value, {FirstWorkFun, _}}, _}, valvex_queue:pop(valvex_queue_fifo_backend, KeyFifo)),
  ?assertMatch({{value, {SecondWorkFun, _}}, _}, valvex_queue:pop(valvex_queue_fifo_backend, KeyFifo)).

test_pop_r(suite)                         -> [];
test_pop_r({init, Config})                -> Config;
test_pop_r({'end', _Config})              -> ok;
test_pop_r(doc)                           ->
  ["Test pop_r is the reverse of pop"];
test_pop_r(Config) when is_list(Config)   ->
  Valvex       = valvex,
  KeyLifo       = test_lifo,
  KeyFifo       = test_fifo,
  LifoSizeFun = fun() ->
                    valvex:get_queue_size(Valvex, KeyLifo)
                end,
  FifoSizeFun = fun() ->
                    valvex:get_queue_size(Valvex, KeyFifo)
                end,
  FirstWorkFun  = fun() -> 1 end,
  SecondWorkFun = fun() -> 2 end,
  %% Make sure the queues are started as expected
  ?assert(is_pid(whereis(KeyLifo))),
  ?assert(is_pid(whereis(KeyFifo))),
  %% Stop the consumer so we can pop manually
    ?assertEqual(ok, valvex_queue:stop_consumer(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(ok, valvex_queue:stop_consumer(valvex_queue_fifo_backend, KeyFifo)),
  ?assertEqual(false, valvex_queue:is_consuming(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(false, valvex_queue:is_consuming(valvex_queue_fifo_backend, KeyFifo)),
  %% Push work to the queues
  ?assertEqual(ok, valvex:push(Valvex, KeyLifo, FirstWorkFun)),
  ?assertEqual(ok, valvex:push(Valvex, KeyLifo, SecondWorkFun)),
  ?assertEqual(ok, valvex:push(Valvex, KeyFifo, FirstWorkFun)),
  ?assertEqual(ok, valvex:push(Valvex, KeyFifo, SecondWorkFun)),
  ?assertEqual(ok, do_until(LifoSizeFun, 2, 999999)),
  ?assertEqual(ok, do_until(FifoSizeFun, 2, 999999)),
  %% Pop queues and check correct order
  ?assertMatch({{value, {FirstWorkFun, _}}, _}, valvex_queue:pop_r(valvex_queue_lifo_backend, KeyLifo)),
  ?assertMatch({{value, {SecondWorkFun, _}}, _}, valvex_queue:pop_r(valvex_queue_lifo_backend, KeyLifo)),
  ?assertMatch({{value, {SecondWorkFun, _}}, _}, valvex_queue:pop_r(valvex_queue_fifo_backend, KeyFifo)),
  ?assertMatch({{value, {FirstWorkFun, _}}, _}, valvex_queue:pop_r(valvex_queue_fifo_backend, KeyFifo)).

test_pushback(suite)                         -> [];
test_pushback({init, Config})                -> Config;
test_pushback({'end', _Config})              -> ok;
test_pushback(doc)                           ->
  ["Test pushback works"];
test_pushback(Config) when is_list(Config)   ->
  Valvex  = valvex,
  KeyLifo = test_lifo,
  KeyFifo = test_fifo,
  {_, BeforeSeconds, _} = os:timestamp(),
  valvex:add_handler(valvex, valvex_message_event_handler, [self()]),
  %% Begin pushback
  valvex:pushback(Valvex, KeyLifo),
  receive
    {threshold_hit, _} ->
      ok;
    _ -> ok
  end,
  valvex:pushback(Valvex, KeyFifo),
  receive
    {threshold_hit, _} ->
      ok;
    _ -> ok
  end,
  valvex:remove_handler(Valvex, valvex_message_event_handler, []),
  %% Compare time
  {_, CurrentSeconds, _} = os:timestamp(),
  Diff = CurrentSeconds - BeforeSeconds,
  ?assert(Diff >= 2).

test_remove(suite)                         -> [];
test_remove({init, Config})                -> Config;
test_remove({'end', _Config})              -> ok;
test_remove(doc)                           ->
  ["Test we can remove queues and all the possible scenarios"];
test_remove(Config) when is_list(Config)   ->
  Valvex      = valvex,
  KeyLifo     = test_lifo,
  KeyFifo     = test_fifo,
  KeyPBTest   = test_threshold_pushback,
  RawLifoFun  = fun() ->
                    gen_server:call(Valvex, {get_raw_queue, KeyLifo})
                end,
  LifoSizeFun = fun() ->
                    valvex:get_queue_size(Valvex, KeyLifo)
                end,
  LifoConFun  = fun() ->
                    valvex_queue:is_consuming(valvex_queue_lifo_backend, KeyLifo)
                end,
  RawFifoFun  = fun() ->
                    gen_server:call(Valvex, {get_raw_queue, KeyFifo})
                end,
  FifoSizeFun = fun() ->
                    valvex:get_queue_size(Valvex, KeyFifo)
                end,
  FifoConFun  = fun() ->
                    valvex_queue:is_consuming(valvex_queue_fifo_backend, KeyFifo)
                end,
  RawPBTestFun = fun() ->
                     gen_server:call(Valvex, {get_raw_queue, KeyPBTest})
                 end,
  PBTestConFun  = fun() ->
                      valvex_queue:is_consuming(valvex_queue_fifo_backend, KeyPBTest)
                  end,
  %% Make sure the queues are started as expected
  ?assert(is_pid(whereis(KeyLifo))),
  ?assert(is_pid(whereis(KeyFifo))),
  ?assert(is_pid(whereis(KeyPBTest))),
  %% Stop the consumer of the lifo queue so we can test it hangs around
  %% when a normal remove is done
  ?assertEqual(ok, valvex_queue:stop_consumer(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(ok, do_until(LifoConFun, false, 999999)),
  ?assertEqual(ok, valvex:push(Valvex, KeyLifo, RawLifoFun)),
  ?assertEqual(ok, do_until(LifoSizeFun, 1, 999999)),
  ?assertEqual(ok, valvex:remove(Valvex, KeyLifo)),
  ?assertEqual(true, valvex_queue:is_tombstoned(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(ok, valvex_queue:start_consumer(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(ok, do_until(LifoConFun, true, 999999)),
  ?assertEqual(ok, do_until(LifoSizeFun, 0, 999999)),
  ?assertEqual(ok, do_until(RawLifoFun, {error, key_not_found}, 999999)),
  %% Stop the consumer of the fifo queue so we can test locking
  ?assertEqual(ok, valvex_queue:stop_consumer(valvex_queue_fifo_backend, KeyFifo)),
  ?assertEqual(ok, do_until(FifoConFun, false, 9999999)),
  ?assertEqual(ok, valvex:push(Valvex, KeyFifo, RawFifoFun)),
  ?assertEqual(ok, do_until(FifoSizeFun, 1, 9999999)),
  ?assertEqual(ok, valvex:remove(Valvex, KeyFifo, lock_queue)),
  ?assert(valvex_queue:is_locked(valvex_queue_fifo_backend, KeyFifo)),
  %% Push work to the PBTest queue so we can be sure force remove doesn't care
  ?assertEqual(ok, valvex_queue:stop_consumer(valvex_queue_fifo_backend, KeyPBTest)),
  ?assertEqual(ok, do_until(PBTestConFun, false, 999999)),
  ?assertEqual(ok, valvex:push(Valvex, KeyPBTest, RawPBTestFun)),
  ?assertEqual(ok, do_until(FifoSizeFun, 1, 9999999)),
  ?assertEqual(ok, valvex:remove(Valvex, KeyPBTest, force_remove)),
  ?assertEqual(ok, do_until(RawPBTestFun, {error, key_not_found}, 999999)).

test_tombstone(suite)                         -> [];
test_tombstone({init, Config})                -> Config;
test_tombstone({'end', _Config})              -> ok;
test_tombstone(doc)                           ->
  ["Test tombstone mechanisms"];
test_tombstone(Config) when is_list(Config)   ->
  Valvex     = valvex,
  KeyLifo    = test_lifo,
  KeyFifo    = test_fifo,
  RawLifoFun = fun() ->
                   gen_server:call(Valvex, {get_raw_queue, KeyLifo})
               end,
  RawFifoFun = fun() ->
                   gen_server:call(Valvex, {get_raw_queue, KeyFifo})
               end,
  %% Make sure the queues are started as expected
  ?assert(is_pid(whereis(KeyLifo))),
  ?assert(is_pid(whereis(KeyFifo))),
  %% Tombstone both queues
  ?assertEqual(ok, valvex_queue:tombstone(valvex_queue_lifo_backend, KeyLifo)),
  ?assertEqual(ok, valvex_queue:tombstone(valvex_queue_fifo_backend, KeyFifo)),
  ?assert(valvex_queue:is_tombstoned(valvex_queue_lifo_backend, KeyLifo)),
  ?assert(valvex_queue:is_tombstoned(valvex_queue_fifo_backend, KeyFifo)),
  ?assertEqual(ok, do_until(RawLifoFun, {error, key_not_found}, 999999)),
  ?assertEqual(ok, do_until(RawFifoFun, {error, key_not_found}, 999999)).

do_until(Fun, ExpectedResult, 0) ->
  throw({unexpected_result, Fun(), ExpectedResult});
do_until(Fun, ExpectedResult, N) ->
  case Fun() of
    ExpectedResult ->
      lager:info("Expected Result was given: ~p", [ExpectedResult]),
      ok;
    Other              ->
      lager:info("Unxpected Result was given attempting again: ~p", [Other]),
      do_until(Fun, ExpectedResult, N-1)
  end.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
