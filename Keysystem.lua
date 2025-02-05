local service = 1735 -- Set your Platoboost Id
local secret = "efe0275d-13db-49d0-a8e0-e6b3312aa674" -- Set Your Platoboost Api key
local useNonce = true

-- Notification function
local function notify(message, color)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "System",
        Text = message,
        Duration = 5,
    })
end

-- Wait for the game to load
repeat task.wait(1) until game:IsLoaded() or game.Players.LocalPlayer

-- Helper functions
local fSetClipboard = setclipboard or toclipboard
local fRequest = request or http_request or (syn and syn.request)
local fStringChar = string.char
local fToString = tostring
local fStringSub = string.sub
local fOsTime = os.time
local fMathRandom = math.random
local fMathFloor = math.floor
local fGetHwid = gethwid or function() return game:GetService("Players").LocalPlayer.UserId end

local cachedLink, cachedTime = "", 0
local HttpService = game:GetService("HttpService")

-- JSON encode/decode
function lEncode(data) return HttpService:JSONEncode(data) end
function lDecode(data) return HttpService:JSONDecode(data) end

-- Hash function
local function lDigest(input)
    local inputStr = tostring(input)
    local hash = {}
    for i = 1, #inputStr do
        table.insert(hash, string.byte(inputStr, i))
    end
    local hashHex = ""
    for _, byte in ipairs(hash) do
        hashHex = hashHex .. string.format("%02x", byte)
    end
    return hashHex
end

-- API host
local host = "https://api.platoboost.com"
local hostResponse = fRequest({ Url = host .. "/public/connectivity", Method = "GET" })
if hostResponse.StatusCode ~= 200 or hostResponse.StatusCode ~= 429 then
    host = "https://api.platoboost.net"
end

-- Cache link function
function cacheLink()
    if cachedTime + (10 * 60) < fOsTime() then
        local response = fRequest({
            Url = host .. "/public/start",
            Method = "POST",
            Body = lEncode({ service = service, identifier = lDigest(fGetHwid()) }),
            Headers = { ["Content-Type"] = "application/json" }
        })

        if response.StatusCode == 200 then
            local decoded = lDecode(response.Body)
            if decoded.success == true then
                cachedLink = decoded.data.url
                cachedTime = fOsTime()
                return true, cachedLink
            else
                notify(decoded.message, Color3.fromRGB(255, 0, 0))
                return false, decoded.message
            end
        elseif response.StatusCode == 429 then
            notify("You are being rate limited, please wait 20 seconds and try again.", Color3.fromRGB(255, 0, 0))
            return false, "Rate limited"
        else
            notify("Failed to cache link.", Color3.fromRGB(255, 0, 0))
            return false, "Failed to cache link"
        end
    else
        return true, cachedLink
    end
end

cacheLink()

-- Nonce generator
local function generateNonce()
    local str = ""
    for _ = 1, 16 do
        str = str .. fStringChar(fMathFloor(fMathRandom() * (122 - 97 + 1)) + 97)
    end
    return str
end

-- Validate nonce
for _ = 1, 5 do
    local oNonce = generateNonce()
    task.wait(0.2)
    if generateNonce() == oNonce then
        notify("Platoboost nonce error.", Color3.fromRGB(255, 0, 0))
        error("Platoboost nonce error")
    end
end

-- Copy link to clipboard
local function copyLink()
    local success, link = cacheLink()
    if success then
        fSetClipboard(link)
        notify("Link copied to clipboard!", Color3.fromRGB(0, 255, 0))
    else
        notify("Failed to copy link.", Color3.fromRGB(255, 0, 0))
    end
end

-- Redeem key function
local function redeemKey(key)
    local nonce = generateNonce()
    local endpoint = host .. "/public/redeem/" .. fToString(service)
    local body = {
        identifier = lDigest(fGetHwid()),
        key = key
    }
    if useNonce then
        body.nonce = nonce
    end

    local response = fRequest({
        Url = endpoint,
        Method = "POST",
        Body = lEncode(body),
        Headers = { ["Content-Type"] = "application/json" }
    })

    if response.StatusCode == 200 then
        local decoded = lDecode(response.Body)
        if decoded.success == true then
            if decoded.data.valid == true then
                if useNonce then
                    if decoded.data.hash == lDigest("true" .. "-" .. nonce .. "-" .. secret) then
                        return true
                    else
                        notify("Failed to verify integrity.", Color3.fromRGB(255, 0, 0))
                        return false
                    end
                else
                    return true
                end
            else
                notify("Key is invalid.", Color3.fromRGB(255, 0, 0))
                return false
            end
        else
            if fStringSub(decoded.message, 1, 27) == "unique constraint violation" then
                notify("You already have an active key, please wait for it to expire before redeeming it.", Color3.fromRGB(255, 0, 0))
                return false
            else
                notify(decoded.message, Color3.fromRGB(255, 0, 0))
                return false
            end
        end
    elseif response.StatusCode == 429 then
        notify("You are being rate limited, please wait 20 seconds and try again.", Color3.fromRGB(255, 0, 0))
        return false
    else
        notify("Server returned an invalid status code, please try again later.", Color3.fromRGB(255, 0, 0))
        return false
    end
end

