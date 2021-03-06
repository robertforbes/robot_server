-module(robot_udp).
-export([
    start_server/0,
    start_server/1,
    start_udp_serial_server/1,
    start_udp_serial_server/3,
    display_controls/1,
    client/2,
    client/3]).

-define(SERVER_HOST, "localhost").
-define(SERVER_PORT, 1995).
-define(SERIAL_BAUD, 9600).

start_server() ->
    start_server(fun display_packet/1).

start_server(PktFun) ->
    spawn(fun() -> server(?SERVER_PORT, PktFun) end).

start_udp_serial_server(SerialDevice) ->
    start_udp_serial_server(SerialDevice, ?SERIAL_BAUD, ?SERVER_PORT).

start_udp_serial_server(SerialDevice, Baud, Port) ->
    SP = serial:start([{speed,Baud},{open,SerialDevice}]),
    Drive = fun(<<Speed:8, Direction:8>>) ->
                robot:drive(SP, Speed, Direction)
            end,
    spawn(fun() -> server(Port, Drive) end).

%% The server.

server(Port, PktFun) ->
    {ok, Socket} = gen_udp:open(Port, [binary]),
    io:format("Server opened socket: ~p~n", [Socket]),
    loop(Socket, PktFun).

loop(Socket, PktFun) ->
    receive
        {udp, Socket, Host, Port, Bin} = _Msg ->
            PktFun(Bin),
            gen_udp:send(Socket, Host, Port, term_to_binary(0)),
            loop(Socket, PktFun)
    end.

display_packet(PktBin) ->
    io:format("Server received: ~p~n", [PktBin]).

display_controls(<<Speed:8, Direction:8>>) ->
    io:format("Speed: ~p, Direction: ~p~n", [Speed, Direction]).

%% The client

client(Speed, Direction) ->
    client(?SERVER_HOST, Speed, Direction).

client(Host, Speed, Direction) ->
    {ok, Socket} = gen_udp:open(0, [binary]),
    io:format("Client opened socket: ~p~n", [Socket]),
    ok = gen_udp:send(Socket, Host, ?SERVER_PORT, list_to_binary([Speed, Direction])),

    Value = receive
                {udp, Socket, _, _, Bin} = Msg ->
                    io:format("Client received: ~p~n", [Msg]),
                    binary_to_term(Bin)
            after 2000 ->
                0
            end,
    gen_udp:close(Socket),
    Value.
