%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc valvex proper tests
%%% @copyright 2016 Howard Beard-Marlowe
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%_* Module declaration =======================================================
-module(valvex_tests_proper).
-compile(export_all).

-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").

%%%_* Macros ===================================================================

-define(SERVER, valvex).
-define(ADD_OPTIONS, [manual_start, undefined]).
-define(REMOVE_OPTIONS, [force_remove, lock_queue, undefined]).
-define(BACKENDS, [valvex_queue_fifo_backend, valvex_queue_lifo_backend]).

%%%_* Generators ===============================================================

add_option() ->
  elements(?ADD_OPTIONS).

remove_option() ->
  elements(?REMOVE_OPTIONS).

queue() ->
  { atom()
  , {threshold, non_neg_integer()}
  , {timeout, non_neg_integer(), seconds}
  , {pushback, non_neg_integer(), seconds}
  , {poll_rate, integer(1, inf), ms}
  , {poll_count, integer(0, inf)}
  , ?MODULE:queue_backend()
  }.

queue_with_same_key([]) ->
  [];
queue_with_same_key({Key, _, _, _, _, _, Backend}) ->
  { Key
  , {threshold, non_neg_integer()}
  , {timeout, non_neg_integer(), seconds}
  , {pushback, non_neg_integer(), seconds}
  , {poll_rate, integer(5000, inf), ms}
  , {poll_count, integer(0, inf)}
  , Backend
  }.

existing_queue_key(#{ queues := []}) ->
  [];
existing_queue_key(#{ queues := Queues }) ->
  Index = rand:uniform(length(Queues)),
  Key = element(1, lists:nth(Index, Queues)),
  Key.

existing_queue(#{ queues := Queues }) ->
  Index = rand:uniform(length(Queues)),
  lists:nth(Index, Queues).

first_queue_key(#{ queues := Queues }) ->
  element(1, lists:nth(1, Queues)).

first_queue(#{ queues := Queues }) ->
  lists:nth(1, Queues).

random_wait_fun() ->
  fun() ->
      timer:sleep(integer(1000, 5000))
  end.

queue_backend() ->
  elements(?BACKENDS).

%%%_* Proper Callbacks =========================================================

proper_test_() ->
  {timeout, 30000, ?_assert(proper:quickcheck(valvex_tests_proper:prop_valvex(), [{to_file, user}, {numtests, 500}]))}.
prop_valvex() ->
  ?FORALL(Cmds, commands(?MODULE),
          ?TRAPEXIT(
             begin
               valvex_test_forwarder:start_link(),
               application:ensure_all_started(valvex),
               {History,State,Result} = run_commands(?MODULE, Cmds),
               application:stop(valvex),
               gen_server:stop(valvex_test_forwarder),
               ?WHENFAIL(io:format("History: ~w~nState: ~w\nResult: ~w~n",
                                   [History,State,Result]),
                         aggregate(command_names(Cmds), Result =:= ok))
             end)).

initial_state() ->
  #{ queues            => []
   , queue_pids        => []
   , pushback          => false
   , workers           => []
   , event_server      => undefined
   , available_workers => []
   }.

command(S) ->
  Queues  = (maps:get(queues, S) =/= []),
  oneof([ {call,?SERVER,add,[?SERVER, ?MODULE:queue()]}
        , {call,?SERVER,add,[?SERVER, queue(), add_option()]}] ++
        [ {call,?SERVER,add,[?SERVER, queue_with_same_key(existing_queue(S)), crossover_on_existing]} || Queues] ++
        [ {call,?SERVER,push,[?SERVER, existing_queue_key(S), random_wait_fun()]} || Queues] ++
        [ {call,?SERVER,remove,[?SERVER, existing_queue_key(S)]} || Queues] ++
        [ {call,?SERVER,remove,[?SERVER, atom()]} || Queues] ++
        [ {call,?SERVER,remove,[?SERVER, existing_queue_key(S), remove_option()]} || Queues] ++
        [ {call,?SERVER,remove,[?SERVER, atom(), remove_option()]} || Queues ] ++
        [ {call,?SERVER,update,[?SERVER, first_queue_key(S), queue_with_same_key(first_queue(S))]} || Queues] ++
        [ {call,?SERVER,update,[?SERVER, atom(), queue()]} || Queues]
        ).

precondition(_S, {call,_,add,[?SERVER, _Q]}) ->
  true;
precondition(_S, {call,_,add,[?SERVER, _Q, crossover_on_existing]}) ->
  true;
precondition(_S, {call,_,add,[?SERVER, _Q, _Option]}) ->
  true;
precondition(_S, {call,_,remove,[?SERVER, _Key]}) ->
  true;
precondition(_S, {call,_,remove,[?SERVER, _Key, lock_queue]}) ->
  true;
precondition(_S, {call,_,remove,[?SERVER, _Key, _Option]}) ->
  true;
precondition(_S, {call,_,push,[?SERVER, _Key, _Fun]}) ->
  true;
precondition(_S, {call,_,update,[?SERVER, _Key, _Queue]}) ->
  true.

postcondition(_S, {call,_,add,[?SERVER, _Q]}, R) ->
  R =:= ok orelse R =:= {error, key_not_unique};
postcondition(_S, {call,_,add,[?SERVER, _Q, crossover_on_existing]}, R) ->
  R =:= ok orelse R =:= {error, backend_key_crossover_not_supported};
postcondition(_S, {call,_,add,[?SERVER, _Q, _Option]}, R) ->
  R =:= ok orelse R =:= {error, key_not_unique};
postcondition(_S, {call,_,remove,[?SERVER, _Key]}, R) ->
  R =:= ok orelse R =:= {error, key_not_found};
postcondition(_S, {call,_,remove,[?SERVER, _Key, undefined]}, R) ->
  R =:= ok orelse R =:= {error, key_not_found};
postcondition(_S, {call,_,remove,[?SERVER, _Key, lock_queue]}, _R) ->
  true;
postcondition(_S, {call,_,remove,[?SERVER, _Key, force_remove]}, R) ->
  R =:= ok orelse R =:= {error, key_not_found};
postcondition(_S, {call,_,push,[?SERVER, _Key, _Fun]}, R) ->
  R =:= ok;
postcondition(_S, {call,_,update,[?SERVER, _Key, _Queue]}, R) ->
  R =:= ok orelse R =:= {error, key_not_found} orelse R =:= {error, backend_key_crossover_not_supported}.


next_state(#{ queues     := Queues
            , queue_pids := QueuePids
            } = S, _V, {call,_,add,[?SERVER, {Key, _, _, _, _, _, Backend} = Q]}) ->
  S#{ queues     := lists:append(Queues, [Q])
    , queue_pids := lists:append(QueuePids, [{Key, Backend}])
    };
next_state(#{ queues     := Queues
            , queue_pids := QueuePids
            } = S, _V, {call,_,add,[?SERVER, {Key, _, _, _, _, _, Backend} = Q, crossover_on_existing]}) ->
  case lists:keyfind(Key, 1, QueuePids) of
    {Key, Backend} ->
      S#{ queues     := lists:append(lists:keydelete(Key, 1, Queues), [Q])
        , queue_pids := lists:append(lists:keydelete(Key, 1, QueuePids), [{Key, Backend}])
        };
    _ -> S
  end;
