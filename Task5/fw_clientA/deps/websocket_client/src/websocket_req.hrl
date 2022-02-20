-record(transport,
        {
         mod :: gen_tcp | ssl, %% Which module to use for transport
         name :: tcp | ssl,
         closed :: tcp_closed | ssl_closed, %% These are used to pattern match
         error :: tcp_error | ssl_error,  %% exact tuples in active mode
         opts :: list(term()) %% TODO I think there's a inets? type for this
        }).

-record(websocket_req, {
          protocol                        :: protocol(),
          host                            :: string(),
          port                            :: inet:port_number(),
          path                            :: string(),
          keepalive = infinity            :: infinity | integer(),
          keepalive_timer = undefined     :: undefined | reference(),
          keepalive_max_attempts = 1      :: non_neg_integer(), % Set to -1 to disable
          socket                          :: undefined | inet:socket() | ssl:sslsocket(),
          transport                       :: #transport{},
          key                             :: binary(),
          remaining = undefined           :: undefined | integer(),
          fin = undefined                 :: undefined | fin(),
          opcode = undefined              :: undefined | opcode(),
          continuation = undefined        :: undefined | binary(),
          continuation_opcode = undefined :: undefined | opcode()
         }).

-opaque req() :: #websocket_req{}.
-export_type([req/0]).

-type protocol() :: ws | wss.

-type frame() :: close | ping | pong
               | {text | binary | close | ping | pong, binary()}
               | {close, 1000..4999, binary()}.

-type opcode() :: 0 | 1 | 2 | 8 | 9 | 10.
-export_type([protocol/0, opcode/0, frame/0]).

-type fin() :: 0 | 1.
-export_type([fin/0]).
