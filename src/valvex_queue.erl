-module(valvex_queue).

-export([ is_locked/2
        , is_tombstoned/2
        , lock/2
        , pop/2
        , pop_r/2
        , push/3
        , push_r/3
        , size/2
        , start_consumer/2
        , start_link/3
        , tombstone/2
        ]).

%%==============================================================================
%% Callbacks
%%==============================================================================
-callback start_link( Valvex :: valvex:valvex_ref()
                    , Q :: valvex:valvex_queue()
                    ) -> valvex:valvex_ref().

-callback pop( Q :: valvex:valvex_ref() ) -> any().
-callback pop_r( Q :: valvex:valvex_ref() ) -> any().

-callback push( Q :: valvex:valvex_ref()
              , Value :: valvex:valvex_q_item()
              ) -> ok.
-callback push_r( Q :: valvex:valvex_ref()
                , Value :: valvex:valvex_q_item()
                ) -> ok.

-callback tombstone( Q :: valvex:valvex_ref() ) -> ok.
-callback is_tombstoned(Q :: valvex:valvex_ref() ) -> true | false.

-callback lock( Q :: valvex:valvex_ref() ) -> ok.
-callback is_locked( Q :: valvex:valvex_ref() ) -> true | false.

-callback size( Q :: valvex:valvex_ref() ) -> non_neg_integer().

-callback start_consumer( Q :: valvex:valvex_ref() ) -> ok.

%%==============================================================================
%% API
%%==============================================================================
-spec start_link( valvex:queue_backend()
                , valvex:valvex_ref()
                , valvex:valvex_queue()
                ) -> valvex:valvex_ref().
start_link(Backend, Valvex, Q) ->
  Backend:start_link(Valvex, Q).

-spec pop(valvex:queue_backend(), valvex:valvex_ref()) -> any().
pop(Backend, Q) ->
  Backend:pop(Q).

-spec pop_r(valvex:queue_backend(), valvex:valvex_ref()) -> any().
pop_r(Backend, Q) ->
  Backend:pop_r(Q).

-spec push( valvex:queue_backend()
          , valvex:valvex_ref()
          , valvex:valvex_q_item()
          ) -> ok.
push(Backend, Q, Value) ->
  Backend:push(Q, Value).

-spec push_r( valvex:queue_backend()
            , valvex:valvex_ref()
            , valvex:valvex_q_item()
            ) -> ok.
push_r(Backend, Q, Value) ->
  Backend:push_r(Q, Value).

-spec start_consumer(valvex:queue_backend(), valvex:valvex_ref()) -> ok.
start_consumer(Backend, Q) ->
  Backend:start_consumer(Q).

-spec tombstone(valvex:queue_backend(), valvex:valvex_ref()) -> ok.
tombstone(Backend, Q) ->
  Backend:tombstone(Q).

-spec is_tombstoned(valvex:queue_backend(), valvex:valvex_ref()) -> true | false.
is_tombstoned(Backend, Q) ->
  Backend:is_tombstoned(Q).

-spec lock(valvex:queue_backend(), valvex:valvex_ref()) -> ok.
lock(Backend, Q) ->
  Backend:lock(Q).

-spec is_locked(valvex:queue_backend(), valvex:valvex_ref()) -> true | false.
is_locked(Backend, Q) ->
  Backend:is_locked(Q).

-spec size(valvex:queue_backend(), valvex:valvex_ref()) -> non_neg_integer().
size(Backend, Q) ->
  Backend:size(Q).

%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
