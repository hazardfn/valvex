%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc valvex tests
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
  [{timetrap, {seconds, 10}}].

init_per_suite(Config) ->
  Config.
end_per_suite(Config) ->
  Config.

init_per_testcase(TestCase, Config) ->
  application:ensure_all_started(valvex),
  valvex:add_handler(valvex, valvex_message_event_handler, [self()]),
  valvex_queue:stop_consumer(valvex_queue_fifo_backend, test_fifo),
  ok = queue_consumer_stopped(),
  valvex_queue:stop_consumer(valvex_queue_lifo_backend, test_lifo),
  ok = queue_consumer_stopped(),
  valvex:remove_handler(valvex, valvex_message_event_handler, []),
  ?MODULE:TestCase({init, Config}).

end_per_testcase(TestCase, Config)  ->
  application:stop(valvex),
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
  valvex:add_handler(valvex, valvex_message_event_handler, [self()]),
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  FirstItem     = {FirstTestFun, os:timestamp()},
  SecondItem    = {SecondTestFun, os:timestamp()},
  valvex_queue:unlock(valvex_queue_fifo_backend, test_fifo),
  ok = queue_unlocked(),
  valvex_queue:push(valvex_queue_fifo_backend, test_fifo, FirstItem),
  ok = push_flow_unlocked(FirstTestFun, false),
  valvex_queue:push(valvex_queue_fifo_backend, test_fifo, SecondItem),
  ok = push_flow_unlocked(SecondTestFun, false),
  ?assertEqual(2, valvex_queue:size(valvex_queue_fifo_backend, test_fifo)),
  ?assertMatch( {{value, FirstItem}, _}
              , valvex_queue:pop(valvex_queue_fifo_backend, test_fifo)
              ),
  ok = queue_popped(FirstTestFun, false),
  ?assertMatch( {{value, SecondItem}, _}
              , valvex_queue:pop(valvex_queue_fifo_backend, test_fifo)
              ),
  ok = queue_popped(SecondTestFun, false),
  valvex:remove_handler(valvex, valvex_message_event_handler, []).

test_queue_push_lifo(suite)                         -> [];
test_queue_push_lifo({init, Config})                -> Config;
test_queue_push_lifo({'end', _Config})              -> ok;
test_queue_push_lifo(doc)                           ->
  ["Test pushing to the queue creates a queue item and handles it correctly"];
test_queue_push_lifo(Config) when is_list(Config)   ->
  valvex:add_handler(valvex, valvex_message_event_handler, [self()]),
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  FirstItem     = {FirstTestFun, os:timestamp()},
  SecondItem    = {SecondTestFun, os:timestamp()},
  valvex_queue:unlock(valvex_queue_lifo_backend, test_lifo),
  ok = queue_unlocked(),
  valvex_queue:push(valvex_queue_lifo_backend, test_lifo, FirstItem),
  ok = push_flow_unlocked(FirstTestFun, false),
  valvex_queue:push(valvex_queue_lifo_backend, test_lifo, SecondItem),
  ok = push_flow_unlocked(SecondTestFun, false),
  ?assertEqual(2, valvex_queue:size(valvex_queue_lifo_backend, test_lifo)),
  ?assertMatch( {{value, SecondItem}, _}
              , valvex_queue:pop(valvex_queue_lifo_backend, test_lifo)
              ),
  ok = queue_popped(SecondTestFun, false),
  ?assertMatch( {{value, FirstItem}, _}
              , valvex_queue:pop(valvex_queue_lifo_backend, test_lifo)
              ),
  ok = queue_popped(FirstTestFun, false),
  valvex:remove_handler(valvex, valvex_message_event_handler, []).

test_queue_push_r_fifo(suite)                         -> [];
test_queue_push_r_fifo({init, Config})                -> Config;
test_queue_push_r_fifo({'end', _Config})              -> ok;
test_queue_push_r_fifo(doc)                           ->
  ["Test r-pushing to the queue creates a queue item and handles it correctly"];
