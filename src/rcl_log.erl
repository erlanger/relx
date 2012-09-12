%% -*- mode: Erlang; fill-column: 80; comment-column: 75; -*-
%%% Copyright 2012 Erlware, LLC. All Rights Reserved.
%%%
%%% This file is provided to you under the Apache License,
%%% Version 2.0 (the "License"); you may not use this file
%%% except in compliance with the License.  You may obtain
%%% a copy of the License at
%%%
%%%   http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing,
%%% software distributed under the License is distributed on an
%%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%%% KIND, either express or implied.  See the License for the
%%% specific language governing permissions and limitations
%%% under the License.
%%%---------------------------------------------------------------------------
%%% @author Eric Merritt <ericbmerritt@gmail.com>
%%% @copyright (C) 2012 Erlware, LLC.
%%%
%%% @doc This provides simple output functions for relcool. You should use this
%%% to talk to the users if you are wrting code for the system
-module(rcl_log).

-export([new/1,
         log/4,
         should/2,
         debug/2,
         debug/3,
         info/2,
         info/3,
         error/2,
         error/3,
         log_level/1,
         atom_log_level/1,
         format/1]).

-export_type([int_log_level/0,
              log_level/0,
              log_fun/0,
              t/0]).

-include_lib("relcool/include/relcool.hrl").

%%============================================================================
%% types
%%============================================================================

-type int_log_level() :: 0..2.
%% Why no warn? because for our purposes there is no difference between error
%% and warn
-type log_level() :: error | info | debug.
-opaque t() :: {?MODULE, int_log_level()}.

-type log_fun() :: fun(() -> iolist()).

%%============================================================================
%% API
%%============================================================================
%% @doc Create a new 'log level' for the system
-spec new(int_log_level() | log_level()) -> t().
new(LogLevel) when LogLevel >= 0, LogLevel =< 2 ->
    {?MODULE, LogLevel};
new(AtomLogLevel)
  when AtomLogLevel =:= error;
       AtomLogLevel =:= info;
       AtomLogLevel =:= debug ->
    LogLevel = case AtomLogLevel of
                   error -> 0;
                   info -> 1;
                   debug -> 2
               end,
    new(LogLevel).


%% @doc log at the debug level given the current log state with a string or
%% function that returns a string
-spec debug(t(), string() | log_fun()) -> ok.
debug(LogState, Fun)
  when erlang:is_function(Fun) ->
    log(LogState, ?RCL_DEBUG, Fun);
debug(LogState, String) ->
    debug(LogState, "~s~n", [String]).

%% @doc log at the debug level given the current log state with a format string
%% and argements @see io:format/2
-spec debug(t(), string(), [any()]) -> ok.
debug(LogState, FormatString, Args) ->
    log(LogState, ?RCL_DEBUG, FormatString, Args).

%% @doc log at the info level given the current log state with a string or
%% function that returns a string
-spec info(t(), string() | log_fun()) -> ok.
info(LogState, Fun)
    when erlang:is_function(Fun) ->
    log(LogState, ?RCL_INFO, Fun);
info(LogState, String) ->
    info(LogState, "~s~n", [String]).

%% @doc log at the info level given the current log state with a format string
%% and argements @see io:format/2
-spec info(t(), string(), [any()]) -> ok.
info(LogState, FormatString, Args) ->
    log(LogState, ?RCL_INFO, FormatString, Args).

%% @doc log at the error level given the current log state with a string or
%% format string that returns a function
-spec error(t(), string() | log_fun()) -> ok.
error(LogState, Fun)
    when erlang:is_function(Fun) ->
    log(LogState, ?RCL_ERROR, Fun);
error(LogState, String) ->
    error(LogState, "~s~n", [String]).

%% @doc log at the error level given the current log state with a format string
%% and argements @see io:format/2
-spec error(t(), string(), [any()]) -> ok.
error(LogState, FormatString, Args) ->
    log(LogState, ?RCL_ERROR, FormatString, Args).

%% @doc Execute the fun passed in if log level is as expected.
-spec log(t(), int_log_level(), log_fun()) -> ok.
log({?MODULE, DetailLogLevel}, LogLevel, Fun)
    when DetailLogLevel >= LogLevel ->
    io:format("~s~n", [Fun()]);
log(_, _, _) ->
    ok.


%% @doc when the module log level is less then or equal to the log level for the
%% call then write the log info out. When its not then ignore the call.
-spec log(t(), int_log_level(), string(), [any()]) -> ok.
log({?MODULE, DetailLogLevel}, LogLevel, FormatString, Args)
  when DetailLogLevel >= LogLevel,
       erlang:is_list(Args) ->
    io:format(FormatString, Args);
log(_, _, _, _) ->
    ok.

%% @doc return a boolean indicating if the system should log for the specified
%% levelg
-spec should(t(), int_log_level() | any()) -> boolean().
should({?MODULE, DetailLogLevel}, LogLevel)
  when DetailLogLevel >= LogLevel ->
    true;
should(_, _) ->
    false.

%% @doc get the current log level as an integer
-spec log_level(t()) -> int_log_level().
log_level({?MODULE, DetailLogLevel}) ->
    DetailLogLevel.

%% @doc get the current log level as an atom
-spec atom_log_level(t()) -> log_level().
atom_log_level({?MODULE, ?RCL_ERROR}) ->
    error;
atom_log_level({?MODULE, ?RCL_INFO}) ->
    info;
atom_log_level({?MODULE, ?RCL_DEBUG}) ->
    debug.

-spec format(t()) -> iolist().
format(Log) ->
    [<<"(">>,
     erlang:integer_to_list(log_level(Log)), <<":">>,
     erlang:atom_to_list(atom_log_level(Log)),
     <<")">>].

%%%===================================================================
%%% Test Functions
%%%===================================================================

-ifndef(NOTEST).
-include_lib("eunit/include/eunit.hrl").

should_test() ->
    ErrorLogState = new(error),
    ?assertMatch(true, should(ErrorLogState, ?RCL_ERROR)),
    ?assertMatch(true, not should(ErrorLogState, ?RCL_INFO)),
    ?assertMatch(true, not should(ErrorLogState, ?RCL_DEBUG)),
    ?assertEqual(?RCL_ERROR, log_level(ErrorLogState)),
    ?assertEqual(error, atom_log_level(ErrorLogState)),

    InfoLogState = new(info),
    ?assertMatch(true, should(InfoLogState, ?RCL_ERROR)),
    ?assertMatch(true, should(InfoLogState, ?RCL_INFO)),
    ?assertMatch(true, not should(InfoLogState, ?RCL_DEBUG)),
    ?assertEqual(?RCL_INFO, log_level(InfoLogState)),
    ?assertEqual(info, atom_log_level(InfoLogState)),

    DebugLogState = new(debug),
    ?assertMatch(true, should(DebugLogState, ?RCL_ERROR)),
    ?assertMatch(true, should(DebugLogState, ?RCL_INFO)),
    ?assertMatch(true, should(DebugLogState, ?RCL_DEBUG)),
    ?assertEqual(?RCL_DEBUG, log_level(DebugLogState)),
    ?assertEqual(debug, atom_log_level(DebugLogState)).

-endif.