-- Verify key function
local function verifyKey(key)
    local nonce = generateNonce()
    local endpoint = host .. "/public/whitelist/" .. fToString(service) .. "?identifier=" .. lDigest(fGetHwid()) .. "&key=" .. key
    if useNonce then
        endpoint = endpoint .. "&nonce=" .. nonce
    end

    local response = fRequest({
        Url = endpoint,
        Method = "GET",
    })

    if response.StatusCode == 200 then
        local decoded = lDecode(response.Body)
        if decoded.success == true then
            if decoded.data.valid == true then
                return true
            else
                if fStringSub(key, 1, 4) == "FREE_" then
                    return redeemKey(key)
                else
                    notify("Key is invalid.", Color3.fromRGB(255, 0, 0))
                    return false
                end
            end
        else
            notify(decoded.message, Color3.fromRGB(255, 0, 0))
            return false
        end
    elseif response.StatusCode == 429 then
        notify("You are being rate limited, please wait 20 seconds and try again.", Color3.fromRGB(255, 0, 0))
        return false
    else
        notify("Server returned an invalid status code, please try again later.", Color3.fromRGB(255, 0, 0))
        return false
    end
end

-- GUI
local ScreenGui = Instance.new("ScreenGui")
local Frame = Instance.new("Frame")
local Topbar = Instance.new("Frame")
local Exit = Instance.new("TextButton")
local Minimize = Instance.new("TextButton")
local Frame_2 = Instance.new("Frame")
local GetKey = Instance.new("TextButton")
local CheckKey = Instance.new("TextButton")
local TextBox = Instance.new("TextBox")
local TextLabel = Instance.new("TextLabel")

ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

Frame.Parent = ScreenGui
Frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Frame.BorderSizePixel = 0
Frame.Position = UDim2.new(0.35, 0, 0.35, 0)
Frame.Size = UDim2.new(0, 300, 0, 200)
Frame.Active = true
Frame.Draggable = true

Topbar.Parent = Frame
Topbar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Topbar.BorderSizePixel = 0
Topbar.Size = UDim2.new(1, 0, 0, 30)

Exit.Parent = Topbar
Exit.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
Exit.BorderSizePixel = 0
Exit.Position = UDim2.new(0.9, 0, 0.1, 0)
Exit.Size = UDim2.new(0, 20, 0, 20)
Exit.Font = Enum.Font.SourceSans
Exit.Text = "X"
Exit.TextColor3 = Color3.fromRGB(255, 255, 255)
Exit.TextSize = 14
Exit.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

Minimize.Parent = Topbar
Minimize.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
Minimize.BorderSizePixel = 0
Minimize.Position = UDim2.new(0.8, 0, 0.1, 0)
Minimize.Size = UDim2.new(0, 20, 0, 20)
Minimize.Font = Enum.Font.SourceSans
Minimize.Text = "-"
Minimize.TextColor3 = Color3.fromRGB(255, 255, 255)
Minimize.TextSize = 14
Minimize.MouseButton1Click:Connect(function()
    Frame.Visible = not Frame.Visible
end)

Frame_2.Parent = Frame
Frame_2.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Frame_2.BorderSizePixel = 0
Frame_2.Position = UDim2.new(0, 0, 0.15, 0)
Frame_2.Size = UDim2.new(1, 0, 0.85, 0)

TextBox.Parent = Frame_2
TextBox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
TextBox.BorderSizePixel = 0
TextBox.Position = UDim2.new(0.05, 0, 0.1, 0)
TextBox.Size = UDim2.new(0.9, 0, 0.3, 0)
TextBox.Font = Enum.Font.SourceSans
TextBox.PlaceholderText = "Enter your key here..."
TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TextBox.TextSize = 14

GetKey.Parent = Frame_2
GetKey.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
GetKey.BorderSizePixel = 0
GetKey.Position = UDim2.new(0.05, 0, 0.5, 0)
GetKey.Size = UDim2.new(0.425, 0, 0.3, 0)
GetKey.Font = Enum.Font.SourceSans
GetKey.Text = "Get Key"
GetKey.TextColor3 = Color3.fromRGB(255, 255, 255)
GetKey.TextSize = 14
GetKey.MouseButton1Click:Connect(copyLink)

CheckKey.Parent = Frame_2
CheckKey.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
CheckKey.BorderSizePixel = 0
CheckKey.Position = UDim2.new(0.525, 0, 0.5, 0)
CheckKey.Size = UDim2.new(0.425, 0, 0.3, 0)
CheckKey.Font = Enum.Font.SourceSans
CheckKey.Text = "Check Key"
CheckKey.TextColor3 = Color3.fromRGB(255, 255, 255)
CheckKey.TextSize = 14
CheckKey.MouseButton1Click:Connect(function()
    if TextBox.Text ~= "" then
        local success = verifyKey(TextBox.Text)
        if success then
            notify("Key is valid! Loading script...", Color3.fromRGB(0, 255, 0))
            ScreenGui:Destroy()
            loadstring(game:HttpGet("https://pastebin.com/raw/34dZHb49"))()
        else
            notify("Key is invalid.", Color3.fromRGB(255, 0, 0))
        end
    else
        notify("Please enter a key.", Color3.fromRGB(255, 0, 0))
    end
end)
