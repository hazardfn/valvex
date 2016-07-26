%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Howard Beard-Marlowe <howardbm@live.se>
%%% @copyright 2016 Howard Beard-Marlowe
%%% @version 0.1.0
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @doc Valvex test handler
%%
%% This module is used as part of testing the socket event handler
%% It is the cowboy handler which takes data sent by the event handler
%% and forwards it on to the listening sockets.

%%%_* Module declaration ===============================================================================================
-module(valvex_test_handler).
-export([ init/2,
          websocket_handle/3,
          websocket_info/3
        ]).
%%%_* Cowboy callbacks =================================================================================================
init(Req, _Opts) ->
  gen_server:call(valvex_test_forwarder, {register, self()}),
  {cowboy_websocket, Req, #{}}.

websocket_handle({text, Msg}, Req, State) ->
  {reply, {text, << "responding to ", Msg/binary >>}, Req, State, hibernate };
websocket_handle({binary, Msg}, Req, State) ->
  [ S ! Msg || {S} <- all_other_sockets(self()) ],
  {reply, {text, << "Message Forwarded!">>}, Req, State, hibernate }.

websocket_info({timeout, _Ref, Msg}, Req, State) ->
  {reply, {text, Msg}, Req, State};
websocket_info(Info, Req, State) ->
  {reply, {text, Info}, Req, State}.

all_other_sockets(Pid) ->
  Sockets   = gen_server:call(test_forwarder, list),
  lists:filter(fun ({Socket}) -> Socket =/= Pid end, Sockets).

%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
