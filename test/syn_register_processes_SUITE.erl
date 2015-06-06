%% ==========================================================================================================
%% Syn - A global process registry.
%%
%% Copyright (C) 2015, Roberto Ostinelli <roberto@ostinelli.net>.
%% All rights reserved.
%%
%% The MIT License (MIT)
%%
%% Copyright (c) 2015 Roberto Ostinelli
%%
%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%% THE SOFTWARE.
%% ==========================================================================================================
-module(syn_register_processes_SUITE).

%% callbacks
-export([all/0]).
-export([init_per_suite/1, end_per_suite/1]).
-export([groups/0, init_per_group/2, end_per_group/2]).

%% internal
-export([process_main/0]).

%% tests
-export([
    single_node_when_mnesia_is_ram_find_by_key/1,
    single_node_when_mnesia_is_ram_find_by_pid/1,
    single_node_when_mnesia_is_ram_re_register_error/1,
    single_node_when_mnesia_is_disc_find_by_key/1
]).
-export([
    two_nodes_when_mnesia_is_ram_find_by_key/1,
    two_nodes_when_mnesia_is_disc_find_by_pid/1
]).

%% include
-include_lib("common_test/include/ct.hrl").


%% ===================================================================
%% Callbacks
%% ===================================================================

%% -------------------------------------------------------------------
%% Function: all() -> GroupsAndTestCases | {skip,Reason}
%% GroupsAndTestCases = [{group,GroupName} | TestCase]
%% GroupName = atom()
%% TestCase = atom()
%% Reason = term()
%% -------------------------------------------------------------------
all() ->
    [
        {group, single_node_process_registration},
        {group, two_nodes_process_registration}
    ].

%% -------------------------------------------------------------------
%% Function: groups() -> [Group]
%% Group = {GroupName,Properties,GroupsAndTestCases}
%% GroupName = atom()
%% Properties = [parallel | sequence | Shuffle | {RepeatType,N}]
%% GroupsAndTestCases = [Group | {group,GroupName} | TestCase]
%% TestCase = atom()
%% Shuffle = shuffle | {shuffle,{integer(),integer(),integer()}}
%% RepeatType = repeat | repeat_until_all_ok | repeat_until_all_fail |
%%			   repeat_until_any_ok | repeat_until_any_fail
%% N = integer() | forever
%% -------------------------------------------------------------------
groups() ->
    [
        {single_node_process_registration, [shuffle], [
            single_node_when_mnesia_is_ram_find_by_key,
            single_node_when_mnesia_is_ram_find_by_pid,
            single_node_when_mnesia_is_ram_re_register_error,
            single_node_when_mnesia_is_disc_find_by_key
        ]},
        {two_nodes_process_registration, [shuffle], [
            two_nodes_when_mnesia_is_ram_find_by_key,
            two_nodes_when_mnesia_is_disc_find_by_pid
        ]}
    ].
%% -------------------------------------------------------------------
%% Function: init_per_suite(Config0) ->
%%				Config1 | {skip,Reason} |
%%              {skip_and_save,Reason,Config1}
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% -------------------------------------------------------------------
init_per_suite(Config) ->
    %% config
    [
        {slave_node_short_name, syn_slave}
        | Config
    ].

%% -------------------------------------------------------------------
%% Function: end_per_suite(Config0) -> void() | {save_config,Config1}
%% Config0 = Config1 = [tuple()]
%% -------------------------------------------------------------------
end_per_suite(_Config) -> ok.

%% -------------------------------------------------------------------
%% Function: init_per_group(GroupName, Config0) ->
%%				Config1 | {skip,Reason} |
%%              {skip_and_save,Reason,Config1}
%% GroupName = atom()
%% Config0 = Config1 = [tuple()]
%% Reason = term()
%% -------------------------------------------------------------------
init_per_group(two_nodes_process_registration, Config) ->
    %% get slave node short name
    SlaveNodeShortName = proplists:get_value(slave_node_short_name, Config),
    {ok, SlaveNodeName} = syn_test_suite_helper:start_slave(SlaveNodeShortName),
    %% config
    [
        {slave_node_name, SlaveNodeName}
        | Config
    ];
init_per_group(_GroupName, Config) -> Config.

%% -------------------------------------------------------------------
%% Function: end_per_group(GroupName, Config0) ->
%%				void() | {save_config,Config1}
%% GroupName = atom()
%% Config0 = Config1 = [tuple()]
%% -------------------------------------------------------------------
end_per_group(two_nodes_mnesia_creation, Config) ->
    %% get slave node name
    SlaveNodeName = proplists:get_value(slave_node_name, Config),
    %% clean
    syn_test_suite_helper:clean_after_test(SlaveNodeName),
    %% stop slave
    syn_test_suite_helper:stop_slave(SlaveNodeName);
end_per_group(_GroupName, _Config) ->
    syn_test_suite_helper:clean_after_test().