test_queue_push_r_fifo(Config) when is_list(Config)   ->
  valvex:add_handler(valvex, valvex_message_event_handler, [self()]),
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  FirstItem     = {FirstTestFun, os:timestamp()},
  SecondItem    = {SecondTestFun, os:timestamp()},
  valvex_queue:unlock(valvex_queue_fifo_backend, test_fifo),
  ok = queue_unlocked(),
  valvex_queue:push_r(valvex_queue_fifo_backend, test_fifo, FirstItem),
  ok = push_flow_unlocked(FirstTestFun, true),
  valvex_queue:push_r(valvex_queue_fifo_backend, test_fifo, SecondItem),
  ok = push_flow_unlocked(SecondTestFun, true),
  ?assertEqual(2, valvex_queue:size(valvex_queue_fifo_backend, test_fifo)),
  ?assertMatch( {{value, FirstItem}, _}
              , valvex_queue:pop_r(valvex_queue_fifo_backend, test_fifo)
              ),
  ok = queue_popped(FirstTestFun, true),
  ?assertMatch( {{value, SecondItem}, _}
              , valvex_queue:pop_r(valvex_queue_fifo_backend, test_fifo)
              ),
  ok = queue_popped(SecondTestFun, true),
  valvex:remove_handler(valvex, valvex_message_event_handler, []).

test_queue_push_r_lifo(suite)                         -> [];
test_queue_push_r_lifo({init, Config})                -> Config;
test_queue_push_r_lifo({'end', _Config})              -> ok;
test_queue_push_r_lifo(doc)                           ->
  ["Test r-pushing to the queue creates a queue item and handles it correctly"];
test_queue_push_r_lifo(Config) when is_list(Config)   ->
  valvex:add_handler(valvex, valvex_message_event_handler, [self()]),
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  FirstItem     = {FirstTestFun, os:timestamp()},
  SecondItem    = {SecondTestFun, os:timestamp()},
  valvex_queue:unlock(valvex_queue_lifo_backend, test_lifo),
  ok = queue_unlocked(),
  valvex_queue:push_r(valvex_queue_lifo_backend, test_lifo, FirstItem),
  ok = push_flow_unlocked(FirstTestFun, true),
  valvex_queue:push_r(valvex_queue_lifo_backend, test_lifo, SecondItem),
  ok = push_flow_unlocked(SecondTestFun, true),
  ?assertEqual(2, valvex_queue:size(valvex_queue_lifo_backend, test_lifo)),
  ?assertMatch( {{value, SecondItem}, _}
              , valvex_queue:pop_r(valvex_queue_lifo_backend, test_lifo)
              ),
  ok = queue_popped(SecondTestFun, true),
  ?assertMatch( {{value, FirstItem}, _}
              , valvex_queue:pop_r(valvex_queue_lifo_backend, test_lifo)
              ),
  ok = queue_popped(FirstTestFun, true),
  valvex:remove_handler(valvex, valvex_message_event_handler, []).

test_queue_consumer_fifo(suite)                         -> [];
test_queue_consumer_fifo({init, Config})                -> Config;
test_queue_consumer_fifo({'end', _Config})              -> ok;
test_queue_consumer_fifo(doc)                           ->
  ["Test the consumer works"];
