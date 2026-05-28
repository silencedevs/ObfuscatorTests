
local results = {}

local function log(name, ok, ...)
    local values = { ... }
    local parts = {}
    for i = 1, #values do
        parts[i] = tostring(values[i])
    end
    results[#results + 1] = (ok and "OK " or "FAIL ") .. name .. (#parts > 0 and (" :: " .. table.concat(parts, " | ")) or "")
end

local function try(name, fn)
    local ok, a, b, c, d = pcall(fn)
    log(name, ok, a, b, c, d)
    return ok, a, b, c, d
end

local function exists(name)
    local v = rawget(_G, name)
    if v == nil then
        local ok, env = pcall(function()
            if type(getgenv) == "function" then
                return getgenv()
            end
            return nil
        end)
        if ok and type(env) == "table" then
            v = rawget(env, name)
        end
    end
    return v
end

local function mark(name)
    local v = exists(name)
    log("exists." .. name, v ~= nil, type(v))
    return v
end

local function assertEq(name, a, b)
    if a ~= b then
        error(name .. " expected " .. tostring(b) .. " got " .. tostring(a))
    end
    return a
end

try("base.print", function()
    print("[SilenceTest] print passthrough")
    return "printed"
end)

try("base.vararg_nil_multireturn", function()
    local function nativeLike(a, b, c, ...)
        return a, b, c, select("#", ...)
    end
    local a, b, c, n = nativeLike(nil, "middle", nil, "x", nil, "z")
    return tostring(a), b, tostring(c), n
end)

try("base.tables", function()
    local t = {
        "one",
        named = "value",
        "two",
        nested = {
            ok = true,
        },
    }
    t[5] = "five"
    return #t, t[1], t[2], t.named, t.nested.ok, t[5]
end)

try("base.method_call", function()
    local obj = { value = 4 }
    function obj:add(x, y)
        self.value = self.value + x + y
        return self.value
    end
    return obj:add(2, 3)
end)

try("base.closure_upvalue", function()
    local total = 10
    local function make(x)
        return function(y)
            total = total + 1
            return x + y + total
        end
    end
    local f = make(3)
    return f(7), f(8), total
end)

try("roblox.game_services", function()
    if type(game) ~= "userdata" and type(game) ~= "table" then
        return "missing-game"
    end
    local players = game:GetService("Players")
    local runService = game:GetService("RunService")
    local httpService = game:GetService("HttpService")
    return typeof(players), typeof(runService), typeof(httpService)
end)

try("roblox.instances", function()
    if type(Instance) ~= "table" or type(Instance.new) ~= "function" then
        return "missing-Instance"
    end
    local folder = Instance.new("Folder")
    folder.Name = "SilenceCompatFolder"
    local part = Instance.new("Part")
    part.Name = "SilenceCompatPart"
    part.Parent = folder
    return folder.Name, part.Parent == folder, part.Name
end)

try("roblox.datatypes", function()
    local c = Color3.fromRGB(12, 34, 56)
    local v2 = Vector2.new(10, 20)
    local v3 = Vector3.new(1, 2, 3)
    local cf = CFrame.new(1, 2, 3)
    local ud = UDim2.fromOffset(100, 50)
    return typeof(c), typeof(v2), typeof(v3), typeof(cf), typeof(ud)
end)

try("roblox.enum", function()
    return tostring(Enum.KeyCode.E), tostring(Enum.UserInputType.MouseButton1)
end)

try("roblox.httpget", function()
    if type(game) ~= "userdata" and type(game) ~= "table" then
        return "missing-game"
    end
    if type(game.HttpGet) ~= "function" and type(game.HttpGetAsync) ~= "function" then
        return "missing-HttpGet"
    end
    local body
    if type(game.HttpGet) == "function" then
        body = game:HttpGet("https://httpbin.org/get", true)
    else
        body = game:HttpGetAsync("https://httpbin.org/get")
    end
    return type(body), #tostring(body)
end)

try("executor.environments", function()
    local genv = type(getgenv) == "function" and getgenv() or nil
    local renv = type(getrenv) == "function" and getrenv() or nil
    local fenv = type(getfenv) == "function" and getfenv() or nil
    if type(genv) == "table" then
        genv.SilenceCompat = "genv-ok"
    end
    return type(genv), type(renv), type(fenv), genv and genv.SilenceCompat
end)

try("executor.identity", function()
    local a, b
    if type(identifyexecutor) == "function" then
        a, b = identifyexecutor()
    elseif type(getexecutorname) == "function" then
        a = getexecutorname()
    else
        a = "missing"
    end
    return a, b
end)

try("executor.loadstring", function()
    local loader = type(loadstring) == "function" and loadstring or load
    if type(loader) ~= "function" then
        return "missing-loadstring"
    end
    local fn = assert(loader("return function(a,b) return a+b, 'loaded' end"))()
    local sum, tag = fn(20, 22)
    return sum, tag
end)

try("executor.request", function()
    local req = exists("request") or exists("http_request")
    if type(req) ~= "function" then
        return "missing-request"
    end
    local response = req({
        Url = "https://httpbin.org/get",
        Method = "GET",
        Headers = {
            ["User-Agent"] = "SilenceCompat",
        },
    })
    return type(response), response.StatusCode or response.status_code or response.Status, type(response.Body or response.body)
end)

try("executor.syn_request", function()
    if type(syn) ~= "table" or type(syn.request) ~= "function" then
        return "missing-syn.request"
    end
    local response = syn.request({
        Url = "https://httpbin.org/post",
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
        },
        Body = '{"silence":true}',
    })
    return type(response), response.StatusCode or response.status_code or response.Status, type(response.Body or response.body)
end)

