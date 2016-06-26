-module(test_message_handler).
-export([loop/0]).

loop() ->
    receive
        {queue_started, _Q} ->
            ok,
            loop();
        {queue_popped, _Q} ->
            ok,
            loop();
        {queue_popped_r, _Q} ->
            ok,
            loop();
        {queue_push, _Q} ->
            ok,
            loop();
        {queue_push_r, _Q} ->
            ok,
            loop();
        {push_complete, _Q} ->
            ok,
            loop();
        {push_to_locked_queue, _Q} ->
            ok,
            loop();
        {queue_tombstoned, _Q} ->
            ok,
            loop();
        {queue_locked, _Q} ->
            ok,
            loop();
        {queue_unlocked, _Q} ->
            ok,
            loop();
        {queue_consumer_started, _Q} ->
            ok,
            loop();
        {queue_consumer_stopped, _Q} ->
            ok,
            loop();
        {timeout, _Key} ->
            ok,
            loop();
        {result, _Result, _Key} ->
            ok,
            loop();
        {threshold_hit, _Q} ->
            ok,
            loop();
        {work_requeued, _Key, _AvailableWorkers} ->
            ok,
            loop();
        {worker_assigned, _Key, _Worker, _AvailableWorkers} ->
            ok,
            loop();
        {queue_crossover, _Q, _NuQ} ->
            ok,
            loop();
        {queue_removed, _Key} ->
            ok,
            loop();
        {worker_stopped, _Worker} ->
            ok,
            loop();
        Msg ->
            throw({unexpected_msg, Msg})
    end.
