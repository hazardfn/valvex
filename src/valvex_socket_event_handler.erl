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
init([ {port, Port}
     , {handler, Handler}
     , {use_local, true}
     ]) ->
  start_cowboy(Port, Handler),
  {ok, [{IP, _, _}, _]} = inet:getif(),
  Host = inet_parse:ntoa(IP),
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
        }};
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
  after 15000 ->
      exit(timeout)
  end,
  {ok, #{ gun      => Gun
        , host     => Host
        , port     => Port
        , protocol => Protocol
        }}.

handle_event( {queue_started, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}}
            , #{ gun := Gun } = S) ->
  Map = #{ key        => Key
         , threshold  => Threshold
         , timeout    => Timeout
         , pushback   => Pushback
         , poll_rate  => Poll
         , backend    => Backend
         , name       => queue_started
         , created_at => format_utc_timestamp()
         },
  gun:ws_send(Gun, jsonify(Map)),
  {ok, S};
handle_event( {queue_consumer_started, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}}
            , #{ gun := Gun } = S) ->
  Map = #{ key        => Key
         , threshold  => Threshold
         , timeout    => Timeout
         , pushback   => Pushback
         , poll_rate  => Poll
         , backend    => Backend
         , name       => queue_started
         , created_at => format_utc_timestamp()
         },
  gun:ws_send(Gun, jsonify(Map)),
  {ok, S};
handle_event( {queue_consumer_stopped, {Key, {threshold, Threshold}, {timeout, Timeout, seconds}, {pushback, Pushback, seconds}, {poll_rate, Poll, ms}, Backend}}
            , #{ gun := Gun } = S) ->
  Map = #{ key        => Key
         , threshold  => Threshold
         , timeout    => Timeout
         , pushback   => Pushback
         , poll_rate  => Poll
         , backend    => Backend
         , name       => queue_started
         , created_at => format_utc_timestamp()
         },
  gun:ws_send(Gun, jsonify(Map)),
  {ok, S};
handle_event(Event, #{ gun := Gun } = S) ->
  do_dump(Gun, Event),
  {ok, S}.

do_dump(Gun, _Event) ->
  ValvexState = sys:get_state(valvex),
  Queues      = maps:get(queues, ValvexState),
  QueueFun    = fun({Key, _, _, _, _, _}) ->
                    Pred = fun(K, _V) ->
                               lists:member(K, map_blacklist()) == false
                           end,
                    [maps:filter(Pred, sys:get_state(Key))]
                end,
  QueueMapped = #{ mapped_queues => lists:flatmap(QueueFun, Queues) },
  BaseMap     = #{ created_at    => format_utc_timestamp()
                 , name          => dump
                 },
  QueueState = maps:merge(BaseMap, QueueMapped),
  gun:ws_send(Gun, jsonify(QueueState)).

map_blacklist() ->
  [ queue, q, consumer, queue_pid ].

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
  TS =  os:timestamp(),
  calendar:now_to_universal_time(TS).
%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