%% ===================================================================
%% Tests
%% ===================================================================
single_node_when_mnesia_is_ram_find_by_key(_Config) ->
    %% set schema location
    application:set_env(mnesia, schema_location, ram),
    %% start
    ok = syn:start(),
    %% start process
    Pid = start_process(),
    %% retrieve
    undefined = syn:find_by_key(<<"my proc">>),
    %% register
    ok = syn:register(<<"my proc">>, Pid),
    %% retrieve
    Pid = syn:find_by_key(<<"my proc">>),
    %% kill process
    kill_process(Pid),
    timer:sleep(100),
    %% retrieve
    undefined = syn:find_by_key(<<"my proc">>).

single_node_when_mnesia_is_ram_find_by_pid(_Config) ->
    %% set schema location
    application:set_env(mnesia, schema_location, ram),
    %% start
    ok = syn:start(),
    %% start process
    Pid = start_process(),
    %% register
    ok = syn:register(<<"my proc">>, Pid),
    %% retrieve
    <<"my proc">> = syn:find_by_pid(Pid),
    %% kill process
    kill_process(Pid),
    timer:sleep(100),
    %% retrieve
    undefined = syn:find_by_pid(Pid).

single_node_when_mnesia_is_ram_re_register_error(_Config) ->
    %% set schema location
    application:set_env(mnesia, schema_location, ram),
    %% start
    ok = syn:start(),
    %% start process
    Pid = start_process(),
    Pid2 = start_process(),
    %% register
    ok = syn:register(<<"my proc">>, Pid),
    {error, already_taken} = syn:register(<<"my proc">>, Pid2),
    %% retrieve
    Pid = syn:find_by_key(<<"my proc">>),
    %% kill process
    kill_process(Pid),
    timer:sleep(100),
    %% retrieve
    undefined = syn:find_by_key(<<"my proc">>),
    %% reuse
    ok = syn:register(<<"my proc">>, Pid2),
    %% retrieve
    Pid2 = syn:find_by_key(<<"my proc">>),
    %% kill process
    kill_process(Pid),
    timer:sleep(100),
    %% retrieve
    undefined = syn:find_by_pid(Pid).

single_node_when_mnesia_is_disc_find_by_key(_Config) ->
    %% set schema location
    application:set_env(mnesia, schema_location, disc),
    %% create schema
    mnesia:create_schema([node()]),
    %% start
    ok = syn:start(),
    %% start process
    Pid = start_process(),
    %% retrieve
    undefined = syn:find_by_key(<<"my proc">>),
    %% register
    ok = syn:register(<<"my proc">>, Pid),
    %% retrieve
    Pid = syn:find_by_key(<<"my proc">>),
    %% kill process
    kill_process(Pid),
    timer:sleep(100),
    %% retrieve
    undefined = syn:find_by_key(<<"my proc">>).

two_nodes_when_mnesia_is_ram_find_by_key(Config) ->
    %% get slave
    SlaveNodeName = proplists:get_value(slave_node_name, Config),
    %% set schema location
    application:set_env(mnesia, schema_location, ram),
    rpc:call(SlaveNodeName, mnesia, schema_location, [ram]),
    %% start
    ok = syn:start(),
    ok = rpc:call(SlaveNodeName, syn, start, []),
    timer:sleep(100),
    %% start process
    Pid = start_process(),
    %% retrieve
    undefined = syn:find_by_key(<<"my proc">>),
    undefined = rpc:call(SlaveNodeName, syn, find_by_key, [<<"my proc">>]),
    %% register
    ok = syn:register(<<"my proc">>, Pid),
    %% retrieve
    Pid = syn:find_by_key(<<"my proc">>),
    Pid = rpc:call(SlaveNodeName, syn, find_by_key, [<<"my proc">>]),
    %% kill process
    kill_process(Pid),
    timer:sleep(100),
    %% retrieve
    undefined = syn:find_by_key(<<"my proc">>),
    undefined = rpc:call(SlaveNodeName, syn, find_by_key, [<<"my proc">>]).

two_nodes_when_mnesia_is_disc_find_by_pid(Config) ->
    %% get slave
    SlaveNodeName = proplists:get_value(slave_node_name, Config),
    %% set schema location
    application:set_env(mnesia, schema_location, disc),
    rpc:call(SlaveNodeName, mnesia, schema_location, [disc]),
    %% create schema
    mnesia:create_schema([node(), SlaveNodeName]),
    %% start
    ok = syn:start(),
    ok = rpc:call(SlaveNodeName, syn, start, []),
    timer:sleep(100),
    %% start process
    Pid = start_process(),
    %% register
    ok = syn:register(<<"my proc">>, Pid),
    %% retrieve
    <<"my proc">> = syn:find_by_pid(Pid),
    <<"my proc">> = rpc:call(SlaveNodeName, syn, find_by_pid, [Pid]),
    %% kill process
    kill_process(Pid),
    timer:sleep(100),
    %% retrieve
    undefined = syn:find_by_pid(Pid),
    undefined = rpc:call(SlaveNodeName, syn, find_by_pid, [Pid]).

%% ===================================================================
%% Internal
%% ===================================================================
start_process() ->
    Pid = spawn(?MODULE, process_main, []),
    Pid.

kill_process(Pid) ->
    exit(Pid, kill).

process_main() ->
    receive
        shutdown -> ok
    end.