local service = 1735
local secret = "efe0275d-13db-49d0-a8e0-e6b3312aa674"
local useNonce = true

-- Modern notification function
local function notify(message, color)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "System",
        Text = message,
        Icon = "",
        Duration = 3,
        Button1 = "OK",
        Button2 = ""
    })
end

repeat task.wait(1) until game:IsLoaded() or game.Players.LocalPlayer

--API

local onMessage = function(message)
    game:GetService("StarterGui"):SetCore("ChatMakeSystemMessage", { Text = message; })
end;

repeat task.wait(1) until game:IsLoaded() or game.Players.LocalPlayer;

local requestSending = false;
local fSetClipboard, fRequest, fStringChar, fToString, fStringSub, fOsTime, fMathRandom, fMathFloor, fGetHwid = 
    setclipboard or toclipboard, request or http_request, string.char, tostring, string.sub, os.time, math.random, math.floor, 
    gethwid or function() return game:GetService("Players").LocalPlayer.UserId end;

local cachedLink, cachedTime = "", 0;
local HttpService = game:GetService("HttpService");

function lEncode(data) return HttpService:JSONEncode(data) end;
function lDecode(data) return HttpService:JSONDecode(data) end;

local function lDigest(input)
    local inputStr = tostring(input);
    local hash = {};
    for i = 1, #inputStr do
        table.insert(hash, string.byte(inputStr, i));
    end;
    local hashHex = "";
    for _, byte in ipairs(hash) do
        hashHex = hashHex .. string.format("%02x", byte);
    end;
    return hashHex;
end;

local host = "https://api.platoboost.com";
local hostResponse = fRequest({ Url = host .. "/public/connectivity", Method = "GET" });
if hostResponse.StatusCode ~= 200 or hostResponse.StatusCode ~= 429 then
    host = "https://api.platoboost.net";
end;

function cacheLink()
    if cachedTime + (10 * 60) < fOsTime() then
        local response = fRequest({
            Url = host .. "/public/start",
            Method = "POST",
            Body = lEncode({ service = service, identifier = lDigest(fGetHwid()) }),
            Headers = { ["Content-Type"] = "application/json" }
        });

        if response.StatusCode == 200 then
            local decoded = lDecode(response.Body);
            if decoded.success == true then
                cachedLink = decoded.data.url;
                cachedTime = fOsTime();
                return true, cachedLink;
            else
                onMessage(decoded.message);
                return false, decoded.message;
            end;
        elseif response.StatusCode == 429 then
            local msg = "You are being rate limited, please wait 20 seconds and try again.";
            onMessage(msg);
            return false, msg;
        end;
        local msg = "Failed to cache link.";
        onMessage(msg);
        return false, msg;
    else
        return true, cachedLink;
    end;
end;

cacheLink();

local generateNonce = function()
    local str = "";
    for _ = 1, 16 do
        str = str .. fStringChar(fMathFloor(fMathRandom() * (122 - 97 + 1)) + 97);
    end;
    return str;
end;

for _ = 1, 5 do
    local oNonce = generateNonce();
    task.wait(0.2);
    if generateNonce() == oNonce then
        local msg = "Platoboost nonce error.";
        onMessage(msg);
        error(msg);
    end;
end;

local copyLink = function()
    local success, link = cacheLink();
    if success then
        fSetClipboard(link);
        onMessage("Link copied to clipboard!");
    end;
end;

local redeemKey = function(key)
    local nonce = generateNonce();
    local endpoint = host .. "/public/redeem/" .. fToString(service);
    local body = {
        identifier = lDigest(fGetHwid()),
        key = key
    };
    if useNonce then
        body.nonce = nonce;
    end;
    local response = fRequest({
        Url = endpoint,
        Method = "POST",
        Body = lEncode(body),
        Headers = { ["Content-Type"] = "application/json" }
    });
    if response.StatusCode == 200 then
        local decoded = lDecode(response.Body);
        if decoded.success == true then
            if decoded.data.valid == true then
                if useNonce then
                    if decoded.data.hash == lDigest("true" .. "-" .. nonce .. "-" .. secret) then
                        return true;
                    else
                        onMessage("Failed to verify integrity.");
                        return false;
                    end;
                else
                    return true;
                end;
            else
                onMessage("Key is invalid.");
                return false;
            end;
        else
            if fStringSub(decoded.message, 1, 27) == "unique constraint violation" then
                onMessage("You already have an active key, please wait for it to expire before redeeming it.");
                return false;
            else
                onMessage(decoded.message);
                return false;
            end;
        end;
    elseif response.StatusCode == 429 then
        onMessage("You are being rate limited, please wait 20 seconds and try again.");
        return false;
    else
        onMessage("Server returned an invalid status code, please try again later.");
        return false;
    end;
