local QBCore = exports['qb-core']:GetCoreObject()

-- Create enhanced database table
CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `]] .. Config.TableName .. [[` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `citizenid` varchar(50) NOT NULL,
            `application_type` varchar(50) NOT NULL,
            `responses` longtext NOT NULL,
            `status` enum('pending','approved','denied') DEFAULT 'pending',
            `processed_by` varchar(50) DEFAULT NULL,
            `denial_reason` text DEFAULT NULL,
            `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
            `processed_at` timestamp NULL DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`),
            KEY `application_type` (`application_type`),
            KEY `status` (`status`),
            KEY `combined_idx` (`citizenid`, `application_type`, `status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
end)

function sendDiscordNotification(appConfig, appType, notificationType, data)
    if notificationType ~= 'new' then
        return
    end
    
    if not appConfig.discordSettings or not appConfig.discordSettings.enabled then
        if Config.Discord and Config.Discord.enabled then
            local channelId = Config.Discord.defaultChannelId
            local message = data.applicantName .. ' has submitted a new ' .. appConfig.name .. ' Application.'
            sendToDiscordChannel(channelId, message)
        end
        return
    end
    
    local discordSettings = appConfig.discordSettings
    local channelId = discordSettings.channelId
    local message = ""
    
    if discordSettings.newApplicationMessage then
        message = string.format(discordSettings.newApplicationMessage, data.applicantName)
    else
        message = data.applicantName .. ' has submitted a new ' .. appConfig.name .. ' Application, please review at your convenience.'
    end
    
    if message and message ~= "" then
        sendToDiscordChannel(channelId, message)
    end
end

function sendToDiscordChannel(channelId, message)
    if not channelId or not message then
        print('^1[js-businessapps]^7 Discord notification failed: Missing channel ID or message')
        return
    end
    
    local resourceName = (Config.Discord and Config.Discord.resourceName) or 'zdiscord'
    
    if GetResourceState(resourceName) ~= 'started' then
        print('^3[js-businessapps]^7 Discord resource "' .. resourceName .. '" not found or not started. Skipping Discord notification.')
        return
    end
    
    local success, error = pcall(function()
        exports[resourceName]:SendToChannel(channelId, message)
    end)
    
    if success then
        print('^2[js-businessapps]^7 Discord notification sent to channel: ' .. channelId)
    else
        print('^1[js-businessapps]^7 Discord notification failed: ' .. tostring(error))
    end
end

QBCore.Functions.CreateCallback('js-businessapps:server:canApply', function(source, cb, appType)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false, "Player data not found")
        return
    end
    
    local appConfig = Config.Applications[appType]
    if not appConfig then
        cb(false, "Invalid application type")
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    MySQL.single('SELECT id FROM ' .. Config.TableName .. ' WHERE citizenid = ? AND application_type = ? AND status = ?', 
    {citizenid, appType, 'pending'}, function(pendingResult)
        if pendingResult then
            cb(false, "You already have a pending " .. appConfig.name .. " application. Please wait for it to be processed.")
            return
        end
        
        MySQL.single('SELECT processed_at FROM ' .. Config.TableName .. ' WHERE citizenid = ? AND application_type = ? AND status = ? ORDER BY processed_at DESC LIMIT 1', 
        {citizenid, appType, 'denied'}, function(deniedResult)
            if deniedResult then
                local deniedTime = deniedResult.processed_at
                local currentTime = os.time()
                
                local deniedTimestamp
                if type(deniedTime) == "number" then
                    deniedTimestamp = deniedTime
                    if deniedTimestamp > currentTime * 100 then
                        deniedTimestamp = deniedTimestamp / 1000
                    end
                else
                    local year, month, day, hour, min, sec = deniedTime:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
                    deniedTimestamp = os.time{
                        year = tonumber(year),
                        month = tonumber(month),
                        day = tonumber(day),
                        hour = tonumber(hour),
                        min = tonumber(min),
                        sec = tonumber(sec)
                    }
                end
                
                local cooldownSeconds = appConfig.applicationCooldown * 3600 -- Convert hours to seconds
                local cooldownEnd = deniedTimestamp + cooldownSeconds
                
                if currentTime < cooldownEnd then
                    local timeLeft = math.ceil((cooldownEnd - currentTime) / 3600)
                    cb(false, "You must wait " .. timeLeft .. " more hours before applying for " .. appConfig.name .. " again")
                    return
                end
            end
            cb(true)
        end)
    end)
end)

RegisterNetEvent('js-businessapps:server:submitApplication', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then 
        print('^1[js-businessapps]^7 Error: Could not get player data for source ' .. src)
        return 
    end
    
    local appType = data.appType
    local appConfig = Config.Applications[appType]
    
    if not appConfig then
        TriggerClientEvent('js-businessapps:client:applicationResult', src, false, "Invalid application type")
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    local responses = data.responses
    
    -- Validate responses against questions
    if not responses or #responses ~= #appConfig.questions then
        TriggerClientEvent('js-businessapps:client:applicationResult', src, false, "Invalid form data")
        return
    end
    
    -- Validate each response
    for i, question in ipairs(appConfig.questions) do
        local response = responses[i]
        
        if question.required and (not response or response == "") then
            TriggerClientEvent('js-businessapps:client:applicationResult', src, false, question.label .. " is required")
            return
        end
        
        if question.min and string.len(tostring(response)) < question.min then
            TriggerClientEvent('js-businessapps:client:applicationResult', src, false, question.label .. " is too short (minimum " .. question.min .. " characters)")
            return
        end
        
        if question.max and string.len(tostring(response)) > question.max then
            TriggerClientEvent('js-businessapps:client:applicationResult', src, false, question.label .. " is too long (maximum " .. question.max .. " characters)")
            return
        end
        
        -- Validate select options
        if question.type == 'select' and question.options then
            local validOption = false
            for _, option in ipairs(question.options) do
                if option.value == response then
                    validOption = true
                    break
                end
            end
            if not validOption then
                TriggerClientEvent('js-businessapps:client:applicationResult', src, false, "Invalid selection for " .. question.label)
                return
            end
        end
    end
    
    -- Convert responses to JSON
    local responsesJson = json.encode(responses)
    
    MySQL.insert('INSERT INTO ' .. Config.TableName .. ' (citizenid, application_type, responses) VALUES (?, ?, ?)', {
        citizenid, appType, responsesJson
    }, function(insertId)
        if insertId then
            TriggerClientEvent('js-businessapps:client:applicationResult', src, true, "Your " .. appConfig.name .. " application has been submitted successfully!")
            print('^2[js-businessapps]^7 New ' .. appConfig.name .. ' application submitted by ' .. Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' (ID: ' .. insertId .. ')')
            
            -- Send notification to management
            local applicantName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
            notifyManagement(appConfig, responses, applicantName, insertId)
            
            -- Send Discord notification for new application
            sendDiscordNotification(appConfig, appType, 'new', {
                applicantName = applicantName,
                applicationId = insertId
            })
        else
            TriggerClientEvent('js-businessapps:client:applicationResult', src, false, "Failed to submit application. Please try again.")
        end
    end)
end)

QBCore.Functions.CreateCallback('js-businessapps:server:getApplications', function(source, cb, status, appType)
    status = status or 'pending'
    
    if not appType or not Config.Applications[appType] then
        cb({})
        return
    end
    
    local query = [[
        SELECT a.*, CONCAT(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ', JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))) as processor_name 
        FROM ]] .. Config.TableName .. [[ a 
        LEFT JOIN players p ON a.processed_by = p.citizenid 
        WHERE a.status = ? AND a.application_type = ? 
        ORDER BY a.created_at DESC
    ]]
    
    MySQL.query(query, {status, appType}, function(results)
        cb(results or {})
    end)
end)

RegisterNetEvent('js-businessapps:server:processApplication', function(applicationId, action, reason, appType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local appConfig = Config.Applications[appType]
    if not appConfig then
        TriggerClientEvent('js-businessapps:client:applicationResult', src, false, "Invalid application type")
        return
    end
    
    if Player.PlayerData.job.name ~= appConfig.requiredJob or Player.PlayerData.job.grade.level < appConfig.requiredGrade then
        TriggerClientEvent('js-businessapps:client:applicationResult', src, false, "Access denied")
        return
    end
    
    if action ~= 'approved' and action ~= 'denied' then
        TriggerClientEvent('js-businessapps:client:applicationResult', src, false, "Invalid action")
        return
    end
    
    MySQL.single('SELECT * FROM ' .. Config.TableName .. ' WHERE id = ? AND status = ? AND application_type = ?', { 
        applicationId, 'pending', appType
    }, function(application)
        if not application then
            TriggerClientEvent('js-businessapps:client:applicationResult', src, false, "Application not found or already processed")
            return
        end
        
        local query = 'UPDATE ' .. Config.TableName .. ' SET status = ?, processed_by = ?, processed_at = NOW()'
        local params = {action, Player.PlayerData.citizenid}
        
        if action == 'denied' and reason then
            query = query .. ', denial_reason = ?'
            table.insert(params, reason)
        end
        
        query = query .. ' WHERE id = ?'
        table.insert(params, applicationId)
        
        MySQL.update(query, params, function(affectedRows)
            if affectedRows > 0 then
                local message = ""
                if action == 'approved' then
                    message = appConfig.smsSettings.approvedMessage
                else
                    message = string.format(appConfig.smsSettings.deniedMessage, reason or "No specific reason provided")
                end

                local processorName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname

                local applicantPlayer = QBCore.Functions.GetPlayerByCitizenId(application.citizenid)
                if applicantPlayer and applicantPlayer.PlayerData then
                    local applicantSrc = applicantPlayer.PlayerData.source
                    
                    if appConfig.smsSettings.useEmail then
                        pcall(function()
                            TriggerClientEvent('js-businessapps:client:sendEmail', applicantSrc, {
                                sender = appConfig.smsSettings.sender,
                                subject = appConfig.name .. " Application " .. string.upper(action),
                                message = message
                            })
                        end)
                    end
                    
                    if appConfig.smsSettings.useSMS then
                        pcall(function()
                            TriggerClientEvent('qs-smartphone:client:addMessage', applicantSrc, {
                                number = appConfig.smsSettings.senderNumber,
                                message = message,
                                sender = appConfig.smsSettings.sender,
                                time = os.date('%H:%M'),
                                date = os.date('%m/%d/%Y')
                            })
                        end)
                
                        pcall(function()
                            TriggerClientEvent('qs-smartphone:client:notification', applicantSrc, {
                                title = appConfig.smsSettings.sender,
                                text = message,
                                icon = 'fas fa-badge',
                                timeout = 7500
                            })
                        end)
                    end
                else
                    print('^3[js-businessapps]^7 Player offline - ' .. appConfig.name .. ' Application ' .. action .. ' for CitizenID: ' .. application.citizenid .. ' (Name: ' .. applicantName .. ')')
                end
                
                TriggerClientEvent('js-businessapps:client:applicationResult', src, true, appConfig.name .. " application " .. action .. " successfully!")
                TriggerClientEvent('js-businessapps:client:refreshApplications', src, appType)
                print('^3[js-businessapps]^7 ' .. appConfig.name .. ' Application ID ' .. applicationId .. ' ' .. action .. ' by ' .. processorName)
            else
                TriggerClientEvent('js-businessapps:client:applicationResult', src, false, "Failed to process application")
            end
        end)
    end)
end)

QBCore.Commands.Add('checkapp', 'Check your application status', {
    {name = 'type', help = 'Application type (leo, ems, mechanic, delivery)'}
}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    local appType = args[1]
    
    if appType and not Config.Applications[appType] then
        TriggerClientEvent('QBCore:Notify', source, "Invalid application type. Available types: " .. table.concat(getAvailableAppTypes(), ", "), "error")
        return
    end
    
    local query
    local params
    
    if appType then
        query = 'SELECT * FROM ' .. Config.TableName .. ' WHERE citizenid = ? AND application_type = ? ORDER BY created_at DESC LIMIT 1'
        params = {Player.PlayerData.citizenid, appType}
    else
        query = 'SELECT * FROM ' .. Config.TableName .. ' WHERE citizenid = ? ORDER BY created_at DESC'
        params = {Player.PlayerData.citizenid}
    end
    
    MySQL.query(query, params, function(results)
        if not results or #results == 0 then
            if appType then
                TriggerClientEvent('js-businessapps:client:libNotify', source, {
                    title = 'Application System',
                    description = "You have no " .. Config.Applications[appType].name .. " applications on file",
                    type = 'error'
                })
            else
                TriggerClientEvent('js-businessapps:client:libNotify', source, {
                    title = 'Application System', 
                    description = "You have no applications on file",
                    type = 'error'
                })
            end
            return
        end
        
        if appType then
            local result = results[1]
            local appConfig = Config.Applications[result.application_type]
            local statusText = ""
            local notificationType = "info"
            
            if result.status == 'pending' then
                statusText = "Your " .. appConfig.name .. " application is pending review"
                notificationType = "inform"
            elseif result.status == 'approved' then
                statusText = "Your " .. appConfig.name .. " application was approved on " .. result.processed_at
                notificationType = "success"
            else
                statusText = "Your " .. appConfig.name .. " application was denied on " .. result.processed_at
                if result.denial_reason then
                    statusText = statusText .. ". Reason: " .. result.denial_reason
                end
                notificationType = "error"
            end
            
            TriggerClientEvent('js-businessapps:client:libNotify', source, {
                title = 'Application Status',
                description = statusText,
                type = notificationType,
                duration = 8000
            })
        else
            local statusLines = {}
            for _, result in ipairs(results) do
                local appConfig = Config.Applications[result.application_type]
                if appConfig then
                    local line = appConfig.name .. ": " .. string.upper(result.status)
                    if result.status == 'denied' and result.denial_reason then
                        line = line .. " (" .. result.denial_reason .. ")"
                    end
                    table.insert(statusLines, line)
                end
            end
            
            TriggerClientEvent('js-businessapps:client:libNotify', source, {
                title = 'Your Applications',
                description = table.concat(statusLines, '\n'),
                type = 'info',
                duration = 10000
            })
        end
    end)
end)

QBCore.Commands.Add('apptypes', 'List available application types', {}, false, function(source, args)
    local availableTypes = {}
    for appType, appData in pairs(Config.Applications) do
        if appData.enabled then
            table.insert(availableTypes, appType .. " (" .. appData.name .. ")")
        end
    end
    
    TriggerClientEvent('js-businessapps:client:libNotify', source, {
        title = 'Available Applications',
        description = table.concat(availableTypes, '\n'),
        type = 'info',
        duration = 8000
    })
end)

QBCore.Commands.Add('manageapp', 'Manage applications (Admin Only)', {
    {name = 'action', help = 'Action: approve, deny, delete'},
    {name = 'id', help = 'Application ID'},
    {name = 'reason', help = 'Reason (for deny action)'}
}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    if not QBCore.Functions.HasPermission(source, 'admin') then
        TriggerClientEvent('js-businessapps:client:libNotify', source, {
            title = 'Access Denied',
            description = "You don't have permission to use this command",
            type = 'error'
        })
        return
    end
    
    local action = args[1]
    local appId = tonumber(args[2])
    local reason = args[3]
    
    if not action or not appId then
        TriggerClientEvent('js-businessapps:client:libNotify', source, {
            title = 'Invalid Usage',
            description = "Usage: /manageapp [approve/deny/delete] [application_id] [reason]",
            type = 'error'
        })
        return
    end
    
    if action == 'approve' then
        MySQL.single('SELECT application_type FROM ' .. Config.TableName .. ' WHERE id = ?', {appId}, function(result)
            if result then
                TriggerEvent('js-businessapps:server:processApplication', appId, 'approved', nil, result.application_type)
                TriggerClientEvent('js-businessapps:client:libNotify', source, {
                    title = 'Application Management',
                    description = "Application approved",
                    type = 'success'
                })
            else
                TriggerClientEvent('js-businessapps:client:libNotify', source, {
                    title = 'Application Management',
                    description = "Application not found",
                    type = 'error'
                })
            end
        end)
    elseif action == 'deny' then
        if not reason then
            TriggerClientEvent('js-businessapps:client:libNotify', source, {
                title = 'Missing Information',
                description = "Reason required for denial",
                type = 'error'
            })
            return
        end
        MySQL.single('SELECT application_type FROM ' .. Config.TableName .. ' WHERE id = ?', {appId}, function(result)
            if result then
                TriggerEvent('js-businessapps:server:processApplication', appId, 'denied', reason, result.application_type)
                TriggerClientEvent('js-businessapps:client:libNotify', source, {
                    title = 'Application Management',
                    description = "Application denied",
                    type = 'success'
                })
            else
                TriggerClientEvent('js-businessapps:client:libNotify', source, {
                    title = 'Application Management', 
                    description = "Application not found",
                    type = 'error'
                })
            end
        end)
    elseif action == 'delete' then
        MySQL.update('DELETE FROM ' .. Config.TableName .. ' WHERE id = ?', {appId}, function(affectedRows)
            if affectedRows > 0 then
                TriggerClientEvent('js-businessapps:client:libNotify', source, {
                    title = 'Application Management',
                    description = "Application deleted",
                    type = 'success'
                })
            else
                TriggerClientEvent('js-businessapps:client:libNotify', source, {
                    title = 'Application Management',
                    description = "Application not found", 
                    type = 'error'
                })
            end
        end)
    else
        TriggerClientEvent('js-businessapps:client:libNotify', source, {
            title = 'Invalid Action',
            description = "Invalid action. Use: approve, deny, or delete",
            type = 'error'
        })
    end
end, 'admin')

function getAvailableAppTypes()
    local types = {}
    for appType, appData in pairs(Config.Applications) do
        if appData.enabled then
            table.insert(types, appType)
        end
    end
    return types
end

function notifyManagement(appConfig, responses, applicantName, applicationId)
    local players = QBCore.Functions.GetPlayers()
    local managementNotified = 0
    
    print('^3[DEBUG]^7 Looking for ' .. appConfig.requiredJob .. ' grade ' .. appConfig.requiredGrade .. '+ players')
    
    applicationId = tonumber(applicationId) or 0
    
    local message = ""
    if appConfig.managementNotifications and appConfig.managementNotifications.newApplicationMessage then
        -- Try to format with the config message
        local success, formattedMessage = pcall(function()
            return string.format(
                appConfig.managementNotifications.newApplicationMessage,
                applicantName, applicationId
            )
        end)
        
        if success then
            message = formattedMessage
        else
            message = "New " .. appConfig.name .. " application from " .. applicantName .. " (ID: " .. applicationId .. ") requires review."
            print('^1[ERROR]^7 Failed to format notification message: ' .. tostring(formattedMessage))
        end
    else
        message = "New " .. appConfig.name .. " application from " .. applicantName .. " (ID: " .. applicationId .. ") requires review."
    end
    
    print('^2[DEBUG]^7 Notification message: ' .. message)
    
    for _, playerId in pairs(players) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player and Player.PlayerData.job then
            if Player.PlayerData.job.name == appConfig.requiredJob and 
               Player.PlayerData.job.grade.level >= appConfig.requiredGrade then
                
                local src = Player.PlayerData.source
                print('^2[DEBUG]^7 Sending notifications to ' .. Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' (Source: ' .. src .. ')')
                
                if appConfig.managementNotifications and appConfig.managementNotifications.useEmail then
                    print('^3[DEBUG]^7 Sending email notification...')
                    
                    TriggerClientEvent('js-businessapps:client:sendEmail', src, {
                        sender = appConfig.managementNotifications.sender or "HR System",
                        subject = "New " .. appConfig.name .. " Application Submitted",
                        message = message
                    })
                end
                
                if appConfig.managementNotifications and appConfig.managementNotifications.useSMS then
                    print('^3[DEBUG]^7 Sending SMS notification...')
                    
                    TriggerClientEvent('qs-smartphone:client:addMessage', src, {
                        number = appConfig.managementNotifications.senderNumber or "555-HR",
                        message = message,
                        sender = appConfig.managementNotifications.sender or "HR System",
                        time = os.date('%H:%M'),
                        date = os.date('%m/%d/%Y')
                    })
                    
                    TriggerClientEvent('qs-smartphone:client:notification', src, {
                        title = appConfig.managementNotifications.sender or "HR System",
                        text = "New " .. appConfig.name .. " application requires review",
                        icon = 'fas fa-clipboard',
                        timeout = 7500
                    })
                end
                
                TriggerClientEvent('js-businessapps:client:libNotify', src, {
                    title = 'Application System',
                    description = "New " .. appConfig.name .. " application from " .. applicantName .. " requires review",
                    type = 'inform'
                })
                
                managementNotified = managementNotified + 1
            end
        end
    end 
end