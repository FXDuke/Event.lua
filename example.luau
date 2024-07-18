
-- This script creates an event that fires when time_scale is changed, and then in another script a connection is made that fades in the change in time_scale.

-- @Script "timeManagement"

local event = require(event);

local timeChangeEvents = {
  time_scale = event.new("TimeScaleUpdated");
};

local time;
time = {
  time_scale = 1,
};

local proxy = setmetatable({}, {
    __index = time,
    __newindex = function(self, key, value)
      rawset(self, key, value);

      assert(time[key], key .. " is not a valid attribute of time");
      
      time[key] = value;

      if (timeChangeEvents[key]) then
        timeChangeEvents[key]:Fire(value);
      end
      
    end,
});

-- @Script "npc"

local preSimulation = game:GetService("RunService").PreSimulation;
local tweenService = game:GetService("TweenService");
local event = require(event);
local time_scaleChangedEvent = event.getEvent("TimeScaleUpdated");

local humanoid = script.Parent:WaitForChild("Humanoid");

local currentTimeScale = 1;
local walkSpeed = 16;

local timeScaleFadeQueue = 0;
local timeScaleFadeQueueCurrent = 0;
local timeScaleFading = false;

local function time_scaleChangedCallback(value, fadeTime)

  if (timeScaleFading) then 
    timeScaleFadeQueue += 1;
    local queuePosition = timeScaleFadeQueue;
    repeat task.wait() until timeScaleFadeQueueCurrent == queuePosition;
  end

  timeScaleFading = true;
  
  local elapsed = 0;
  local origin = currentTimeScale;
  local change = value-currentTimeScale;

  while (elapsed < fadeTime) do 

    elapsed = math.min(elapsed + preSimulation:Wait(), fadeTime);

    local alpha = tweenService:GetValue(elapsed/fadeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.In);

    currentTimeScale = origin + change*alpha;
    humanoid.WalkSpeed = walkSpeed*currentTimeScale;
    
  end
  
  currentTimeScale = value;
  humanoid.WalkSpeed = walkSpeed*value;
  timeScaleFading = false;
  
end

time_scaleChangedEvent:ConnectParallel(time_scaleChangedCallback, 1);
