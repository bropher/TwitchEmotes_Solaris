--handles updates and frame rendering for animated emotes
--load after Emotes.lua

local SolarisAnimator = {}
local initialized = false
local animations = {}

if TwitchEmotes_Solaris then
    TwitchEmotes_Solaris.Animator = SolarisAnimator
end

local issecretvalue = issecretvalue or function()
    return false
end

function SolarisAnimator:RegisterPath(imagePath, animData)
    if not imagePath or type(animData) ~= "table"
        or not animData.nFrames
        or not animData.frameWidth
        or not animData.frameHeight
        or not animData.imageWidth
        or not animData.imageHeight
        or not animData.framerate then
        return false
    end

    animations[imagePath] = animData
    TwitchEmotes_animation_metadata =
        TwitchEmotes_animation_metadata or {}
    TwitchEmotes_animation_metadata[imagePath] = animData
    return true
end

function SolarisAnimator:RegisterMetadata()
    if not TwitchEmotes_Solaris_Animation_Metadata then
        return
    end

    for imagePath, animData in pairs(
        TwitchEmotes_Solaris_Animation_Metadata
    ) do
        self:RegisterPath(imagePath, animData)
    end
end

local function BuildSolarisFrameString(
    imagePath,
    animData,
    frameNumber,
    displayHeight,
    displayWidth
)
    local top = frameNumber * animData.frameHeight
    local bottom = top + animData.frameHeight

    --build the texture string here so wide animated emotes keep the correct dimensions
    return "|T" .. imagePath
        .. ":" .. displayHeight
        .. ":" .. displayWidth
        .. ":0:0:"
        .. animData.imageWidth
        .. ":" .. animData.imageHeight
        .. ":0:" .. animData.frameWidth
        .. ":" .. top
        .. ":" .. bottom
        .. "|t"
end

local SOLARIS_PATH_PREFIX =
    "Interface\\AddOns\\TwitchEmotes_Solaris\\Emotes\\"

local function IsSolarisPath(imagePath)
    return type(imagePath) == "string"
        and imagePath:sub(1, #SOLARIS_PATH_PREFIX) == SOLARIS_PATH_PREFIX
end

local stockBuildEmoteFrameString =
    TwitchEmotes_BuildEmoteFrameString

local stockBuildEmoteFrameStringWithDimensions =
    TwitchEmotes_BuildEmoteFrameStringWithDimensions

if stockBuildEmoteFrameString then
    TwitchEmotes_BuildEmoteFrameString = function(
        imagePath,
        animData,
        frameNumber
    )
        if IsSolarisPath(imagePath) then
            return BuildSolarisFrameString(
                imagePath,
                animData,
                0,
                animData.frameHeight,
                animData.frameWidth
            )
        end

        return stockBuildEmoteFrameString(
            imagePath,
            animData,
            frameNumber
        )
    end
end

if stockBuildEmoteFrameStringWithDimensions then
    TwitchEmotes_BuildEmoteFrameStringWithDimensions = function(
        imagePath,
        animData,
        frameNumber,
        displayHeight,
        displayWidth
    )
        if IsSolarisPath(imagePath) then
            return BuildSolarisFrameString(
                imagePath,
                animData,
                0,
                displayHeight,
                displayWidth
            )
        end

        return stockBuildEmoteFrameStringWithDimensions(
            imagePath,
            animData,
            frameNumber,
            displayHeight,
            displayWidth
        )
    end
end

function SolarisAnimator:UpdateFontString(fontString, widthOverride, heightOverride)
    if not fontString or not fontString.GetText then
        return
    end

    local text = fontString:GetText()
    if not text or issecretvalue(text) then
        return
    end

    local changed = false

    local newText = text:gsub(
        "(|TInterface\\AddOns\\TwitchEmotes_Solaris\\.-|t)",
        function(textureString)
            local imagePath =
                textureString:match("|T(Interface\\AddOns\\TwitchEmotes_Solaris\\.-%.tga).-|t")
            local animData = imagePath and animations[imagePath]

            if not animData then
                return textureString
            end

            changed = true
            local frameNumber =
                TwitchEmotes_GetCurrentFrameNum(animData)

            if widthOverride or heightOverride then
                local height =
                    heightOverride or animData.frameHeight
                local width =
                    widthOverride or animData.frameWidth

                if animData.frameWidth and animData.frameHeight then
                    width = height * (
                        animData.frameWidth / animData.frameHeight
                    )
                end

                return BuildSolarisFrameString(
                    imagePath,
                    animData,
                    frameNumber,
                    height,
                    width
                )
            end

            return BuildSolarisFrameString(
                imagePath,
                animData,
                frameNumber,
                animData.frameHeight,
                animData.frameWidth
            )
        end
    )

    if not changed then
        return
    end

    if fontString.messageInfo then
        fontString.messageInfo.message = newText
    end

    fontString:SetText(newText)
end

function SolarisAnimator:Initialize()
    if initialized then
        return
    end

    self:RegisterMetadata()

    if not TwitchEmotes_animation_metadata
        or not TwitchEmotes_GetCurrentFrameNum
        or not TwitchEmotes_BuildEmoteFrameString
        or not TwitchEmotes_BuildEmoteFrameStringWithDimensions
        or not TwitchEmotesAnimator_UpdateEmoteInFontString then
        return
    end

    initialized = true

    hooksecurefunc(
        "TwitchEmotesAnimator_UpdateEmoteInFontString",
        function(fontString, widthOverride, heightOverride)
            SolarisAnimator:UpdateFontString(
                fontString,
                widthOverride,
                heightOverride
            )
        end
    )
end

--register animation metadata with TwitchEmotes
SolarisAnimator:RegisterMetadata()

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "TwitchEmotes"
        or addonName == "TwitchEmotes_Solaris" then
        SolarisAnimator:Initialize()
    end
end)

C_Timer.After(0, function()
    SolarisAnimator:Initialize()
end)

_G.SolarisAnimator = SolarisAnimator
