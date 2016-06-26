-module(valvex_socket_event_handler).
-behaviour(gen_event).

%% gen_event exports
-export([ init/1
        , handle_event/2
        , handle_call/2
        , handle_info/2
        , code_change/3
        , terminate/2
        ]).

%% API exports
-export([]).

%%==============================================================================
%% Gen Event API
%%==============================================================================
init([ {host, Host}
     , {port, Port}
     , {handler, Handler}
     , {use_local, Local}
     ]) ->
  case Local of
    true -> start_cowboy(Port, Handler);
    false -> ok
  end,
  {ok, Gun}      = gun:open(Host, Port),
  {ok, Protocol} = gun:await_up(Gun),
  gun:ws_upgrade(Gun, "/websocket"),
  receive
    {gun_ws_upgrade, Gun, ok, _Headers} ->
      ok;
    {gun_response, Gun, _, _, Status, Headers} ->
      exit({ws_upgrade_failed, Status, Headers});
    {gun_error, Gun, _StreamRef, Reason} ->
      exit({ws_upgrade_failed, Reason})
      %% More clauses here as needed.
  after 15000 ->
      exit(timeout)
  end,
  {ok, #{ gun      => Gun
        , host     => Host
        , port     => Port
        , protocol => Protocol
        }}.

handle_event({queue_started, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}}, #{ gun := Gun } = S) ->
  Event  = #{ key => Key
            , threshold => Threshold
            , timeout   => Timeout
            , pushback  => Pushback
            , poll_rate => Poll
            , backend   => Backend
            , event     => queue_started
            , timestamp => format_utc_timestamp()
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({queue_popped, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}}, #{ gun := Gun } = S) ->
  Event  = #{ key => Key
            , threshold => Threshold
            , timeout   => Timeout
            , pushback  => Pushback
            , poll_rate => Poll
            , backend   => Backend
            , event     => queue_popped
            , timestamp => format_utc_timestamp()
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({queue_popped_r, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}}, #{ gun := Gun } = S) ->
    Event = #{ key => Key
             , threshold => Threshold
             , timeout   => Timeout
             , pushback  => Pushback
             , poll_rate => Poll
             , backend   => Backend
             , event     => queue_popped_r
             , timestamp => format_utc_timestamp()
             },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({queue_push, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}}, #{ gun := Gun } = S) ->
  Event  = #{ key => Key
            , threshold => Threshold
            , timeout   => Timeout
            , pushback  => Pushback
            , poll_rate => Poll
            , backend   => Backend
            , event     => queue_push
            , timestamp => format_utc_timestamp()
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({queue_push_r, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}}, #{ gun := Gun } = S) ->
  Event  = #{ key => Key
            , threshold => Threshold
            , timeout   => Timeout
            , pushback  => Pushback
            , poll_rate => Poll
            , backend   => Backend
            , event     => queue_push_r
            , timestamp => format_utc_timestamp()
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({push_complete, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}}, #{ gun := Gun} = S) ->
  Event  = #{ key => Key
            , threshold => Threshold
            , timeout   => Timeout
            , pushback  => Pushback
            , poll_rate => Poll
            , backend   => Backend
            , event     => push_complete
            , timestamp => format_utc_timestamp()
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({push_to_locked_queue, Key}, #{ gun := Gun} = S) ->
  Event  = #{ key => Key
            , event     => push_to_locked_queue
            , timestamp => format_utc_timestamp()
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({queue_tombstoned, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}}, #{ gun := Gun } = S) ->
  Event  = #{ key => Key
            , threshold => Threshold
            , timeout   => Timeout
            , pushback  => Pushback
            , poll_rate => Poll
            , backend   => Backend
            , event     => queue_tombstoned
            , timestamp => format_utc_timestamp()
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({queue_locked, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}}, #{ gun := Gun } = S) ->
  Event  = #{ key => Key
            , threshold => Threshold
            , timeout   => Timeout
            , pushback  => Pushback
            , poll_rate => Poll
            , backend   => Backend
            , event     => queue_locked
            , timestamp => format_utc_timestamp()
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({queue_unlocked, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}}, #{ gun := Gun } = S) ->
  Event  = #{ key => Key
            , threshold => Threshold
            , timeout   => Timeout
            , pushback  => Pushback
            , poll_rate => Poll
            , backend   => Backend
            , event     => queue_unlocked
            , timestamp => format_utc_timestamp()
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({queue_consumer_started, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}}, #{ gun := Gun } = S) ->
  Event  = #{ key => Key
            , threshold => Threshold
            , timeout   => Timeout
            , pushback  => Pushback
            , poll_rate => Poll
            , backend   => Backend
            , event     => queue_consumer_started
            , timestamp => format_utc_timestamp()
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({queue_consumer_stopped, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}}, #{ gun := Gun } = S) ->
  Event  = #{ key => Key
            , threshold => Threshold
            , timeout   => Timeout
            , pushback  => Pushback
            , poll_rate => Poll
            , backend   => Backend
            , event     => queue_consumer_stopped
            , timestamp => format_utc_timestamp()
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({timeout, Key}, #{ gun := Gun } = S) ->
  Event  = #{ key       => Key
            , event     => timeout
            , timestamp => format_utc_timestamp()
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({result, Result, Key}, #{ gun := Gun } = S) ->
  Event  = #{ key    => Key
            , result    => lists:flatten(io_lib:format("~s", [Result]))
            , event     => result
            , timestamp => format_utc_timestamp()
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({threshold_hit, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}}, #{ gun := Gun } = S) ->
  Event  = #{ key => Key
            , threshold => Threshold
            , timeout   => Timeout
            , pushback  => Pushback
            , poll_rate => Poll
            , backend   => Backend
            , event     => threshold_hit
            , timestamp => format_utc_timestamp()
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({queue_crossover, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}, {NuKey, {threshold, NuThreshold}, {timeout, NuTimeout, seconds}, {pushback, NuPushback, seconds}, {poll_rate, NuPoll, ms}, NuBackend}}, #{ gun := Gun } = S) ->
  Event  = #{ key => Key
            , threshold   => Threshold
            , timeout     => Timeout
            , pushback    => Pushback
            , poll_rate   => Poll
            , backend     => Backend
            , nukey       => NuKey
            , nuthreshold => NuThreshold
            , nutimeout   => NuTimeout
            , nupushback  => NuPushback
            , nupoll_rate => NuPoll
            , nubackend   => NuBackend
            , event       => queue_crossover
            , timestamp   => format_utc_timestamp()
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({queue_removed, Key}, #{ gun := Gun } = S) ->
  Event  = #{ key   => Key
            , event => queue_removed
            , timestamp => format_utc_timestamp()
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({work_requeued, Key, AvailableWorkers}, #{ gun := Gun } = S) ->
  Event = #{ key => Key
           , available_workers => AvailableWorkers
           , event => work_requeued
           , timestamp => format_utc_timestamp()
           },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({worker_assigned, Key, AvailableWorkers}, #{ gun := Gun } = S) ->
  Event = #{ key => Key
           , available_workers => AvailableWorkers
           , event => work_assigned
           , timestamp => format_utc_timestamp()
           },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({worker_stopped, Worker}, #{ gun := Gun } = S) ->
  Event = #{ worker => erlang:pid_to_list(Worker)
           , event => worker_stopped
           , timestamp => format_utc_timestamp()
           },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S}.


handle_info(_, State) ->
  {ok, State}.

handle_call(_, S) ->
  {ok, ok, S}.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

terminate(_Reason, #{ gun := Gun }) ->
  gun:shutdown(Gun).

jsonify(Event) ->
  {binary, jsx:encode(Event)}.

start_cowboy(Port, Handler) ->
  Dispatch = cowboy_router:compile([
                                    {'_', [
                                           {"/websocket", Handler, []}
                                          ]}
                                   ]),
  cowboy:start_clear(http, 100, [{port, Port}], #{ env => #{dispatch => Dispatch} }).
format_utc_timestamp() ->
    TS = {_,_,Micro} = os:timestamp(),
    {{Year,Month,Day},{Hour,Minute,Second}} = calendar:now_to_universal_time(TS),
    Mstr = element(Month,{"Jan","Feb","Mar","Apr","May","Jun","Jul",
    "Aug","Sep","Oct","Nov","Dec"}),
    io_lib:format("~2w ~s ~4w ~2w:~2..0w:~2..0w.~6..~w", [Day,Mstr,Year,Hour,Minute,Second, Micro]).

%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
