#!/usr/bin/env ruby
require 'rubygems'
require 'json'
require 'net/http'
require 'fileutils'

HOST = 'api.iquestria.net'
boundary = '----BOUND----'
DEFAULT_APP_ID = "t5geMqm93W0BMBm7"

case ARGV[0]
when "login"
	if ARGV.length < 3 then
		STDOUT.puts "Invalid number of params"
		Kernel.exit(false)
	end

	username = ARGV[1]
	password = ARGV[2]

	if ARGV[3] == "default" then
		appid = DEFAULT_APP_ID
	else
		appid = ARGV[3]
	end

	if ARGV[4] == nil then
		FileUtils.mkdir_p Dir.home + '/.iquestria/'
		file = Dir.home + "/.iquestria/" + appid + ".token"
	else
		file = ARGV[4]
	end
	PATH = '/doLogin/authUser.php'
	data = <<-EOF
--#{boundary}\r
content-disposition: form-data; name="username"\r
\r
#{username}\r
--#{boundary}\r
content-disposition: form-data; name="password";\r
\r
#{password}\r
--#{boundary}\r
content-disposition: form-data; name="appid";\r
\r
#{appid}\r
--#{boundary}--\r
EOF
	headers ={
		'Content-Length' => data.length.to_s,
		'Content-Type' => "multipart/form-data; boundary=#{boundary}",
		'User-Agent' => "iQuestRuby/0.1",
		'Accept' => 'application/json'
	}
	env = ENV['http_proxy']
	if env then
		uri = URI(env)
		proxy_host, proxy_port = uri.host, uri.port
	else
		proxy_host, proxy_port = nil, nil
	end
	Net::HTTP::Proxy(proxy_host, proxy_port).start(HOST,80) {|http|
		res = http.post(PATH,data,headers)
		response = res.response.body
		resjson = JSON.parse(res.response.body)
		if resjson["status"] == 'success' then
			File.open(file, 'w') do |file|
				file.puts response
			end
			appname = resjson["app"]["name"]
			appdeveloper = resjson["app"]["developer"]
			appdomain = resjson["app"]["domain"]
			STDOUT.puts <<-EOF
Successfully logged in

App Info:
Name: #{appname}
Developer: #{appdeveloper}
Domain: #{appdomain}

EOF
			STDOUT.puts "Response file placed in " + file
		else
			STDOUT.puts "Sign in error: " + resjson["error"]
		end
	}

when "list"

	if ARGV[1] == nil then
		auth_file = Dir.home + "/.iquestria/" + DEFAULT_APP_ID + ".token"
	else
		auth_file = ARGV[1]
	end

	body = ""

	File.open(auth_file, "r") do |f|
		f.each_line do |line|
			body += line
		end
	end

	jsonbody = JSON.parse(body)
	auth_token = jsonbody["token"]

	PATH = '/listApps.php'
	data = <<-EOF
--#{boundary}\r
content-disposition: form-data; name="auth_token"\r
\r
#{auth_token}\r
--#{boundary}--\r
EOF
	headers ={
		'Content-Length' => data.length.to_s,
		'Content-Type' => "multipart/form-data; boundary=#{boundary}",
		'User-Agent' => "iQuestRuby/0.1",
		'Accept' => 'application/json'
	}
	env = ENV['http_proxy']
	if env then
		uri = URI(env)
		proxy_host, proxy_port = uri.host, uri.port
	else
		proxy_host, proxy_port = nil, nil
	end

	Net::HTTP::Proxy(proxy_host, proxy_port).start(HOST,80) {|http|
		res = http.post(PATH,data,headers)
		response = res.response.body
		resjson = JSON.parse(res.response.body)
		if resjson["status"] == 'success' then
			resjson["apps"].each do |app|
				appname = app["name"]
				appid = app["id"]
				STDOUT.puts <<-EOF
---------------------
App Name: #{appname}
ID: #{appid}
				EOF
			end
			STDOUT.puts "---------------------"
		else
			STDOUT.puts "Error: " + resjson["error"]
		end
	}
else
	STDOUT.puts <<-EOF

iQuestria Developer Tool v0.1
Command line arguments:
    login <username> <password> <appid> [file] - Logs into <appid> and writes JSON respsonse to [file]
                                                 (use "default" for <appid> to sign into developer app)
                                                 (if file is not specified, it uses ~/.iquestria/<appid>.token)
    list [response-file]                       - List all apps and their ids (must log into developer app first)

EOF
end