display.setStatusBar(display.HiddenStatusBar)

local json = require('json')
local widget = require('widget')
local bluetooth = require('plugin.bluetooth')

local platform = system.getInfo('platformName')
local apiLevel = system.getInfo('androidApiLevel')
-- 14 -> Android 4.0
-- 21 -> Android 5.0

if platform == 'Android' and apiLevel < 18 then
    print('Bluetooth LE is not supported on this device')
end

local deviceToSearch = 'Cycling Power' -- change that to the name of the device you want to connect to

bluetooth.init(function(event)
    print('Init event:', json.prettify(event))
end)

display.setDefault('background', 1)

local x, y = display.contentCenterX, display.contentCenterY
local w, h = display.contentWidth * 0.8, 50

local function str2hex(str)
    local hex = ''
    while #str > 0 do
        local hb = string.format('%x', string.byte(str, 1, 1))
        if #hb < 2 then hb = '0' .. hb end
        hex = hex .. hb
        str = string.sub(str, 2)
    end
    return hex
end

local device

widget.newButton{
    x = x, y = y - 120,
    width = w, height = h,
    label = 'Start Scan',
    onRelease = function()
        bluetooth.startScan(function (event)
            if event.device.name == deviceToSearch then
                device = event.device
            end
            print('Scan event:', json.prettify(event))
        end, 5000)
    end}

widget.newButton{
    x = x, y = y - 40,
    width = w, height = h,
    label = 'Stop Scan',
    onRelease = function()
        bluetooth.stopScan()
    end}

widget.newButton{
    x = x, y = y + 40,
    width = w, height = h,
    label = 'Is active?',
    onRelease = function()
        native.showAlert('Is active?', bluetooth.isActive and 'Yes' or 'No', {'OK'})
    end}

widget.newButton{
    x = x, y = y + 120,
    width = w, height = h,
    label = 'Is scanning?',
    onRelease = function()
        native.showAlert('Is scanning?', bluetooth.isScanning and 'Yes' or 'No', {'OK'})
    end}

widget.newButton{
    x = x, y = y + 200,
    width = w, height = h,
    label = 'Connect',
    onRelease = function()
        local function listener(event)
            print(json.prettify(event))
            if event.name == 'onConnectionStateChange' then
                event.gatt:discoverServices()
            end
            if event.name == 'onServicesDiscovered' and not event.isError then
                local services = event.gatt:getServices()
                for i = 1, #services do
                    print('Service:', json.prettify(services[i]))
                    local characteristics = services[i]:getCharacteristics()
                    for j = 1, #characteristics do
                        print('Characteristic:', json.prettify(characteristics[j]))
                        timer.performWithDelay(j * 3000, function()
                            event.gatt:readCharacteristic(characteristics[j])
                        end)
                    end
                end
            end
            if event.name == 'onCharacteristicRead' and not event.isError then
                print('Characteristic ' .. event.characteristic.uuid .. ' value:', event.characteristic:getValue(), str2hex(event.characteristic:getValue()))
            end
        end
        bluetooth.connect({
            device = device,
            autoconnect = true,
            onCharacteristicChanged = listener,
            onCharacteristicRead = listener,
            onCharacteristicWrite = listener,
            onConnectionStateChange = listener,
            onDescriptorRead = listener,
            onDescriptorWrite = listener,
            onReadRemoteRssi = listener,
            onReliableWriteCompleted = listener,
            onServicesDiscovered = listener
        })
    end}