test_queue_consumer_fifo(Config) when is_list(Config)   ->
  valvex:add_handler(valvex, valvex_message_event_handler, [self()]),
  valvex_queue:start_consumer(valvex_queue_fifo_backend, test_fifo),
  ok = queue_consumer_started(),
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  valvex:push(valvex, test_fifo, FirstTestFun),
  ok = push_flow_unlocked(FirstTestFun, false),
  valvex:push(valvex, test_fifo, SecondTestFun),
  ok = push_flow_unlocked(SecondTestFun, false),
  ok = queue_popped(FirstTestFun, false),
  receive
    FirstItem ->
      ?assertEqual(FirstItem, {result, "First Test Complete"})
  end,
  ok = queue_popped(SecondTestFun, false),
  receive
    SecondItem ->
      ?assertEqual(SecondItem, {result, "Second Test Complete"})
  end,
  valvex_queue:stop_consumer(valvex_queue_fifo_backend, test_fifo),
  ok = queue_consumer_stopped(),
  valvex_queue:lock(valvex_queue_fifo_backend, test_fifo),
  receive
    {queue_locked, _} ->
      ok
  end,
  ?assert(valvex_queue:is_locked(valvex_queue_fifo_backend, test_fifo)),
  valvex:push(valvex, test_fifo, FirstTestFun),
  ok = push_flow_locked(FirstTestFun, false),
  valvex:push(valvex, test_fifo, SecondTestFun),
  ok = push_flow_locked(SecondTestFun, false),
  valvex_queue:unlock(valvex_queue_fifo_backend, test_fifo),
  ok = queue_unlocked(),
  ?assertEqual(0, wait_for_queue_size(test_fifo, valvex_queue_fifo_backend, 0)),
  valvex:remove_handler(valvex, valvex_message_event_handler, []).


test_queue_consumer_lifo(suite)                         -> [];
test_queue_consumer_lifo({init, Config})                -> Config;
test_queue_consumer_lifo({'end', _Config})              -> ok;
test_queue_consumer_lifo(doc)                           ->
  ["Test the consumer works"];
test_queue_consumer_lifo(Config) when is_list(Config)   ->
  valvex:add_handler(valvex, valvex_message_event_handler, [self()]),
  valvex_queue:start_consumer(valvex_queue_lifo_backend, test_lifo),
  ok = queue_consumer_started(),
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  valvex:push(valvex, test_lifo, FirstTestFun),
  ok = push_flow_unlocked(FirstTestFun, false),
  valvex:push(valvex, test_lifo, SecondTestFun),
  ok = push_flow_unlocked(SecondTestFun, false),
  ok = queue_popped(SecondTestFun, false),
  receive
    SecondItem ->
      ?assertEqual(SecondItem, {result, "Second Test Complete"})
  end,
  ok = queue_popped(FirstTestFun, false),
  receive
    FirstItem ->
      ?assertEqual(FirstItem, {result, "First Test Complete"})
  end,
  valvex_queue:stop_consumer(valvex_queue_lifo_backend, test_lifo),
  ok = queue_consumer_stopped(),
  valvex_queue:lock(valvex_queue_lifo_backend, test_lifo),
  receive
    {queue_locked, _} ->
      ok
  end,
  ?assert(valvex_queue:is_locked(valvex_queue_lifo_backend, test_lifo)),
  valvex:push(valvex, test_lifo, FirstTestFun),
  ok = push_flow_locked(FirstTestFun, false),
  valvex:push(valvex, test_lifo, SecondTestFun),
  ok = push_flow_locked(SecondTestFun, false),
  wait_for_queue_size(test_lifo, valvex_queue_lifo_backend, 0),
  valvex_queue:unlock(valvex_queue_lifo_backend, test_lifo),
  ok = queue_unlocked(),
  ?assertEqual(0, wait_for_queue_size(test_lifo, valvex_queue_lifo_backend, 0)),
  valvex:remove_handler(valvex, valvex_message_event_handler, []).

test_queue_tombstone_fifo(suite)                         -> [];
test_queue_tombstone_fifo({init, Config})                -> Config;
test_queue_tombstone_fifo({'end', _Config})              -> ok;
test_queue_tombstone_fifo(doc)                           ->
  ["Test that a tombstoned queue dies"];
