%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc valve tests
%%% @copyright 2015 Klarna AB
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%_* Module declaration =======================================================
-module(valvex_tests).

-export([
         test_work_completes/1
%%        , test_threshold_hit/1
%%        , test_timeout_hit/1
%%        , test_available_workers/1
%%        , test_requeue/1
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
  Valvex           = valvex:start_link(get_params()),
  ValvexNoPushback = valvex:start_link(get_params_no_pushback()),
  [ {test_pid, Valvex}
  , {no_pushback_pid, ValvexNoPushback}
    | Config
  ].

end_per_suite(Config) ->
  {_, Valvex}           = lists:keyfind(test_pid, 1, Config),
  {_, ValvexNoPushback} = lists:keyfind(no_pushback_pid, 1, Config),
  ?assertEqual(ok, gen_server:stop(Valvex)),
  ?assertEqual(ok, gen_server:stop(ValvexNoPushback)),
  ok.


init_per_testcase(TestCase, Config) ->
 ?MODULE:TestCase({init, Config}).

end_per_testcase(TestCase, Config)  ->
 ?MODULE:TestCase({'end', Config}).

all()      ->
  all(suite).
all(suite) ->
  [
   test_work_completes
%%  , test_threshold_hit
%%  , test_timeout_hit
%%  , test_available_workers
%%  , test_requeue
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
  {ok, Valve} = tulib_lists:assoc(test_pid, Config),
  WorkFun = fun() ->
                timer:sleep(3000),
                {timer_run, 3000}
            end,
  push(Valve, self(), test_method, WorkFun, 13),
  ?assertEqual(receive_until_throttled(), {error, throttled}).

test_timeout_hit(suite)                            -> [];
test_timeout_hit({init, Config})                   -> Config;
test_timeout_hit({'end', _Config})                 -> ok;
test_timeout_hit(doc)                              ->
    ["Test the timeout is hit"];
test_timeout_hit(Config) when is_list(Config)      ->
  {ok, Valve} = tulib_lists:assoc(timeout_pid, Config),
  WorkFun = fun() ->
                timer:sleep(1000),
                {timer_run, 1000}
            end,
  push(Valve, self(), timeout_method, WorkFun, 11),
  ?assertEqual(receive_until_stale(), {error, call_stale}).

test_available_workers(suite)                       -> [];
test_available_workers({init, Config})              -> Config;
test_available_workers({'end', _Config})            -> ok;
test_available_workers(doc)                         ->
    ["Test an available worker is consumed when work is pushed"];
test_available_workers(Config) when is_list(Config) ->
  {ok, Valve} = tulib_lists:assoc(test_pid, Config),
  Workers     = valve:get_available_workers(Valve),
  case is_list(Workers) of
    true  ->
      WorkerCount = valve:get_available_worker_count(Valve),
      ?assertEqual(length(Workers), WorkerCount),
      WorkFun     = fun() ->
                        timer:sleep(1000),
                        {timer_run, 1000}
                    end,
      push(Valve, self(), test_method, WorkFun, 1),
      ?assertEqual(do_until_worker_state(Valve, WorkerCount-1), true),
      ?assertEqual(do_until_worker_state(Valve, WorkerCount), true);
    false -> error(workers_not_a_list)
  end.

test_requeue(suite)                                 -> [];
test_requeue({init, Config})                        -> Config;
test_requeue({'end', _Config})                      -> ok;
test_requeue(doc)                                   ->
    ["Test work is requeued when all workers are busy"];
test_requeue(Config) when is_list(Config)           ->
  {ok, Valve} = tulib_lists:assoc(test_pid, Config),
  WorkFun = fun() ->
                timer:sleep(10000),
                {timer_run, 10000}
            end,
  push(Valve, self(), test_method, WorkFun, 11),
  ?assertEqual(do_until_worker_state(Valve, 0), true),
  ?assertEqual(do_until_queue_size(Valve, test_method, 1), true).

%%%_* Internals ================================================================
push(_Valve, _Key, _Reply, _WorkFun, 0) ->
  ok;
push(Valvex, Key, Reply, WorkFun, N) ->
  valvex:push(Valvex, Key, Reply, WorkFun),
  push(Valvex, Key, Reply, WorkFun, N-1).

get_params() ->
  [{ queues,
     [ { test_fifo
       , {300, unit}
       , {20, seconds}
       , {20, seconds}
       , valvex_queue_fifo_backend
       }
     , { test_lifo
       , {300, unit}
       , {20, seconds}
       , {20, seconds}
       , valvex_queue_lifo_backend
       }
     ]},
   {pushback_enabled, true},
   {workers, 10}
  ].

get_params_no_pushback() ->
  [{ queues,
     [ { test_fifo
       , {300, unit}
       , {20, seconds}
       , {20, seconds}
       , valvex_queue_fifo_backend
       }
     , { test_lifo
       , {300, unit}
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
      {error, throttled} ->
        {error, throttled};
      _Other ->
        receive_until_throttled()
  end.

receive_until_stale() ->
    receive
      {timer_run, Value} ->
        ?assertEqual(Value, 1000),
        receive_until_stale();
      {error, call_stale} ->
        {error, call_stale};
      Other ->
        ?debugFmt("Unexpected Result: ~p", [Other]),
        receive_until_stale()
  end.

do_until_worker_state(Valve, ExpectedCount) ->
  case valvex:get_available_worker_count(Valve) of
    ExpectedCount ->
      true;
    _OtherCount    ->
      do_until_worker_state(Valve, ExpectedCount)
  end.

do_until_queue_size(Valve, Key, Size) ->
  case valvex:get_queue_size(Valve, Key) of
    Size -> true;
    _    -> do_until_queue_size(Valve, Key, Size)
  end.
%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
