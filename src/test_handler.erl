-module(test_handler).
-export([init/2]).
-export([
    websocket_handle/3,
    websocket_info/3
]).

init(Req, _Opts) ->
  gen_server:call(test_forwarder, {register, self()}),
  {cowboy_websocket, Req, #{}}.

websocket_handle({text, Msg}, Req, State) ->
    lager:info("Got Data: ~p", [Msg]),
    {reply, {text, << "responding to ", Msg/binary >>}, Req, State, hibernate };
websocket_handle({binary, Msg}, Req, State) ->
    lager:info("Got Data: ~p", [Msg]),
    [ S ! Msg || {S} <- all_other_sockets(self()) ],
    {reply, {text, << "whut?">>}, Req, State, hibernate }.

all_other_sockets(Pid) ->
  Sockets = gen_server:call(test_forwarder, list),
  WithoutMe = lists:filter(fun ({Socket}) ->
                               Socket =/= Pid
                           end, Sockets),
  WithoutMe.

websocket_info({timeout, _Ref, Msg}, Req, State) ->
    {reply, {text, Msg}, Req, State};
websocket_info(Info, Req, State) ->
    lager:info("info is ~p", [Info]),
    {reply, {text, Info}, Req, State}.
