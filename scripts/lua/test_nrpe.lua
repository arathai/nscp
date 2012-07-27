test = require("test_helper")

TestMessage = {
	uuid = nil,
	source = nil,
	command = nil,
	status = nil,
	message = nil,
	perfdata = nil,
	got_simple_response = false,
	got_response = false
}
	
TestNRPE = {
	requests = {}, 
	responses = {} 
}
function TestNRPE:install(arguments)
	local conf = Settings()
	
	conf:set_string('/modules', 'test_nrpe_server', 'NRPEServer')
	conf:set_string('/modules', 'test_nrpe_client', 'NRPEClient')
	conf:set_string('/modules', 'luatest', 'LuaScript')

	conf:set_string('/settings/luatest/scripts', 'test_nrpe', 'test_nrpe.lua')
	
	conf:set_string('/settings/NRPE/test_nrpe_server', 'port', '15666')
	conf:set_string('/settings/NRPE/test_nrpe_server', 'inbox', 'nrpe_test_inbox')
	conf:set_string('/settings/NRPE/test_nrpe_server', 'encryption', '1')

	conf:set_string('/settings/NRPE/test_nrpe_client/targets', 'nrpe_test_local', 'nrpe://127.0.0.1:15666')
	conf:set_string('/settings/NRPE/test_nrpe_client', 'channel', 'nrpe_test_outbox')
	--conf:save()
end

function TestNRPE:setup()
	local reg = Registry(plugin_id)
	reg:simple_query('check_py_nrpe_test_s', self, self.simple_handler, 'TODO')
	reg:query('check_py_nrpe_test', self, self.handler, 'TODO')
end
function TestNRPE:teardown()
end

function TestNRPE:uninstall()
end

function TestNRPE:help()
end

function TestNRPE:init(plugin_id)
end

function TestNRPE:shutdown()
end

function TestNRPE:has_response(id)
	return self.responses[id]
end

function TestNRPE:get_response(id)
	msg = self.requests[id]
	if msg == nil then
		msg = TestMessage
		msg.uuid=id
		self.responses[id] = msg
		return msg
	end
	return msg
end

function TestNRPE:set_response(msg)
	self.responses[msg.uuid] = msg
end

function TestNRPE:del_response(id)
	self.responses[id] = nil
end
		
function TestNRPE:get_request(id)
	msg = self.requests[id]
	if msg == nil then
		msg = TestMessage
		msg.uuid=id
		self.requests[id] = msg
		return msg
	end
	return msg
end

function TestNRPE:set_request(msg)
	self.requests[msg.uuid] = msg
end

function TestNRPE:del_request(id)
	self.requests[id] = nil
end

function TestNRPE:simple_handler(command, args)
	msg = self:get_response(args[0])
	msg.got_simple_response = true
	self:set_response(msg)
	rmsg = self:get_request(args[0])
	return rmsg.status, rmsg.message, rmsg.perfdata
end

function TestNRPE:handler(req)
	msg = self:get_response(args[0])
	msg.got_response = true
	self:set_response(msg)
	rmsg = self:get_request(args[0])
end

