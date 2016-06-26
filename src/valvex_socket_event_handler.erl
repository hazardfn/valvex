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

handle_event({_, {Key, _, _, _, _, _}}, #{ gun := Gun } = S) ->
  do_fudge(sys:get_state(Key), Gun),
  {ok, S};
handle_event({_, {Key, _, _, _, _, _}, _}, #{ gun := Gun } = S) ->
  do_fudge(sys:get_state(Key), Gun),
  {ok, S};
handle_event({_, Key}, #{ gun := Gun } = S) ->
  do_fudge(sys:get_state(Key), Gun),
  {ok, S};
handle_event({_, Key, _, _}, #{ gun := Gun } = S) ->
  do_fudge(sys:get_state(Key), Gun),
  {ok, S};
handle_event({_, Key, _}, #{ gun := Gun } = S) ->
  do_fudge(sys:get_state(Key), Gun),
  {ok, S}.

do_fudge(QS, Gun) ->
  QueueState = maps:put(created_at, format_utc_timestamp(), maps:put(name, dump, maps:remove(queue, maps:remove(q, maps:remove(consumer, maps:remove(queue_pid, QS)))))),
  gun:ws_send(Gun, jsonify(QueueState)).

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
  R = io_lib:format("~2w ~s ~4w ~2w:~2..0w:~2..0w.~6..~w", [Day,Mstr,Year,Hour,Minute,Second, Micro]),
  lists:flatten(R).

%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
