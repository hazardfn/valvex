%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Howard Beard-Marlowe <howardbm@live.se>
%%% @copyright 2016 Howard Beard-Marlowe
%%% @version 0.1.0
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @doc Valvex test forwarder
%%
%% This module is used as part of testing the socket event handler.
%% It collects the pids of the open sockets in an ets table so every
%% listener can receive the message.

%%%_* Module declaration ===============================================================================================
-module(valvex_test_forwarder).
-export([ start_link/0
        , register/2
        , list/1
        ]).

%%%_* Behaviour declaration ============================================================================================
-behavior(gen_server).
-export([ init/1
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , terminate/2
        , code_change/3
        ]).
%%%_* API ==============================================================================================================
%% @doc Starts a link with the test_forwarder gen_server.
-spec start_link() -> 'ignore' | {'error',_} | {'ok',pid()}.
start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Registers a socket by placing it in the global
%% sockets ets table.
-spec register(atom() | pid(), atom() | pid()) -> ok.
register(Forwarder, SocketPid) ->
    gen_server:call(Forwarder, {register, SocketPid}).

%% @doc Lists all the sockets currently residing in the table.
-spec list(atom() | pid()) -> [pid() | atom()].
list(Forwarder) ->
    gen_server:call(Forwarder, list).

%%%_* Gen_Server callbacks =============================================================================================
-spec init([]) -> {'ok',atom() | ets:tid()}.
init([]) ->
  {ok, ets:new(sockets, [ named_table ])}.

handle_call({register, Pid}, _From, Table) ->
  {reply, ets:insert(Table, {Pid}), Table};
handle_call(list, _From, Table) ->
  {reply, ets:tab2list(Table), Table }.

handle_cast(_Msg, S) ->
  {noreply, S}.

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, Table) ->
  ets:delete(Table).

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.
