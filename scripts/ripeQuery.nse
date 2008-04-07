require "ipOps"

id = "RIPE query"
description = "Connects to the RIPE database, extracts and prints the role: entry for the IP."
author = "Diman Todorov <diman.todorov@gmail.com>"
license = "Same as Nmap--See http://nmap.org/man/man-legal.html"

categories = {"discovery"}

hostrule = function(host, port)
	return not ipOps.isPrivate(host.ip)
end

action = function(host, port)
	local socket = nmap.new_socket()
	local status, line
	local result = ""

	socket:connect("whois.ripe.net", 43)
--	socket:connect("193.0.0.135", 43)
	socket:send(host.ip .. "\n")

	while true do
		local status, lines = socket:receive_lines(1)

		if not status then
			break
		else
			result = result .. lines
		end
	end
	socket:close()

	local value  = string.match(result, "role:(.-)\n")

	if (value == "see http://www.iana.org.") then
		value = nil
	end

	if (value == nil) then
		return
	end
	
	return "IP belongs to: " .. value:gsub("^%s*", "")
end
