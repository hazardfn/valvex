%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc valve tests
%%% @copyright 2015 Klarna AB
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%_* Module declaration =======================================================
-module(valvex_queue_tests).

-export([
          test_work_completes/1
        , test_threshold_hit/1
        , test_timeout_hit/1
        , test_available_workers/1
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
Config.

end_per_suite(Config) ->
Config.


init_per_testcase(TestCase, Config) ->
  Valvex           = valvex:start_link(get_params()),
  ValvexNoPushback = valvex:start_link(get_params_no_pushback()),
 ?MODULE:TestCase({init,   [ {test_pid, Valvex}
                           , {no_pushback_pid, ValvexNoPushback}
                             | Config
                           ]}).

end_per_testcase(TestCase, Config)  ->
  {_, Valvex}           = lists:keyfind(test_pid, 1, Config),
  {_, ValvexNoPushback} = lists:keyfind(no_pushback_pid, 1, Config),
  ?assertEqual(ok, gen_server:stop(Valvex)),
  ?assertEqual(ok, gen_server:stop(ValvexNoPushback)),
  ?MODULE:TestCase({'end', Config}).

all()      ->
  all(suite).
all(suite) ->
  [
    test_work_completes
  , test_threshold_hit
  , test_timeout_hit
  , test_available_workers
  ].

%%%_ * Tests ===================================================================
test_work_completes(suite)                         -> [];
test_work_completes({init, Config})                -> Config;
test_work_completes({'end', _Config})              -> ok;
test_work_completes(doc)                           ->
  ["Test we can send some work and we get a reasonable reply"];
test_work_completes(Config) when is_list(Config)   ->
  {_, Valvex} = lists:keyfind(test_pid, 1, Config),
  WorkFun = fun() ->
                timer:sleep(1000),
                {timer_run, 1000}
            end,
  push(Valvex, test_fifo, self(), WorkFun, 1),
  receive
    {timer_run, Value} ->
      ?assertEqual(Value, 1000);
    Err ->
      erlang:error(Err)
  end,
  push(Valvex, test_lifo, self(), WorkFun, 1),
  receive
    {timer_run, LifoValue} ->
      ?assertEqual(LifoValue, 1000);
    LifoErr ->
      erlang:error(LifoErr)
  end.
test_threshold_hit(suite)                          -> [];
test_threshold_hit({init, Config})                 -> Config;
test_threshold_hit({'end', _Config})               -> ok;
test_threshold_hit(doc)                            ->
    ["Test the threshold is hit"];
test_threshold_hit(Config) when is_list(Config)    ->
  {_, Valvex} = lists:keyfind(test_pid, 1, Config),
  WorkFun = fun() ->
                timer:sleep(3000),
                {timer_run, 3000}
            end,
  push(Valvex, test_fifo, self(), WorkFun, 13),
  ?assertEqual(receive_until_throttled(), {error, threshold_hit}),
  push(Valvex, test_lifo, self(), WorkFun, 13),
  ?assertEqual(receive_until_throttled(), {error, threshold_hit}).

test_timeout_hit(suite)                            -> [];
test_timeout_hit({init, Config})                   -> Config;
test_timeout_hit({'end', _Config})                 -> ok;
test_timeout_hit(doc)                              ->
    ["Test the timeout is hit"];
test_timeout_hit(Config) when is_list(Config)      ->
  {_, Valvex} = lists:keyfind(test_pid, 1, Config),
  WorkFun = fun() ->
                timer:sleep(5000),
                {timer_run, 5000}
            end,
  push(Valvex, test_fifo, self(), WorkFun, 11),
  ?assertEqual(receive_until_stale(), {error, timeout}),
  push(Valvex, test_lifo, self(), WorkFun, 11),
  ?assertEqual(receive_until_stale(), {error, timeout}).

test_available_workers(suite)                       -> [];
test_available_workers({init, Config})              -> Config;
test_available_workers({'end', _Config})            -> ok;
test_available_workers(doc)                         ->
    ["Test an available worker is consumed when work is pushed"];
test_available_workers(Config) when is_list(Config) ->
  {_, Valvex} = lists:keyfind(test_pid, 1, Config),
  Workers     = valvex:get_available_workers(Valvex),
  case is_list(Workers) of
    true  ->
      WorkerCount = valvex:get_available_workers_count(Valvex),
      ?assertEqual(length(Workers), WorkerCount),
      WorkFun     = fun() ->
                        timer:sleep(1000),
                        {timer_run, 1000}
                    end,
      push(Valvex, test_fifo, self(), WorkFun, 1),
      ?assertEqual(do_until_worker_state(Valvex, WorkerCount-1), true),
      ?assertEqual(do_until_worker_state(Valvex, WorkerCount), true),
      push(Valvex, test_lifo, self(), WorkFun, 1),
      ?assertEqual(do_until_worker_state(Valvex, WorkerCount-1), true),
      ?assertEqual(do_until_worker_state(Valvex, WorkerCount), true);
    false -> error(workers_not_a_list)
  end.

%%%_* Internals ================================================================
push(_Valvex, _Key, _Reply, _WorkFun, 0) ->
  ok;
push(Valvex, Key, Reply, WorkFun, N) ->
  valvex:push(Valvex, Key, Reply, WorkFun),
  push(Valvex, Key, Reply, WorkFun, N-1).

get_params() ->
  [{ queues,
     [ { test_fifo
       , {10, unit}
       , {1, seconds}
       , {1, seconds}
       , valvex_queue_fifo_backend
       }
     , { test_lifo
       , {10, unit}
       , {1, seconds}
       , {1, seconds}
       , valvex_queue_lifo_backend
       }
     ]},
   {pushback_enabled, false},
   {workers, 5}
  ].

get_params_no_pushback() ->
  [{ queues,
     [ { test_fifo
       , {10, unit}
       , {20, seconds}
       , {20, seconds}
       , valvex_queue_fifo_backend
       }
     , { test_lifo
       , {10, unit}
       , {20, seconds}
       , {20, seconds}
       , valvex_queue_lifo_backend
       }
     ]},
   {pushback_enabled, true},
   {workers, 10}
  ].
%%get_bad_params_() ->
%%  [
%%   {throttle_rules, []}
%%  ].
get_timeout_params() ->
  [
   {throttle_rules, [{timeout_method, 25, 1}]}
  ].

receive_until_throttled() ->
    receive
      {timer_run, _Value} ->
        receive_until_throttled();
      {error, threshold_hit} ->
        {error, threshold_hit};
      _Other ->
        receive_until_throttled()
  end.

receive_until_stale() ->
    receive
      {timer_run, Value} ->
        ?assertEqual(Value, 5000),
        receive_until_stale();
      {error, timeout} ->
        {error, timeout};
      _Other ->
        receive_until_stale()
  end.

do_until_worker_state(Valvex, ExpectedCount) ->
  case valvex:get_available_workers_count(Valvex) of
    ExpectedCount ->
      true;
    _OtherCount    ->
      do_until_worker_state(Valvex, ExpectedCount)
  end.

do_until_queue_size(Valvex, Key, Size) ->
  case valvex:get_queue_size(Valvex, Key) of
    Size       -> true;
    _OtherSize -> do_until_queue_size(Valvex, Key, Size)
  end.
%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
