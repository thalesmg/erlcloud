-module(erlcloud_ec2_meta).

-include("erlcloud.hrl").
-include("erlcloud_aws.hrl").

-export([get_instance_metadata/0, get_instance_metadata/1, get_instance_metadata/2,
        get_instance_user_data/0, get_instance_user_data/1,
        get_instance_dynamic_data/0, get_instance_dynamic_data/1, get_instance_dynamic_data/2]).

-export([get_instance_metadata_v2/3, get_metadata_v2_session_token/1]).


-spec get_instance_metadata() -> {ok, binary()} | {error, erlcloud_aws:httpc_result_error()}.
get_instance_metadata() ->
   get_instance_metadata(erlcloud_aws:default_config()).

-spec get_instance_metadata(Config :: aws_config() ) -> {ok, binary()} | {error, erlcloud_aws:httpc_result_error()}.
get_instance_metadata(Config) ->
   get_instance_metadata("", Config).


%%%---------------------------------------------------------------------------
-spec get_instance_metadata( ItemPath :: string(), Config :: aws_config() ) -> {ok, binary()} | {error, erlcloud_aws:httpc_result_error()}.
%%%---------------------------------------------------------------------------
%% @doc Retrieve the instance meta data for the instance this code is running on. Will fail if not an EC2 instance.
%%
%% This convenience function will retrieve the instance id from the AWS metadata available at 
%% http://<host:port>/latest/meta-data/*
%% ItemPath allows fetching specific pieces of metadata.
%% <host:port> defaults to 169.254.169.254
%%
%%
get_instance_metadata(ItemPath, Config) ->
    MetaDataPath = "http://" ++ ec2_meta_host_port() ++ "/latest/meta-data/" ++ ItemPath,
    erlcloud_aws:http_body(erlcloud_httpc:request(MetaDataPath, get, [], <<>>, erlcloud_aws:get_timeout(Config), Config)).


-spec get_instance_user_data() -> {ok, binary()} | {error, erlcloud_aws:httpc_result_error()}.
get_instance_user_data() ->
   get_instance_user_data(erlcloud_aws:default_config()).

%% https://aws.amazon.com/blogs/security/defense-in-depth-open-firewalls-reverse-proxies-ssrf-vulnerabilities-ec2-instance-metadata-service/
get_instance_metadata_v2(ItemPath, Config, Opts) ->
    case Opts of
        #{session_token := Token} ->
            do_get_instance_metadata_v2(ItemPath, Token, Config);
        _ ->
            case get_metadata_v2_session_token(Config) of
                {ok, Token} ->
                    do_get_instance_metadata_v2(ItemPath, Token, Config);
                Error ->
                    Error
            end
    end.


do_get_instance_metadata_v2(ItemPath, Token, Config) ->
    MetaDataPath = "http://" ++ ec2_meta_host_port() ++ "/latest/meta-data/" ++ ItemPath,
    erlcloud_aws:http_body(erlcloud_httpc:request(
       MetaDataPath, get,
       [{"X-aws-ec2-metadata-token", Token}],
       <<>>, erlcloud_aws:get_timeout(Config), Config)).


get_metadata_v2_session_token(Config) ->
    MetaDataPath = "http://" ++ ec2_meta_host_port() ++ "/latest/api/token",
    %% https://github.com/boto/botocore/blob/8c517320c6a40cd91e8e7fbb05e27183ba2f6dce/botocore/utils.py#L372
    TokenTTL = "21600",
    erlcloud_aws:http_body(erlcloud_httpc:request(
        MetaDataPath, put,
        [{"X-aws-ec2-metadata-token-ttl-seconds", TokenTTL}],
        <<>>,
        erlcloud_aws:get_timeout(Config), Config)).

%%%---------------------------------------------------------------------------
-spec get_instance_user_data( Config :: aws_config() ) -> {ok, binary()} | {error, erlcloud_aws:httpc_result_error()}.
%%%---------------------------------------------------------------------------
%% @doc Retrieve the user data for the instance this code is running on. Will fail if not an EC2 instance.
%%
%% This convenience function will retrieve the user data the instance was started with, i.e. what's available at 
%% http://<host:port>/latest/user-data
%% <host:port> defaults to 169.254.169.254
%%
%%
get_instance_user_data(Config) ->
    UserDataPath = "http://" ++ ec2_meta_host_port() ++ "/latest/user-data/",
    erlcloud_aws:http_body(erlcloud_httpc:request(UserDataPath, get, [], <<>>, erlcloud_aws:get_timeout(Config), Config)).


-spec get_instance_dynamic_data() -> {ok, binary()} | {error, erlcloud_aws:httpc_result_error()}.
get_instance_dynamic_data() ->
   get_instance_dynamic_data(erlcloud_aws:default_config()).

-spec get_instance_dynamic_data(Config :: aws_config() ) -> {ok, binary()} | {error, erlcloud_aws:httpc_result_error()}.
get_instance_dynamic_data(Config) ->
   get_instance_dynamic_data("", Config).


%%%---------------------------------------------------------------------------
-spec get_instance_dynamic_data( ItemPath :: string(), Config :: aws_config() ) -> {ok, binary()} | {error, erlcloud_aws:httpc_result_error()}.
%%%---------------------------------------------------------------------------

get_instance_dynamic_data(ItemPath, Config) ->
    DynamicDataPath = "http://" ++ ec2_meta_host_port() ++ "/latest/dynamic/" ++ ItemPath,
    erlcloud_aws:http_body(erlcloud_httpc:request(DynamicDataPath, get, [], <<>>, erlcloud_aws:get_timeout(Config), Config)).

%%%------------------------------------------------------------------------------
%%% Internal functions.
%%%------------------------------------------------------------------------------

ec2_meta_host_port() ->
    {ok, EC2MetaHostPort} = application:get_env(erlcloud, ec2_meta_host_port),
    EC2MetaHostPort.
