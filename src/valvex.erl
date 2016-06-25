%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @author Howard Beard-Marlowe <howardbm@live.se>
%%% @copyright 2016 Howard Beard-Marlowe
%%% @version 0.1.0
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @doc Valvex - the ultimate tool for rate-limiting in erlang.
%%
%% This module provides the main interface to Valvex. For more information
%% refer to the readme.

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
        , update/3
        ]).

%%======================================================================================================================
%% Types
%%======================================================================================================================

%% Queue Types ---------------------------------------------------------------------------------------------------------
-type queue_backend()    :: module() | {module, list()}.
-type queue_key()        :: atom().
-type queue_poll_rate()  :: {poll_rate, non_neg_integer(), ms}.
-type queue_pushback()   :: {pushback, non_neg_integer(), seconds}.
-type queue_threshold()  :: {threshold, non_neg_integer()}.
-type queue_timeout()    :: {timeout, non_neg_integer(), seconds}.

%% Option / Behavioural modifier types ---------------------------------------------------------------------------------
-type add_option()       :: crossover_on_existing | manual_start | undefined.

-type remove_option()    :: force_remove | lock_queue | undefined.

%% Error types ---------------------------------------------------------------------------------------------------------
-type key_find_error()   :: {error, key_not_found}.
-type unique_key_error() :: {error, key_not_unique}.

%% Other types ---------------------------------------------------------------------------------------------------------
-type valvex_ref()       :: pid() | atom().
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
             , valvex_ref/0
             , valvex_workers/0
             ]).

%%======================================================================================================================
%% API functions
%%======================================================================================================================
%% @doc Starts a link with the valvex gen_server.
-spec start_link(valvex_options()) -> {ok, valvex_ref()}.
start_link(Options) ->
  Pid = valvex_server:start_link(Options),
  lager:info("Valvex server started: ~p", [Pid]),
  {ok, Pid}.

%% @doc Adds a queue to valvex using the default option undefined.
%% @see add/3
-spec add( valvex_ref()
         , valvex_queue()
         ) -> ok | unique_key_error().
add(Valvex, { _Key
            , {threshold, _Threshold}
            , {timeout, _Timeout, seconds}
            , {pushback, _Pushback, seconds}
            , {poll_rate, _Poll, ms}
            , _Backend
            } = Q) ->
  valvex:add(Valvex, Q, undefined).

%% @doc Adds a queue to valvex. There are a few options that aliter slightly
%% the behaviour of the add:
%% <br/><br/>
%% <ul>
%% <li> manual_start - adds the queue but does not immediately start the consumer </li>
%% <li> crossover_on_existing - adds the queue, if a queue of the same key exists it will swap out the old settings
%% for the new </li>
%% <li> undefined - default behaviour which is to add the queue or error if
%% the key is not unique </li>
%% </ul>.
%% @see add_option()
-spec add( valvex_ref()
         , valvex_queue()
         , add_option()) -> ok.
add(Valvex, { _Key
            , {threshold, _Threshold}
            , {timeout, _Timeout, seconds}
            , {pushback, _Pushback, seconds}
            , {poll_rate, _Poll, ms}
            , _Backend
            } = Q, Option) ->
  valvex_server:add(Valvex, Q, Option).

%% @doc removes a queue from valvex with the default setting. see remove/3 for more info.
%% @see remove/3
-spec remove( valvex_ref()
            , queue_key()
            ) -> ok | key_find_error().
remove(Valvex, Key) ->
  valvex:remove(Valvex, Key, undefined).

%% @doc Removes a queue from valvex. There are a few options that alter the way
%% a remove behaves:
%% <br/><br/>
%% <ul>
%% <li> force_remove - Removes the queue by force regardless of items in it </li>
%% <li> lock_queue - Locks the queue and marks it for deletion meaning it will be removed when empty and
%% no new things can be placed in it </li>
%% <li> undefined - marks the queue for deletion but new items can flow in, it won't be removed until empty </li>
%% </ul>.
%% @see remove_option()
-spec remove( valvex_ref()
            , queue_key()
            , remove_option()
            ) -> ok | key_find_error().
remove(Valvex, Key, Option) ->
  valvex_server:remove(Valvex, Key, Option).

%% @doc Pushes an item to the queue with the given key. Work can be any
%% 0 arity function.
-spec push( valvex_ref()
          , queue_key()
          , function()
          ) -> ok.
push(Valvex, Key, Work) ->
  valvex_server:push(Valvex, Key, {Work, erlang:timestamp()}).

%% @doc Gets the list of workers that are currently not undertaking work.
-spec get_available_workers(valvex_ref()) -> valvex_workers().
get_available_workers(Valvex) ->
  valvex_server:get_available_workers(Valvex).

%% @doc Gets the mumber of workers that are currently not undertaking work.
-spec get_available_workers_count(valvex_ref()) -> non_neg_integer().
get_available_workers_count(Valvex) ->
  length(valvex:get_available_workers(Valvex)).

%% @doc Gets the size of the queue with the given key.
-spec get_queue_size( valvex_ref()
                    , queue_key()
                    ) -> non_neg_integer() | key_find_error().
get_queue_size(Valvex, Key) ->
  valvex_server:get_queue_size(Valvex, Key).

%% @doc Pushes back a set amount of time in order to prevent spamming.
-spec pushback( valvex_ref()
              , queue_key()
              ) -> ok.
pushback(Valvex, Key) ->
  valvex_server:pushback(Valvex, Key).

%% @doc Notifies those listening via gen_event of various events happening
%% inside valvex.
-spec notify( valvex_ref()
            , any()
            ) -> ok.
notify(Valvex, Event) ->
  valvex_server:notify(Valvex, Event).

%% @doc Adds an event handler which can intercept events from valvex
%% and do various things.
-spec add_handler( valvex_ref()
                 , module()
                 , [any()]
                 ) -> ok.
add_handler(Valvex, Module, Args) ->
  valvex_server:add_handler(Valvex, Module, Args).

%% @doc Removes a previously added handler.
-spec remove_handler( valvex_ref()
                    , module()
                    , [any()]
                    ) -> ok.
remove_handler(Valvex, Module, Args) ->
  valvex_server:remove_handler(Valvex, Module, Args).

%% @doc Updates a key with a new set of queue settings.
-spec update(valvex_ref(), queue_key(), valvex_queue()) -> ok.
update(Valvex, Key, NuQ) ->
  valvex_server:update(Valvex, Key, NuQ).

%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