end;

local verifyKey = function(key)
    if requestSending == true then
        onMessage("A request is already being sent, please slow down.");
        return false;
    else
        requestSending = true;
    end;
    local nonce = generateNonce();
    local endpoint = host .. "/public/whitelist/" .. fToString(service) .. "?identifier=" .. lDigest(fGetHwid()) .. "&key=" .. key;
    if useNonce then
        endpoint = endpoint .. "&nonce=" .. nonce;
    end;
    local response = fRequest({
        Url = endpoint,
        Method = "GET",
    });
    requestSending = false;
    if response.StatusCode == 200 then
        local decoded = lDecode(response.Body);
        if decoded.success == true then
            if decoded.data.valid == true then
                return true;
            else
                if fStringSub(key, 1, 4) == "FREE_" then
                    return redeemKey(key);
                else
                    onMessage("Key is invalid.");
                    return false;
                end;
            end;
        else
            onMessage(decoded.message);
            return false;
        end;
    elseif response.StatusCode == 429 then
        onMessage("You are being rate limited, please wait 20 seconds and try again.");
        return false;
    else
        onMessage("Server returned an invalid status code, please try again later.");
        return false;
    end;
end;

-- Modern GUI Design
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local TopBar = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local ExitButton = Instance.new("TextButton")
local MinimizeButton = Instance.new("TextButton")
local ContentFrame = Instance.new("Frame")
local KeyBox = Instance.new("TextBox")
local GetKeyButton = Instance.new("TextButton")
local CheckKeyButton = Instance.new("TextButton")
local StatusLabel = Instance.new("TextLabel")

ScreenGui.Name = "KeyAuth"
ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
MainFrame.BackgroundTransparency = 0.1
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.35, 0, 0.35, 0)
MainFrame.Size = UDim2.new(0, 350, 0, 250)
MainFrame.Active = true
MainFrame.Draggable = true

-- Add gradient effect
local Gradient = Instance.new("UIGradient")
Gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 45, 60)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 40))
})
Gradient.Rotation = 90
Gradient.Parent = MainFrame

-- Add drop shadow
local Shadow = Instance.new("ImageLabel")
Shadow.Name = "Shadow"
Shadow.Parent = MainFrame
Shadow.BackgroundTransparency = 1
Shadow.BorderSizePixel = 0
Shadow.Position = UDim2.new(0, -15, 0, -15)
Shadow.Size = UDim2.new(1, 30, 1, 30)
Shadow.Image = "rbxassetid://1316045217"
Shadow.ImageColor3 = Color3.new(0, 0, 0)
Shadow.ImageTransparency = 0.8
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(10, 10, 118, 118)
Shadow.ZIndex = -1

TopBar.Name = "TopBar"
TopBar.Parent = MainFrame
TopBar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
TopBar.BorderSizePixel = 0
TopBar.Size = UDim2.new(1, 0, 0, 30)

Title.Name = "Title"
Title.Parent = TopBar
Title.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Title.BackgroundTransparency = 1.000
Title.Position = UDim2.new(0.02, 0, 0, 0)
Title.Size = UDim2.new(0.5, 0, 1, 0)
Title.Font = Enum.Font.GothamSemibold
Title.Text = "PREMIUdM ACCESS"
Title.TextColor3 = Color3.fromRGB(200, 200, 200)
Title.TextSize = 14.000
Title.TextXAlignment = Enum.TextXAlignment.Left

ExitButton.Name = "ExitButton"
ExitButton.Parent = TopBar
ExitButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
ExitButton.BorderSizePixel = 0
ExitButton.Position = UDim2.new(0.9, 0, 0.1, 0)
ExitButton.Size = UDim2.new(0, 20, 0, 20)
ExitButton.Font = Enum.Font.GothamBold
ExitButton.Text = "×"
ExitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ExitButton.TextSize = 18.000
ExitButton.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Add button hover effects
local function addHoverEffect(button)
    local originalColor = button.BackgroundColor3
    local originalSize = button.Size
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = originalColor:Lerp(Color3.new(1,1,1), 0.2)
        button.Size = originalSize + UDim2.new(0,2,0,2)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = originalColor
        button.Size = originalSize
    end)
end

addHoverEffect(ExitButton)

ContentFrame.Name = "ContentFrame"
ContentFrame.Parent = MainFrame
ContentFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ContentFrame.BackgroundTransparency = 1.000
ContentFrame.Position = UDim2.new(0, 0, 0.12, 0)
ContentFrame.Size = UDim2.new(1, 0, 0.88, 0)

