-- TYPEDEF
-- Define connection type
type Connection = {
	Pause: () -> nil,
	Resume: () -> nil,
	Disconnect: () -> nil	
};

-- Define event type
type Event = {
	Fire: (...any?) -> nil,	
	ClearConnections: () -> nil,
	Destroy: () -> nil,
	Once: (callback: (...any?) -> nil, ...any?) -> Connection,
	Connect: (callback: (...any?) -> nil, ...any?) -> Connection,
	OnceParallel: (callback: (...any?) -> nil, ...any?) -> Connection,
	ConnectParallel: (callback: (...any?) -> nil, ...any?) -> Connection,
	BindFire: () -> (...any?)
};

-- DATA
local eventId = 0; -- event id counter
local events = {}; -- stores events
local namedEvents = {}; -- stores ids of named events (so they can be retrieved by name)

-- CONNECTION
local connection;
connection = {
	new = function(attachedEventId: number, callback: (...any?) -> nil, parallel: boolean, id: number, once: boolean, ...): Connection
		
		-- Connection constructor
		
		local parameters = ... ~= nil and {...};
		print(parameters)
		
		local newConnection = setmetatable({
			attachedEventId = attachedEventId,
			id = id,
			once = once,
			parallel = parallel,
			paused = false,
			passedParameters = parameters,
			callback = callback,
		}, connection);
		
		return newConnection;
		
	end,	
};
connection.__index = connection;

function connection:Signal(...) -- Fire the connected function with stored values as well as the ones passed when signal was fired
	
	local parametersToPass = (self.passedParameters) and {table.unpack(self.passedParameters), ...} or {...};
	
	-- Thread function if asynchronous 
	if (self.parallel) then 
		task.spawn(self.callback, table.unpack(parametersToPass));
	else
		self.callback(table.unpack(parametersToPass));
	end
	
	if (self.once) then
		self:Disconnect();
	end
end

function connection:Pause() -- Prevents the connection from being signaled when event is fired
	self.paused = true;
end

function connection:Resume() -- Enables the connection to be signaled when event is fired
	self.paused = false;
end

function connection:Disconnect() -- Disconnects connection from event and clears memory
	rawset(events[self.attachedEventId].connected, self.id, nil);
	setmetatable(self, nil);
end

-- HIGH OPERATOR FUNCTIONS

local function createConnection(self, callback, parallel, once, ...)
	self.connectionId += 1;
	local newConnection = connection.new(self.id, callback, parallel, self.connectionId, once, ...);
	newConnection.id = self.connectionId;
	self.connected[self.connectionId] = newConnection;
	return newConnection;
end

-- EVENT
local event;
event = {
	getEvent = function(identifier, waitTime: number) -- retrieve event based on name or id
		repeat task.wait() until (events[namedEvents[identifier]] or events[identifier]);
		return events[namedEvents[identifier]] or events[identifier];
	end,
	new = function(name: string): Event -- Event Construction
		
		-- Increase event counter
		eventId += 1;
		
		local id = eventId;
		
		local newEvent = setmetatable({
			id = id,
			name = name,
			connectionId = 0,
			connected = {},
		}, event);
		
		events[eventId] = newEvent;
		
		if (name) then 
			
			-- Preventing Overlapping Event names
			if (namedEvents[name]) then error("Attempted to override event ", name) end;
			
			namedEvents[name] = id;
			
		end
		
		return events[eventId];
		
	end,	
};
event.__index = event;

function event:__call(...) -- When you call the event directly, it fires the event
	self:Fire(...);
end

function event:ClearConnections() -- Clear all connections and free memory
	
	self.connectionId = 0;
	
	-- Disconnect and clear memory of connected tables
	for _, connection in pairs(self.connected) do
		connection:Disconnect();
	end
	
end

function event:Destroy() -- Clear memory of connections and event
	
	-- Remove event name from list
	if (self.name) then 
		rawset(namedEvents, self.name, nil);
	end
	
	-- Free memory
	self:ClearConnections();
	rawset(events, self.id, nil);
	setmetatable(self, nil);
	
end

function event:Connect(callback: (...any?) -> nil, ...): Connection -- Connect a function and store desired parameters 
	assert(callback, "Callback cannot be nil; (Event: " .. (self.name or self.id));
	return createConnection(self, callback, false, false, ...);
end

function event:Once(callback: (...any?) -> nil, ...): Connection -- Connect a function and store desired parameters that after being signaled clears its memory. 
	assert(callback, "Callback cannot be nil; (Event: " .. (self.name or self.id));
	return createConnection(self, callback, false, true, ...);
end

function event:ConnectParallel(callback: (...any?) -> nil, ...): Connection -- Connect an asynchronous function and store desired parameters 
	assert(callback, "Callback cannot be nil; (Event: " .. (self.name or self.id));
	return createConnection(self, callback, true, false, ...);
end

function event:OnceParallel(callback: (...any?) -> nil, ...): Connection -- Connect an asynchronous function and store desired parameters that after being signaled clears its memory. 
	assert(callback, "Callback cannot be nil; (Event: " .. (self.name or self.id));
	return createConnection(self, callback, true, true, ...);
end

function event:Fire(...) -- Signal all connected functions with passed parameters
	
	for _, connection in pairs(self.connected) do
		
		if (connection.paused) then continue end;
		
		connection:Signal(...);
	end
	
end

function event:BindFire() -- To allow for the fire function to be passed as a callback
	return function(...) self:Fire(...) end;
end

return event;