test_queue_tombstone_fifo(Config) when is_list(Config)   ->
  valvex:add_handler(valvex, valvex_message_event_handler, [self()]),

  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  valvex_queue:unlock(valvex_queue_fifo_backend, test_fifo),
  ok = queue_unlocked(),
  valvex:push(valvex, test_fifo, FirstTestFun),
  ok = push_flow_unlocked(FirstTestFun, false),
  valvex:push(valvex, test_fifo, SecondTestFun),
  ok = push_flow_unlocked(SecondTestFun, false),
  valvex:remove(valvex, test_fifo),
  ok = queue_tombstoned(),
  ?assert(valvex_queue:is_tombstoned(valvex_queue_fifo_backend, test_fifo)),
  ?assert(is_process_alive(whereis(test_fifo))),
  valvex_queue:start_consumer(valvex_queue_fifo_backend, test_fifo),
  ok = queue_consumer_started(),
  ok = queue_popped(FirstTestFun, false),
  receive
    FirstItem ->
      ?assertEqual(FirstItem, {result, "First Test Complete"})
  end,
  ok = queue_popped(SecondTestFun, false),
  receive
    SecondItem ->
      ?assertEqual(SecondItem, {result, "Second Test Complete"})
  end,
  wait_until_killed(test_fifo),
  ?assertEqual(undefined, whereis(test_fifo)),
  valvex:remove_handler(valvex, valvex_message_event_handler, []).

test_queue_tombstone_lifo(suite)                         -> [];
test_queue_tombstone_lifo({init, Config})                -> Config;
test_queue_tombstone_lifo({'end', _Config})              -> ok;
test_queue_tombstone_lifo(doc)                           ->
  ["Test that a tombstoned queue dies"];
test_queue_tombstone_lifo(Config) when is_list(Config)   ->
  valvex:add_handler(valvex, valvex_message_event_handler, [self()]),

  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  valvex_queue:unlock(valvex_queue_lifo_backend, test_lifo),
  ok = queue_unlocked(),
  valvex:push(valvex, test_lifo, FirstTestFun),
  ok = push_flow_unlocked(FirstTestFun, false),
  valvex:push(valvex, test_lifo, SecondTestFun),
  ok = push_flow_unlocked(SecondTestFun, false),
  valvex:remove(valvex, test_lifo),
  ok = queue_tombstoned(),
  ?assert(valvex_queue:is_tombstoned(valvex_queue_lifo_backend, test_lifo)),
  ?assert(is_process_alive(whereis(test_lifo))),
  valvex_queue:start_consumer(valvex_queue_lifo_backend, test_lifo),
  ok = queue_consumer_started(),
  ok = queue_popped(SecondTestFun, false),
  receive
    SecondItem ->
      ?assertEqual(SecondItem, {result, "Second Test Complete"})
  end,
  ok = queue_popped(FirstTestFun, false),
  receive
    FirstItem ->
      ?assertEqual(FirstItem, {result, "First Test Complete"})
  end,
  wait_until_killed(test_lifo),
  ?assertEqual(undefined, whereis(test_lifo)),
  valvex:remove_handler(valvex, valvex_message_event_handler, []).

test_queue_lock_fifo(suite)                         -> [];
test_queue_lock_fifo({init, Config})                -> Config;
test_queue_lock_fifo({'end', _Config})              -> ok;
test_queue_lock_fifo(doc)                           ->
  ["Test that a locked queue has expected behaviour"];
