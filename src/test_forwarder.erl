-module(test_forwarder).

-behavior(gen_server).

-compile([export_all]).

-spec start_link() -> {'ok', pid()}.
start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec init(list()) -> {ok, #{}}.
init(_Options) ->
  State = ets:new(sockets, [ named_table ]),
  {ok, State}.

handle_info(_Info, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

handle_call({register, Pid}, _From, Table) ->
  {reply, ets:insert(Table, {Pid}), Table};

handle_call(list, _From, Table) ->
  {reply, ets:tab2list(Table), Table }.

handle_cast(_Msg, S) ->
  {noreply, S}.