KeyBox.Name = "KeyBox"
KeyBox.Parent = ContentFrame
KeyBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
KeyBox.BorderSizePixel = 0
KeyBox.Position = UDim2.new(0.05, 0, 0.1, 0)
KeyBox.Size = UDim2.new(0.9, 0, 0.3, 0)
KeyBox.Font = Enum.Font.Gotham
KeyBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
KeyBox.PlaceholderText = "Enter your access key..."
KeyBox.Text = ""
KeyBox.TextColor3 = Color3.fromRGB(200, 200, 200)
KeyBox.TextSize = 14.000

-- Add rounded corners to input box
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 5)
UICorner.Parent = KeyBox

GetKeyButton.Name = "GetKeyButton"
GetKeyButton.Parent = ContentFrame
GetKeyButton.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
GetKeyButton.BorderSizePixel = 0
GetKeyButton.Position = UDim2.new(0.05, 0, 0.5, 0)
GetKeyButton.Size = UDim2.new(0.425, 0, 0.3, 0)
GetKeyButton.Font = Enum.Font.GothamSemibold
GetKeyButton.Text = "GET KEY"
GetKeyButton.TextColor3 = Color3.fromRGB(200, 200, 200)
GetKeyButton.TextSize = 14.000
GetKeyButton.MouseButton1Click:Connect(function()
    copyLink()
    notify("Key link copied to clipboard!", Color3.fromRGB(0, 200, 0))
end)

CheckKeyButton.Name = "CheckKeyButton"
CheckKeyButton.Parent = ContentFrame
CheckKeyButton.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
CheckKeyButton.BorderSizePixel = 0
CheckKeyButton.Position = UDim2.new(0.525, 0, 0.5, 0)
CheckKeyButton.Size = UDim2.new(0.425, 0, 0.3, 0)
CheckKeyButton.Font = Enum.Font.GothamSemibold
CheckKeyButton.Text = "CHECK KEY"
CheckKeyButton.TextColor3 = Color3.fromRGB(200, 200, 200)
CheckKeyButton.TextSize = 14.000
CheckKeyButton.MouseButton1Click:Connect(function()
    if KeyBox.Text == "" then
        notify("Please enter a key first!", Color3.fromRGB(200, 50, 50))
        return
    end
    
    local valid = verifyKey(KeyBox.Text)
    if valid then
        notify("Access granted! Loading...", Color3.fromRGB(0, 200, 0))
        ScreenGui:Destroy()
        loadstring(game:HttpGet("https://pastebin.com/raw/34dZHb49"))()
    else
        notify("Invalid key! Please try again.", Color3.fromRGB(200, 50, 50))
        KeyBox.Text = ""
    end
end)

-- Add hover effects to buttons
addHoverEffect(GetKeyButton)
addHoverEffect(CheckKeyButton)

-- Add subtle animations
local hoverAnim = Instance.new("Animation")
hoverAnim.AnimationId = "rbxassetid://3541044388"
local hoverTrack = game:GetService("Players").LocalPlayer:WaitForChild("Humanoid"):LoadAnimation(hoverAnim)

for _, button in pairs({GetKeyButton, CheckKeyButton}) do
    button.MouseEnter:Connect(function()
        hoverTrack:Play()
    end)
end

-- Add status label
StatusLabel.Name = "StatusLabel"
StatusLabel.Parent = ContentFrame
StatusLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
StatusLabel.BackgroundTransparency = 1.000
StatusLabel.Position = UDim2.new(0.05, 0, 0.85, 0)
StatusLabel.Size = UDim2.new(0.9, 0, 0.1, 0)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "Status: Ready"
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.TextSize = 12.000
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Add decorative elements
local DecorativeLine = Instance.new("Frame")
DecorativeLine.Parent = TopBar
DecorativeLine.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
DecorativeLine.BorderSizePixel = 0
DecorativeLine.Position = UDim2.new(0, 0, 1, 0)
DecorativeLine.Size = UDim2.new(1, 0, 0, 2)

-- Add key icon
local KeyIcon = Instance.new("ImageLabel")
KeyIcon.Name = "KeyIcon"
KeyIcon.Parent = ContentFrame
KeyIcon.BackgroundTransparency = 1
KeyIcon.Position = UDim2.new(0.4, 0, -0.15, 0)
KeyIcon.Size = UDim2.new(0, 50, 0, 50)
KeyIcon.Image = "rbxassetid://3926305904"  -- Replace with your key icon ID
KeyIcon.ImageColor3 = Color3.fromRGB(0, 150, 100)