test_queue_lock_fifo(Config) when is_list(Config)   ->
  valvex:add_handler(valvex, valvex_message_event_handler, [self()]),

  valvex_queue:lock(valvex_queue_fifo_backend, test_fifo),
  receive
    {queue_locked, _} ->
      ok
  end,
  ?assert(valvex_queue:is_locked(valvex_queue_fifo_backend, test_fifo)),
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  valvex:push(valvex, test_fifo, FirstTestFun),
  ok = push_flow_locked(FirstTestFun, false),
  valvex:push(valvex, test_fifo, SecondTestFun),
  ok = push_flow_locked(SecondTestFun, false),
  ?assertEqual( 0
              , monitor_queue_size( test_fifo
                                   , valvex_queue_fifo_backend
                                   , 0
                                   , 30
                                   )
              ),
  valvex_queue:unlock(valvex_queue_fifo_backend, test_fifo),
  ok = queue_unlocked(),
  ?assertEqual(false
              , valvex_queue:is_locked( valvex_queue_fifo_backend
                                      , test_fifo
                                      )
              ),
  valvex:push(valvex, test_fifo, FirstTestFun),
  ok = push_flow_unlocked(FirstTestFun, false),
  valvex:push(valvex, test_fifo, SecondTestFun),
  ok = push_flow_unlocked(SecondTestFun, false),
  ?assertEqual(2, wait_for_queue_size(test_fifo, valvex_queue_fifo_backend, 2)),
  valvex_queue:pop(valvex_queue_fifo_backend, test_fifo),
  ok = queue_popped(FirstTestFun, false),
  ?assertEqual(1, wait_for_queue_size(test_fifo, valvex_queue_fifo_backend, 1)),
  valvex_queue:pop(valvex_queue_fifo_backend, test_fifo),
  ok = queue_popped(SecondTestFun, false),
  ?assertEqual(0, wait_for_queue_size(test_fifo, valvex_queue_fifo_backend, 0)),
  valvex_queue:lock(valvex_queue_fifo_backend, test_fifo),
  ok = queue_locked(),
  ?assert(valvex_queue:is_locked(valvex_queue_fifo_backend, test_fifo)),
  valvex:remove_handler(valvex, valvex_message_event_handler, []).

test_queue_lock_lifo(suite)                         -> [];
test_queue_lock_lifo({init, Config})                -> Config;
test_queue_lock_lifo({'end', _Config})              -> ok;
test_queue_lock_lifo(doc)                           ->
  ["Test that a locked queue has expected behaviour"];
test_queue_lock_lifo(Config) when is_list(Config)   ->
  valvex:add_handler(valvex, valvex_message_event_handler, [self()]),

    valvex_queue:lock(valvex_queue_lifo_backend, test_lifo),
  receive
    {queue_locked, _} ->
      ok
  end,
  ?assert(valvex_queue:is_locked(valvex_queue_lifo_backend, test_lifo)),
  FirstTestFun  = fun() ->
                      "First Test Complete"
                  end,
  SecondTestFun = fun() ->
                      "Second Test Complete"
                  end,
  valvex:push(valvex, test_lifo, FirstTestFun),
  ok = push_flow_locked(FirstTestFun, false),
  valvex:push(valvex, test_lifo, SecondTestFun),
  ok = push_flow_locked(SecondTestFun, false),
  ?assertEqual( 0
              , monitor_queue_size( test_lifo
                                   , valvex_queue_lifo_backend
                                   , 0
                                   , 30
                                   )
              ),
  valvex_queue:unlock(valvex_queue_lifo_backend, test_lifo),
  ok = queue_unlocked(),
  ?assertEqual(false
              , valvex_queue:is_locked( valvex_queue_lifo_backend
                                      , test_lifo
                                      )
              ),
  valvex:push(valvex, test_lifo, FirstTestFun),
  ok = push_flow_unlocked(FirstTestFun, false),
  valvex:push(valvex, test_lifo, SecondTestFun),
  ok = push_flow_unlocked(SecondTestFun, false),
  ?assertEqual(2, wait_for_queue_size(test_lifo, valvex_queue_lifo_backend, 2)),
  valvex_queue:pop(valvex_queue_lifo_backend, test_lifo),
  ok = queue_popped(SecondTestFun, false),
  ?assertEqual(1, wait_for_queue_size(test_lifo, valvex_queue_lifo_backend, 1)),
  valvex_queue:pop(valvex_queue_lifo_backend, test_lifo),
  ok = queue_popped(FirstTestFun, false),
  ?assertEqual(0, wait_for_queue_size(test_lifo, valvex_queue_lifo_backend, 0)),
  valvex_queue:lock(valvex_queue_lifo_backend, test_lifo),
  ok = queue_locked(),
  ?assert(valvex_queue:is_locked(valvex_queue_lifo_backend, test_lifo)),
  valvex:remove_handler(valvex, valvex_message_event_handler, []).