next_state(#{ queues     := Queues
            , queue_pids := QueuePids
            } = S, _V, {call,_,add,[?SERVER, {Key, _, _, _, _, _, Backend} = Q, _Option]}) ->
  S#{ queues     := lists:append(Queues, [Q])
    , queue_pids := lists:append(QueuePids, [{Key, Backend}])
    };
next_state(#{ queues     := Queues
            , queue_pids := QPids
            } = S
          , _V, {call,_,remove,[?SERVER, Key]}) ->
  S#{ queues     := lists:keydelete(Key, 1, Queues)
    , queue_pids := lists:keydelete(Key, 1, QPids)
    };
next_state(#{ queues     := Queues
            , queue_pids := QPids
            } = S
          , _V, {call,_,remove,[?SERVER, Key, _Option]}) ->
  S#{ queues     := lists:keydelete(Key, 1, Queues)
    , queue_pids := lists:keydelete(Key, 1, QPids)
    };
next_state(S, _V, {call,_,push,[?SERVER, _Key, _Fun]}) ->
  S;
next_state(#{ queues := Queues
            , queue_pids := QPids
            } = S, _V, {call, _, update, [?SERVER, Key, {Key, _, _, _, _, _, Backend} = Q]}) ->
  S#{ queues := lists:keyreplace(Key, 1, Queues, Q)
    , queue_pids := lists:keyreplace(Key, 1, QPids, {Key, Backend})
    };
next_state(S, _V, {call, _, update, [?SERVER, _Key, {_OtherKey, _, _, _, _, _, _}]}) ->
  S.

%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