function TestNRPE:submit_payload(tag, ssl, length, source, status, message, perf, target)
	local core = Core()
	local result = test.TestResult:new{message='Testing NRPE: '..tag..' for '..target}
	
	local msg = protobuf.Plugin.QueryRequestMessage.new()
	hdr = msg:get_header()
	hdr:set_version(1)
	hdr:set_recipient_id(target)
	host = hdr:add_hosts()
	host:set_address("127.0.0.1:15666")
	host:set_id(target)
	if target == 'valid' then
	else
		enc = host:add_metadata()
		enc:set_key("use ssl")
		enc:set_value(tostring(ssl))
		enc = host:add_metadata()
		enc:set_key("payload length")
		enc:set_value(tostring(length))
		enc = host:add_metadata()
		enc:set_key("timeout")
		enc:set_value('5')
	end

	uid = string.random(12)
	payload = msg:add_payload()
	payload:set_command('check_py_nrpe_test_s')
	payload:set_arguments(1, uid)
	rmsg = self:get_request(uid)
	rmsg.status = status
	rmsg.message = message
	rmsg.perfdata = perf
	self:set_request(rmsg)
	serialized = msg:serialized()
	result_code, response = core:query('nrpe_forward', serialized)
	response_message = protobuf.Plugin.QueryResponseMessage.parsefromstring(response)
	--print(response_message:get_payload(1):get_message())


	found = False
	for i = 0,10 do
		if (self:has_response(uid)) then
			rmsg = self:get_response(uid)
			--#result.add_message(rmsg.got_response, 'Testing to recieve message using %s'%tag)
			result:add_message(rmsg.got_simple_response, 'Testing to recieve simple message using '..tag)
			result:add_message(response_message:size_payload() == 1, 'Verify that we only get one payload response for '..tag)
			pl = response_message:get_payload(1)
			result:assert_equals(pl:get_result(), test.status_to_int(status), 'Verify that status is sent through '..tag)
			result:assert_equals(pl:get_message(), rmsg.message, 'Verify that message is sent through '..tag)
			--#result.assert_equals(rmsg.perfdata, perf, 'Verify that performance data is sent through')
			self:del_response(uid)
			found = True
			break
		else
			log(string.format('Waiting for %s (%s/%s)', uid,tag,target))
			--sleep(500)
		end
	end
	if (not found) then
		result:add_message(false, string.format('Testing to recieve message using %s', tag))
	end
	
	return result
end

function TestNRPE:test_one(ssl, length, status)
	tag = string.format("%s/%d/%s", tostring(ssl), length, status)
	local result = test.TestResult:new{message=string.format('Testing: %s with various targets', tag)}
	for k,t in pairs({'valid', 'test_rp', 'invalid'}) do
		result:add(self:submit_payload(tag, ssl, length, tag .. 'src' .. tag, status, tag .. 'msg' .. tag, '', t))
	end
	return result
end

function TestNRPE:do_one_test(ssl, length)
	if ssl == nil then ssl = true end
	length = length or 1024
	
	local conf = Settings()
	local core = Core()
	conf:set_int('/settings/NRPE/test_nrpe_server', 'payload length', length)
	conf:set_bool('/settings/NRPE/test_nrpe_server', 'use ssl', ssl)
	conf:set_bool('/settings/NRPE/test_nrpe_server', 'allow arguments', true)
	core:reload('test_nrpe_server')

	conf:set_string('/settings/NRPE/test_nrpe_client/targets/default', 'address', 'nrpe://127.0.0.1:35666')
	conf:set_bool('/settings/NRPE/test_nrpe_client/targets/default', 'use ssl', not ssl)
	conf:set_int('/settings/NRPE/test_nrpe_client/targets/default', 'payload length', length*3)

	conf:set_string('/settings/NRPE/test_nrpe_client/targets/invalid', 'address', 'nrpe://127.0.0.1:25666')
	conf:set_bool('/settings/NRPE/test_nrpe_client/targets/invalid', 'use ssl', not ssl)
	conf:set_int('/settings/NRPE/test_nrpe_client/targets/invalid', 'payload length', length*2)

	conf:set_string('/settings/NRPE/test_nrpe_client/targets/valid', 'address', 'nrpe://127.0.0.1:15666')
	conf:set_bool('/settings/NRPE/test_nrpe_client/targets/valid', 'use ssl', ssl)
	conf:set_int('/settings/NRPE/test_nrpe_client/targets/valid', 'payload length', length)
	core:reload('test_nrpe_client')

	local result = test.TestResult:new{message="Testing "..tostring(ssl)..", "..tostring(length)}
	result:add(self:test_one(ssl, length, 'unknown'))
	result:add(self:test_one(ssl, length, 'ok'))
	result:add(self:test_one(ssl, length, 'warn'))
	result:add(self:test_one(ssl, length, 'crit'))
	return result
end


function TestNRPE:run()
	local result = test.TestResult:new{message="NRPE Test Suite"}
	result:add(self:do_one_test(true, 1024))
	result:add(self:do_one_test(false, 1024))
	result:add(self:do_one_test(true, 4096))
	result:add(self:do_one_test(true, 65536))
	result:add(self:do_one_test(true, 1048576))
	return result
end


instances = { TestNRPE }
test.install_test_manager(instances)