%%%_* Event Flows ================================================================

queue_consumer_started() ->
  receive
    {queue_consumer_started, _} ->
      ok;
    _ ->
      throw(unexpected_message)
  end.

queue_tombstoned() ->
  receive
    {queue_tombstoned, _Q} ->
      ok;
    Msg ->
      throw({unexpected_message, Msg})
  end.

queue_consumer_stopped() ->
  receive
    {queue_consumer_stopped, _} ->
      ok;
    _ ->
      throw(unexpected_message)
  end.

queue_unlocked() ->
  receive
    {queue_unlocked, _} ->
      ok;
    Msg ->
      throw(Msg)
  end.

queue_locked() ->
  receive
    {queue_locked, _} ->
      ok;
    Msg ->
      throw(Msg)
  end.

push_flow_unlocked(_Item, Reversed) ->
  HandlerFun = case Reversed of
                 true ->
                   fun() ->
                       receive
                         {queue_push_r, _} ->
                           ok;
                         Msg1 ->
                           throw({unexpected_message, Msg1})
                       end,
                       receive
                         {push_complete, _} ->
                           ok;
                         Msg2 ->
                           throw({unexpected_message, Msg2})
                       end
                   end;
                 false ->
                   fun() ->
                       receive
                         {queue_push, _} ->
                           ok;
                         Msg1 ->
                           throw({unexpected_message, Msg1})
                       end,
                       receive
                         {push_complete, _} ->
                           ok;
                         Msg2 ->
                           throw({unexpected_message, Msg2})
                       end
                   end
               end,
  HandlerFun().

push_flow_locked(_Item, Reversed) ->
  HandlerFun = case Reversed of
                 true ->
                   fun() ->
                       receive
                         {push_to_locked_queue, _} ->
                           ok;
                         Msg ->
                           throw({"unexpected_message:", Msg})
                       end
                   end;
                 false ->
                   fun() ->
                       receive
                         {push_to_locked_queue, _} ->
                           ok;
                         Msg ->
                           throw({"unexpected_message:", Msg})
                       end
                   end
               end,
  HandlerFun().

queue_popped(_Item, Reversed) ->
  HandlerFun = case Reversed of
                 true ->
                   fun() ->
                       receive
                         {queue_popped_r, _Q} ->
                           ok;
                         Msg ->
                           throw({"unexpected_message:", Msg})
                       end
                   end;
                 false ->
                   fun() ->
                       receive
                         {queue_popped, _Q} ->
                           ok;
                         Msg ->
                           throw({"unexpected_message:", Msg})
                       end
                   end
               end,
  HandlerFun().

%%%_* Internals ================================================================

get_child_spec_from_Q({ Key
                      , _Threshold
                      , _Timeout
                      , _Pushback
                      , Backend
                      } = Q) ->
  [Backend, Key, Q].

wait_for_queue_size(Key, Backend, ExpectedSize) ->
  case valvex_queue:size(Backend, Key) of
    ExpectedSize ->
      ExpectedSize;
    _Other ->
      wait_for_queue_size(Key, Backend, ExpectedSize)
  end.

monitor_queue_size(Key, Backend, ExpectedSize, 0) ->
  case valvex_queue:size(Backend, Key) of
    ExpectedSize ->
      ExpectedSize;
    _Other ->
      error(queue_size_incorrect)
  end;
monitor_queue_size(Key, Backend, ExpectedSize, N) ->
  case valvex_queue:size(Backend, Key) of
    _Size ->
      monitor_queue_size(Key, Backend, ExpectedSize, N-1)
  end.

wait_until_killed(Key) ->
  case whereis(Key) of
    undefined ->
      ok;
    _Other ->
      wait_until_killed(Key)
  end.


%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
