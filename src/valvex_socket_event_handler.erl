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
     ]) ->
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
  after 5000 ->
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
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({queue_popped_r, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}}, #{ gun := Gun } = S) ->
    Event  = #{ key => Key
            , threshold => Threshold
            , timeout   => Timeout
            , pushback  => Pushback
            , poll_rate => Poll
            , backend   => Backend
            , event     => queue_popped_r
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
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({push_to_locked_queue, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}}, #{ gun := Gun} = S) ->
  Event  = #{ key => Key
            , threshold => Threshold
            , timeout   => Timeout
            , pushback  => Pushback
            , poll_rate => Poll
            , backend   => Backend
            , event     => push_to_locked_queue
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
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({timeout, Key}, #{ gun := Gun } = S) ->
  Event  = #{ key       => Key
            , event     => timeout
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({result, Result}, #{ gun := Gun } = S) ->
  Event  = #{ result    => Result
            , event     => result
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
            , event     => queue_crossover
            },
  gun:ws_send(Gun, jsonify(Event)),
  {ok, S};
handle_event({queue_removed, Key}, #{ gun := Gun } = S) ->
  Event  = #{ key   => Key
            , event => queue_removed
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
  {binary, jsone:encode(Event)}.

%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