try("executor.http_aliases", function()
    local names = {
        "request",
        "http_request",
        "http.request",
        "fluxus.request",
        "krnl_request",
    }
    local found = {}
    for i = 1, #names do
        local name = names[i]
        local value
        if name == "http.request" then
            value = type(http) == "table" and http.request or nil
        elseif name == "fluxus.request" then
            value = type(fluxus) == "table" and fluxus.request or nil
        else
            value = exists(name)
        end
        found[#found + 1] = name .. "=" .. type(value)
    end
    return table.concat(found, ",")
end)

try("executor.filesystem", function()
    if type(writefile) ~= "function" or type(readfile) ~= "function" then
        return "missing-filesystem"
    end
    writefile("silence_compat.txt", "A")
    if type(appendfile) == "function" then
        appendfile("silence_compat.txt", "B")
    end
    local data = readfile("silence_compat.txt")
    local isFile = type(isfile) == "function" and isfile("silence_compat.txt") or "missing-isfile"
    local listed = "missing-listfiles"
    if type(listfiles) == "function" then
        local files = listfiles(".")
        listed = type(files) .. ":" .. tostring(#files)
    end
    return data, tostring(isFile), listed
end)

try("executor.folders", function()
    if type(makefolder) ~= "function" then
        return "missing-makefolder"
    end
    makefolder("silence_folder")
    local isFolder = type(isfolder) == "function" and isfolder("silence_folder") or "missing-isfolder"
    if type(delfolder) == "function" then
        delfolder("silence_folder")
    end
    return tostring(isFolder)
end)

try("executor.clipboard", function()
    local setter = exists("setclipboard") or exists("toclipboard") or exists("set_clipboard")
    if type(setter) ~= "function" then
        return "missing-clipboard"
    end
    setter("SilenceClipboard")
    return "set"
end)

try("executor.custom_asset", function()
    if type(getcustomasset) ~= "function" then
        return "missing-getcustomasset"
    end
    return getcustomasset("silence_compat.txt")
end)

try("executor.teleport_queue", function()
    local queue = exists("queue_on_teleport") or exists("queueonteleport")
    if type(queue) ~= "function" then
        return "missing-queue"
    end
    queue("print('queued by SilenceCompat')")
    if type(clearqueueonteleport) == "function" then
        clearqueueonteleport()
    end
    return "queued"
end)

try("executor.fflags", function()
    if type(getfflag) ~= "function" then
        return "missing-fflag"
    end
    local before = getfflag("DebugDisableTelemetryEphemeralCounter")
    if type(setfflag) == "function" then
        setfflag("SilenceCompatFlag", "True")
    end
    return tostring(before)
end)

try("executor.drawing", function()
    if type(Drawing) ~= "table" or type(Drawing.new) ~= "function" then
        return "missing-Drawing"
    end
    local text = Drawing.new("Text")
    text.Text = "Silence"
    text.Visible = false
    local square = Drawing.new("Square")
    square.Visible = false
    return text.Text, tostring(text.Visible), typeof(square)
end)

try("executor.hooks", function()
    local old = function(x)
        return "old:" .. tostring(x)
    end
    local new = function(x)
        return "new:" .. tostring(x)
    end
    local returned = "missing-hookfunction"
    if type(hookfunction) == "function" then
        local original = hookfunction(old, new)
        returned = type(original)
    end
    local nc = type(newcclosure) == "function" and newcclosure(function()
        return "newcclosure"
    end) or nil
    return returned, type(nc), nc and nc()
end)

try("executor.metatable", function()
    local t = {}
    local mt = {
        __index = function(_, key)
            return "idx:" .. tostring(key)
        end,
    }
    setmetatable(t, mt)
    local rawMt = type(getrawmetatable) == "function" and getrawmetatable(t) or getmetatable(t)
    if type(setreadonly) == "function" then
        pcall(setreadonly, rawMt, false)
    end
    if type(setrawmetatable) == "function" then
        setrawmetatable(t, rawMt)
    end
    return t.hello, type(rawMt)
end)

try("executor.closure_checks", function()
    local fn = function()
        return "x"
    end
    local a = type(islclosure) == "function" and tostring(islclosure(fn)) or "missing"
    local b = type(iscclosure) == "function" and tostring(iscclosure(print)) or "missing"
    local c = type(isexecutorclosure) == "function" and tostring(isexecutorclosure(fn)) or "missing"
    local d = type(isourclosure) == "function" and tostring(isourclosure(fn)) or "missing"
    return a, b, c, d
end)

try("executor.reflection", function()
    local values = {}
    local names = {
        "getgc",
        "getreg",
        "getrenv",
        "getsenv",
        "getloadedmodules",
        "getrunningscripts",
        "getnilinstances",
        "getinstances",
        "getscripts",
        "getscriptbytecode",
        "getscriptclosure",
    }
    for i = 1, #names do
        local name = names[i]
        local f = exists(name)
        values[#values + 1] = name .. "=" .. type(f)
    end
    return table.concat(values, ",")
end)

try("executor.connections", function()
    if type(getconnections) ~= "function" then
        return "missing-getconnections"
    end
    local signal
    if type(Instance) == "table" and type(Instance.new) == "function" then
        local bindable = Instance.new("BindableEvent")
        signal = bindable.Event
        bindable.Event:Connect(function() end)
    else
        signal = {
            Connect = function() end,
        }
    end
    local connections = getconnections(signal)
    return type(connections), #connections
end)

try("executor.firesignal", function()
    if type(firesignal) ~= "function" then
        return "missing-firesignal"
    end
    if type(Instance) ~= "table" or type(Instance.new) ~= "function" then
        return "missing-Instance"
    end
    local bindable = Instance.new("BindableEvent")
    local got = nil
    bindable.Event:Connect(function(value)
        got = value
    end)
    firesignal(bindable.Event, "signal-ok")
    return tostring(got)
end)

try("executor.fireclickdetector", function()
    if type(fireclickdetector) ~= "function" then
        return "missing-fireclickdetector"
    end
    if type(Instance) ~= "table" or type(Instance.new) ~= "function" then
        return "missing-Instance"
    end
    local part = Instance.new("Part")
    local detector = Instance.new("ClickDetector")
    detector.Parent = part
    fireclickdetector(detector)
    return "fired"
end)

try("executor.fireproximityprompt", function()
    if type(fireproximityprompt) ~= "function" then
        return "missing-fireproximityprompt"
    end
    if type(Instance) ~= "table" or type(Instance.new) ~= "function" then
        return "missing-Instance"
    end
    local prompt = Instance.new("ProximityPrompt")
    fireproximityprompt(prompt, 1, true)
    return "fired"
end)

try("executor.firetouchinterest", function()
    if type(firetouchinterest) ~= "function" then
        return "missing-firetouchinterest"
    end
    if type(Instance) ~= "table" or type(Instance.new) ~= "function" then
        return "missing-Instance"
    end
    local a = Instance.new("Part")
    local b = Instance.new("Part")
    firetouchinterest(a, b, 0)
    firetouchinterest(a, b, 1)
    return "fired"
end)

try("executor.saveinstance_decompile", function()
    local save = type(saveinstance) == "function" and "saveinstance=function" or "saveinstance=" .. type(saveinstance)
    local dec = type(decompile) == "function" and "decompile=function" or "decompile=" .. type(decompile)
    local dump = type(dumpstring) == "function" and "dumpstring=function" or "dumpstring=" .. type(dumpstring)
    return save, dec, dump
end)

try("executor.namecall_helpers", function()
    local getNamecall = type(getnamecallmethod) == "function" and getnamecallmethod or nil
    local setNamecall = type(setnamecallmethod) == "function" and setnamecallmethod or nil
    if not getNamecall and not setNamecall then
        return "missing-namecall-helpers"
    end
    local before = getNamecall and getNamecall() or "missing-get"
    local after = setNamecall and setNamecall("SilenceNamecall") or "missing-set"
    return tostring(before), tostring(after)
end)

try("executor.cache", function()
    local cacheTable = exists("cache")
    if type(cacheTable) ~= "table" then
        return "missing-cache"
    end
    local fns = {}
    for _, name in ipairs({ "invalidate", "iscached", "replace", "cloneref" }) do
        fns[#fns + 1] = name .. "=" .. type(cacheTable[name])
    end
    return table.concat(fns, ",")
end)

try("executor.instance_refs", function()
    local clone = exists("cloneref")
    local compare = exists("compareinstances")
    if type(clone) ~= "function" and type(compare) ~= "function" then
        return "missing-instance-ref-functions"
    end
    local obj = type(game) ~= "nil" and game or {}
    local cloned = type(clone) == "function" and clone(obj) or obj
    local same = type(compare) == "function" and compare(obj, cloned) or (obj == cloned)
    return tostring(same), type(cloned)
end)

try("executor_input_virtual_user", function()
    local vim = nil
    if type(game) ~= "nil" and type(game.GetService) == "function" then
        pcall(function()
            vim = game:GetService("VirtualInputManager")
        end)
    end
    return typeof(vim)
end)

try("summary", function()
    return #results
end)

print("=== Silence Executor Compatibility Results ===")
for i = 1, #results do
    print(i, results[i])
end
print("=== Silence Executor Compatibility Done ===")
