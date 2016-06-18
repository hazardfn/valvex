%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Public API for valvex
%%% @author Howard Beard-Marlowe <howardbm@live.se>
%%% @copyright 2016 Howard Beard-Marlowe
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%_* Module declaration =======================================================
-module(valvex).

%% API exports
-export([ add/2
        , add/3
        , add_handler/3
        , get_available_workers/1
        , get_available_workers_count/1
        , get_queue_size/2
        , notify/2
        , push/3
        , pushback/2
        , remove/2
        , remove/3
        , remove_handler/3
        , start_link/1
        ]).

%%==============================================================================
%% Types
%%==============================================================================

%% Queue Types
-type queue_backend()    :: module() | {module, list()}.
-type queue_key()        :: atom().
-type queue_poll_rate()  :: {poll_rate, non_neg_integer(), ms}.
-type queue_pushback()   :: {pushback, non_neg_integer(), seconds}.
-type queue_threshold()  :: {threshold, non_neg_integer()}.
-type queue_timeout()    :: {timeout, non_neg_integer(), seconds}.

%% Option / Behavioural modifier types
-type add_option()       :: crossover_on_existing              |
                            crossover_on_existing_force_remove |
                            undefined.
-type remove_option()    :: force_remove |
                            lock_queue   |
                            undefined.

%% Error types
-type key_find_error()   :: {error, key_not_found}.
-type unique_key_error() :: {error, key_not_unique}.

%% Other types
-type valvex_ref()       :: pid() | atom().
-type valvex_queue_raw() :: { queue_key()
                            , non_neg_integer()
                            , non_neg_integer()
                            , non_neg_integer()
                            , non_neg_integer()
                            , queue_backend()
                            }.
-type valvex_queue()     :: { queue_key()
                            , queue_threshold()
                            , queue_timeout()
                            , queue_pushback()
                            , queue_poll_rate()
                            , queue_backend()
                            }.
-type valvex_q_item()    :: {function(), erlang:timestamp()}
                          | {empty, any()}.
-type valvex_options()   :: [{atom(), any()}].
-type valvex_workers()   :: [pid()].

-export_type([ add_option/0
             , key_find_error/0
             , queue_backend/0
             , queue_key/0
             , queue_poll_rate/0
             , queue_pushback/0
             , queue_threshold/0
             , queue_timeout/0
             , remove_option/0
             , unique_key_error/0
             , valvex_options/0
             , valvex_q_item/0
             , valvex_queue/0
             , valvex_queue_raw/0
             , valvex_ref/0
             , valvex_workers/0
             ]).

%%==============================================================================
%% API functions
%%==============================================================================
-spec start_link(valvex_options()) -> {ok, valvex_ref()}.
start_link(Options) ->
  Pid = valvex_server:start_link(Options),
  {ok, Pid}.


-spec add( valvex_ref()
         , valvex_queue() | valvex_queue_raw()
         , add_option()) -> ok.
add(Valvex, { _Key
            , {threshold, _Threshold}
            , {timeout, _Timeout, seconds}
            , {pushback, _Pushback, seconds}
            , {poll_rate, _Poll, ms}
            , _Backend
            } = Q, Option) ->
  valvex_server:add(Valvex, Q, Option);
add(Valvex, { Key
            , Threshold
            , Timeout
            , Pushback
            , Poll
            , Backend
            }, Option) ->
  valvex:add(Valvex, { Key
                     , {threshold, Threshold}
                     , {timeout, Timeout, seconds}
                     , {pushback, Pushback, seconds}
                     , {poll_rate, Poll, ms}
                     , Backend
                     }, Option).

-spec add( valvex_ref()
         , valvex_queue() | valvex_queue_raw()
         ) -> ok | unique_key_error().
add(Valvex, { _Key
            , {threshold, _Threshold}
            , {timeout, _Timeout, seconds}
            , {pushback, _Pushback, seconds}
            , {poll_rate, _Poll, ms}
            , _Backend
            } = Q) ->
  valvex:add(Valvex, Q, undefined);
add(Valvex, { Key
            , Threshold
            , Timeout
            , Pushback
            , Poll
            , Backend
            }) ->
  valvex:add(Valvex, { Key
                     , {threshold, Threshold}
                     , {timeout, Timeout, seconds}
                     , {pushback, Pushback, seconds}
                     , {poll_rate, Poll, ms}
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
          , function()
          ) -> ok.
push(Valvex, Key, Work) ->
  valvex_server:push(Valvex, Key, {Work, erlang:timestamp()}).

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
              ) -> ok.
pushback(Valvex, Key) ->
  valvex_server:pushback(Valvex, Key).

-spec notify( valvex_ref()
            , any()
            ) -> ok.
notify(Valvex, Event) ->
  valvex_server:notify(Valvex, Event).

-spec add_handler( valvex_ref()
                 , module()
                 , [any()]
                 ) -> ok.
add_handler(Valvex, Module, Args) ->
  valvex_server:add_handler(Valvex, Module, Args).

remove_handler(Valvex, Module, Args) ->
  valvex_server:remove_handler(Valvex, Module, Args).

%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
