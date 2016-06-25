%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @author Howard Beard-Marlowe <howardbm@live.se>
%%% @copyright 2016 Howard Beard-Marlowe
%%% @version 0.1.0
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @doc valvex_queue
%%
%% This module defines the behaviour any queue backend should have
%% read through the readme and the documentation for more info.

-module(valvex_queue).

-export([ crossover/3
        , is_consuming/2
        , is_locked/2
        , is_tombstoned/2
        , lock/2
        , pop/2
        , pop_r/2
        , push/3
        , push_r/3
        , size/2
        , start_consumer/2
        , start_link/3
        , stop_consumer/2
        , tombstone/2
        , unlock/2
        ]).

%%==============================================================================
%% Types
%%==============================================================================

-type queue_state() :: #{ key        => valvex:queue_key()
                        , threshold  => non_neg_integer()
                        , timeout    => non_neg_integer()
                        , pushback   => non_neg_integer()
                        , backend    => module()
                        , size       => non_neg_integer()
                        , poll_rate  => non_neg_integer()
                        , queue      => queue:queue()
                        , q          => valvex:valvex_queue()
                        , locked     => true | false
                        , tombstoned => true | false
                        , valvex     => valvex:valvex_ref()
                        , queue_pid  => valvex:valvex_ref()
                        , consumer   => undefined | timer:tref()
                        }.

-export_type([queue_state/0]).

%%======================================================================================================================
%% Callbacks
%%======================================================================================================================

-callback crossover(Q :: valvex:valvex_ref(), NuQ :: valvex:valvex_queue()) -> ok.

-callback is_consuming(Q :: valvex:valvex_ref() ) -> true | false.

-callback is_locked(Q :: valvex:valvex_ref() ) -> true | false.

-callback is_tombstoned(Q :: valvex:valvex_ref() ) -> true | false.

-callback lock(Q :: valvex:valvex_ref() ) -> ok.

-callback pop(Q :: valvex:valvex_ref() ) -> any().

-callback pop_r(Q :: valvex:valvex_ref() ) -> any().

-callback push(Q :: valvex:valvex_ref(), Value :: valvex:valvex_q_item()) -> ok.

-callback push_r(Q :: valvex:valvex_ref(), Value :: valvex:valvex_q_item()) -> ok.

-callback size( Q :: valvex:valvex_ref() ) -> non_neg_integer().

-callback start_consumer( Q :: valvex:valvex_ref() ) -> ok.

-callback start_link(Valvex :: valvex:valvex_ref(), Q :: valvex:valvex_queue()) -> valvex:valvex_ref().

-callback stop_consumer( Q :: valvex:valvex_ref() ) -> ok.

-callback tombstone( Q :: valvex:valvex_ref() ) -> ok.

-callback unlock( Q :: valvex:valvex_ref() ) -> ok.

%%======================================================================================================================
%% API
%%======================================================================================================================

%% @doc This defines the crossover behaviour for your queue should you be developing
%% your own backend take a look at how it is done in other stock modules if your module cannot
%% work with this behaviour for any reason it is important that the user is made aware and something is logged.
-spec crossover(valvex:queue_backend(), valvex:valvex_ref(), valvex:valvex_queue()) -> ok.
crossover(Backend, Q, NuQ) ->
  Backend:crossover(Q, NuQ).

%% @doc Returns true if the consumer is started, false otherwise.
-spec is_consuming(valvex:queue_backend(), valvex:valvex_ref()) -> true | false.
is_consuming(Backend, Q) ->
  Backend:is_consuming(Q).

%% @doc Whenever needed this should reply true or false depending on if
%% the queue is locked, a locked queue is one that cannot be pushed to
%% remaining work may continue to be consumed however view the stock
%% backends or the readme for more info.
-spec is_locked(valvex:queue_backend(), valvex:valvex_ref()) -> true | false.
is_locked(Backend, Q) ->
  Backend:is_locked(Q).

%% @doc Whenever needed this should reply true or false depending on if
%% the queue is tombstoned, a tombstoned queue is marked for deletion
%% and will delete itself when all work is consumed. A tombstoned
%% queue does not have to be locked, this simply means it will stay
%% alive as long as work is being passed to it.
-spec is_tombstoned(valvex:queue_backend(), valvex:valvex_ref()) -> true | false.
is_tombstoned(Backend, Q) ->
  Backend:is_tombstoned(Q).

%% @doc This will lock a queue, a locked queue cannot be pushed to.
-spec lock(valvex:queue_backend(), valvex:valvex_ref()) -> ok.
lock(Backend, Q) ->
  Backend:lock(Q).

%% @doc This will pop the queue, depending on your backends behaviour
%% this can have different conotations see the documentation for your
%% specific backend for more info.
-spec pop(valvex:queue_backend(), valvex:valvex_ref()) -> any().
pop(Backend, Q) ->
  Backend:pop(Q).

%% @doc This will pop the queue but with the reverse operation of pop()
%% this can have different conotations depending on your backends
%% behaviour see the documentation for more info.
-spec pop_r(valvex:queue_backend(), valvex:valvex_ref()) -> any().
pop_r(Backend, Q) ->
  Backend:pop_r(Q).

%% @doc This will push a queue item to the queue, this can have different conotations
%% depending on your backend view its documentation for more information.
%% @see valvex:valvex_q_item()
-spec push(valvex:queue_backend(), valvex:valvex_ref(), valvex:valvex_q_item()) -> ok.
push(Backend, Q, Value) ->
  Backend:push(Q, Value).

%% @doc This will do the reverse operation of push, this can have different conotations
%% depending on your backend view its documentation for more information.
-spec push_r( valvex:queue_backend(), valvex:valvex_ref(), valvex:valvex_q_item()) -> ok.
push_r(Backend, Q, Value) ->
  Backend:push_r(Q, Value).

%% @doc This function should retrieve the current size of the queue, if for some reason
%% this is costly with your implementation make sure the user is notified this doesnt
%% work.
-spec size(valvex:queue_backend(), valvex:valvex_ref()) -> non_neg_integer().
size(Backend, Q) ->
  Backend:size(Q).

%% @doc This function should start your consumer, this will be a regularly run
%% function that slurps the queue.
-spec start_consumer(valvex:queue_backend(), valvex:valvex_ref()) -> ok.
start_consumer(Backend, Q) ->
  Backend:start_consumer(Q).

-spec start_link(valvex:queue_backend(), valvex:valvex_ref(), valvex:valvex_queue()) -> {ok, valvex:valvex_ref()}.
start_link(Backend, Valvex, Q) ->
  Backend:start_link(Valvex, Q).

%% @doc This function should stop the consumer, note that it should not remove the queue
%% entirely.
-spec stop_consumer(valvex:queue_backend(), valvex:valvex_ref()) -> ok.
stop_consumer(Backend, Q) ->
  Backend:stop_consumer(Q).

%% @doc This function marks the queue for deletion, once the queue is empty it should be removed
%% note a queue does not have to be locked to be tombstoned.
-spec tombstone(valvex:queue_backend(), valvex:valvex_ref()) -> ok.
tombstone(Backend, Q) ->
  Backend:tombstone(Q).

%% @doc This function unlocks a locked queue, it is idempotent.
-spec unlock(valvex:queue_backend(), valvex:valvex_ref()) -> ok.
unlock(Backend, Q) ->
  Backend:unlock(Q).

%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
