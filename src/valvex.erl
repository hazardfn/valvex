-module(valvex).

%% API exports
-export([ add/2
        , add/3
        , remove/2
        , remove/3
        , push/4
        , get_available_workers/1
        , get_available_workers_count/1
        , get_queue_size/2
        , start_link/1
        , pushback/3
        ]).

%%==============================================================================
%% Types
%%==============================================================================

%% Queue Types
-type queue_key()        :: atom().
-type queue_backend()    :: module() | {module, list()}.
-type queue_threshold()  :: {threshold, non_neg_integer()}.
-type queue_timeout()    :: {timeout, non_neg_integer(), seconds}.
-type queue_pushback()   :: {pushback, non_neg_integer(), seconds}.

%% Option / Behavioural modifier types
-type add_option()       :: crossover_on_existing              |
                            crossover_on_existing_force_remove |
                            undefined.
-type remove_option()    :: force_remove |
                            lock_queue   |
                            undefined.

%% Error types
-type unique_key_error() :: {error, key_not_unique}.
-type key_find_error()   :: {error, key_not_found}.

%% Other types
-type valvex_ref()       :: pid() | atom().
-type valvex_queue_raw() :: { queue_key()
                            , non_neg_integer()
                            , non_neg_integer()
                            , non_neg_integer()
                            , queue_backend()
                            }.
-type valvex_queue()     :: { queue_key()
                            , queue_threshold()
                            , queue_timeout()
                            , queue_pushback()
                            , queue_backend()
                            }.
-type valvex_q_item()    :: {function(), pid(), erlang:timestamp()}
                          | {empty, any()}.
-type valvex_options()   :: [{atom(), any()}].
-type valvex_workers()   :: [pid()].

-export_type([ queue_key/0
             , queue_backend/0
             , queue_threshold/0
             , queue_timeout/0
             , queue_pushback/0
             , add_option/0
             , remove_option/0
             , unique_key_error/0
             , key_find_error/0
             , valvex_ref/0
             , valvex_queue_raw/0
             , valvex_queue/0
             , valvex_options/0
             , valvex_workers/0
             , valvex_q_item/0
             ]).

%%==============================================================================
%% API functions
%%==============================================================================
-spec start_link(valvex_options()) -> {ok, valvex_ref()}.
start_link(Options) ->
  Pid = valvex_server:start_link(Options),
  {ok, Pid}.

-spec add( valvex_ref(), valvex_queue() | valvex_queue_raw()
         , add_option()) -> ok.
add(Valvex, { _Key
            , {threshold, _Threshold}
            , {timeout, _Timeout, seconds}
            , {pushback, _Pushback, seconds}
            , _Backend
            } = Q, Option) ->
  valvex_server:add(Valvex, Q, Option);
add(Valvex, { Key
            , Threshold
            , Timeout
            , Pushback
            , Backend
            }, Option) ->
  valvex:add(Valvex, { Key
                     , {threshold, Threshold}
                     , {timeout, Timeout, seconds}
                     , {pushback, Pushback, seconds}
                     , Backend
                     }, Option).

-spec add( valvex_ref()
         , valvex_queue() | valvex_queue_raw()
         ) -> ok | unique_key_error().
add(Valvex, { _Key
            , {threshold, _Threshold}
            , {timeout, _Timeout, seconds}
            , {pushback, _Pushback, seconds}
            , _Backend
            } = Q) ->
  valvex:add(Valvex, Q, undefined);
add(Valvex, { Key
            , Threshold
            , Timeout
            , Pushback
            , Backend
            }) ->
  valvex:add(Valvex, { Key
                     , {threshold, Threshold}
                     , {timeout, Timeout, seconds}
                     , {pushback, Pushback, seconds}
                     , Backend
                     }, undefined).

-spec remove( valvex_ref()
            , queue_key()
            , remove_option()
            ) -> ok | key_find_error().
remove(Valvex, Key, Option) ->
  valvex_server:remove(Valvex, Key, Option).

-spec remove( valvex_ref()
            , queue_key()
            ) -> ok | key_find_error().
remove(Valvex, Key) ->
  valvex:remove(Valvex, Key, undefined).

-spec push( valvex_ref()
		  , queue_key()
          , valvex_ref()
          , function()
          ) -> ok.
push(Valvex, Key, Reply, Work) ->
  valvex_server:push(Valvex, Key, {Work, Reply, erlang:timestamp()}).

-spec get_available_workers(valvex_ref()) -> valvex_workers().
get_available_workers(Valvex) ->
  valvex_server:get_available_workers(Valvex).

-spec get_available_workers_count(valvex_ref()) -> non_neg_integer().
get_available_workers_count(Valvex) ->
  length(valvex:get_available_workers(Valvex)).

-spec get_queue_size( valvex_ref()
                    , queue_key()
                    ) -> non_neg_integer() | key_find_error().
get_queue_size(Valvex, Key) ->
  valvex_server:get_queue_size(Valvex, Key).

-spec pushback( valvex_ref()
              , queue_key()
              , valvex_ref()
              ) -> ok.
pushback(Valvex, Key, Reply) ->
  valvex_server:pushback(Valvex, Key, Reply).

%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
