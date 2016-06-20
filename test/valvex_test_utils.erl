%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @author Howard Beard-Marlowe <howardbm@live.se>
%%% @copyright 2016 Howard Beard-Marlowe
%%% @version 0.1.0
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%_* Module declaration =======================================================
-module(valvex_test_utils).
-export([ get_queue_from_config/2
        ]).

%%%_* Includes =================================================================

-include_lib("eunit/include/eunit.hrl").

%%%_* Test Utils =================================================================

get_queue_from_config(Key, Config) ->
  {queues, Queues} = lists:keyfind(queues, 1, Config),
  Q                = lists:keyfind(Key, 1, Queues),
  ?assertNotEqual(false, Q),
  ?assert(is_tuple(Q)),
  Q.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
