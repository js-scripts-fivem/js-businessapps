local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}

CreateThread(function()
    while QBCore.Functions.GetPlayerData() == nil do
        Wait(200)
    end
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

if Config.ApplicationsEnabled then 
    CreateThread(function()
        while not LocalPlayer.state.isLoggedIn do
            Wait(500)
        end
        
        while GetResourceState('qb-target') ~= 'started' and GetResourceState('ox_target') ~= 'started' do
            Wait(1000)
        end
        
        Wait(2000)
        
        for appType, appData in pairs(Config.Applications) do
            if appData.enabled then
                print('^3[DEBUG]^7 Setting up ' .. appType .. ' application desk at: ' .. appData.applicationDesk.coords)
                
                if GetResourceState('qb-target') == 'started' then
                    exports['qb-target']:AddBoxZone(appType .. "_application_desk", appData.applicationDesk.coords, 1.5, 1.0, {
                        name = appType .. "_application_desk",
                        heading = appData.applicationDesk.heading,
                        debugPoly = false,
                        minZ = appData.applicationDesk.coords.z - 1,
                        maxZ = appData.applicationDesk.coords.z + 1,
                    }, {
                        options = {
                            {
                                type = "client",
                                event = "js-businessapps:client:openApplication",
                                icon = "fas fa-clipboard",
                                label = "Submit " .. appData.name .. " Application",
                                appType = appType
                            },
                        },
                        distance = appData.applicationDesk.distance
                    })
                elseif GetResourceState('ox_target') == 'started' then
                    exports.ox_target:addBoxZone({
                        coords = appData.applicationDesk.coords,
                        size = vec3(1.5, 1.0, 1.0),
                        rotation = appData.applicationDesk.heading,
                        options = {
                            {
                                name = appType .. '_application',
                                event = 'js-businessapps:client:openApplication',
                                icon = 'fas fa-clipboard',
                                label = 'Submit ' .. appData.name .. ' Application',
                                appType = appType
                            }
                        }
                    })
                end
                
                if GetResourceState('qb-target') == 'started' then
                    exports['qb-target']:AddBoxZone(appType .. "_management_desk", appData.managementDesk.coords, 1.5, 1.0, {
                        name = appType .. "_management_desk",
                        heading = appData.managementDesk.heading,
                        debugPoly = false,
                        minZ = appData.managementDesk.coords.z - 1,
                        maxZ = appData.managementDesk.coords.z + 1,
                    }, {
                        options = {
                            {
                                type = "client",
                                event = "js-businessapps:client:openManagement",
                                icon = "fas fa-users-cog",
                                label = "Review " .. appData.name .. " Applications",
                                job = appData.requiredJob,
                                appType = appType
                            },
                        },
                        distance = appData.managementDesk.distance
                    })
                elseif GetResourceState('ox_target') == 'started' then
                    exports.ox_target:addBoxZone({
                        coords = appData.managementDesk.coords,
                        size = vec3(1.5, 1.0, 1.0),
                        rotation = appData.managementDesk.heading,
                        options = {
                            {
                                name = appType .. '_management',
                                event = 'js-businessapps:client:openManagement',
                                icon = 'fas fa-users-cog',
                                label = 'Review ' .. appData.name .. ' Applications',
                                groups = {[appData.requiredJob] = appData.requiredGrade},
                                appType = appType
                            }
                        }
                    })
                end
            end
        end
        
        if GetResourceState('qb-target') ~= 'started' and GetResourceState('ox_target') ~= 'started' then
            print('^1[js-businessapps]^7 No compatible targeting system found (qb-target or ox_target)')
        end
    end)
end 

RegisterNetEvent('js-businessapps:client:openApplication', function(data)
    local appType = data.appType or 'leo' -- Default fallback
    local appConfig = Config.Applications[appType]
    
    if not appConfig then
        lib.notify({
            title = 'Application System',
            description = 'Invalid application type',
            type = 'error'
        })
        return
    end
    
    QBCore.Functions.TriggerCallback('js-businessapps:server:canApply', function(canApply, reason)
        if not canApply then
            lib.notify({
                title = 'Application System',
                description = reason,
                type = 'error'
            })
            return
        end
        
        local input = lib.inputDialog(appConfig.name .. ' Application Form', appConfig.questions)

        if not input then return end

        local applicationData = {
            appType = appType,
            responses = input
        }

        TriggerServerEvent('js-businessapps:server:submitApplication', applicationData)
    end, appType)
end)

RegisterNetEvent('js-businessapps:client:openManagement', function(data)
    local appType = data.appType or 'leo'
    local appConfig = Config.Applications[appType]
    
    if not appConfig then
        lib.notify({
            title = 'Access Denied',
            description = 'Invalid application type',
            type = 'error'
        })
        return
    end
    
    if not PlayerData.job or PlayerData.job.name ~= appConfig.requiredJob or PlayerData.job.grade.level < appConfig.requiredGrade then
        lib.notify({
            title = 'Access Denied',
            description = 'You do not have permission to access this system',
            type = 'error'
        })
        return
    end
    
    lib.registerContext({
        id = appType .. '_applications_main',
        title = appConfig.name .. ' Application Management',
        options = {
            {
                title = 'Pending Applications',
                description = 'View applications awaiting review',
                icon = 'clock',
                iconColor = 'orange',
                onSelect = function()
                    openApplicationList('pending', appType)
                end
            },
            {
                title = 'Approved Applications',
                description = 'View approved applications',
                icon = 'check',
                iconColor = 'green',
                onSelect = function()
                    openApplicationList('approved', appType)
                end
            },
            {
                title = 'Denied Applications',
                description = 'View denied applications',
                icon = 'times',
                iconColor = 'red',
                onSelect = function()
                    openApplicationList('denied', appType)
                end
            }
        }
    })
    
    lib.showContext(appType .. '_applications_main')
end)

function openApplicationList(status, appType)
    local appConfig = Config.Applications[appType]
    
    QBCore.Functions.TriggerCallback('js-businessapps:server:getApplications', function(applications)
        if not applications or #applications == 0 then
            lib.notify({
                title = 'Application System',
                description = 'No ' .. status .. ' applications found',
                type = 'info'
            })
            return
        end
        
        local options = {}
        local statusColors = {
            pending = 'orange',
            approved = 'green',
            denied = 'red'
        }
        
        for i, app in ipairs(applications) do
            local description = 'Applied: ' .. app.created_at
            if app.processed_at then
                description = description .. ' | Processed: ' .. app.processed_at
            end
            if app.processed_by then
                description = description .. ' | By: ' .. (app.processor_name or 'Unknown')
            end
            
            local applicantName = "Unknown"
            if app.responses and type(app.responses) == "string" then
                local success, decoded = pcall(json.decode, app.responses)
                if success and decoded and decoded[1] then
                    applicantName = decoded[1]
                end
            end
            
            table.insert(options, {
                title = applicantName,
                description = description,
                icon = 'user',
                iconColor = statusColors[status],
                onSelect = function()
                    openApplicationDetail(app, status, appType)
                end
            })
        end
        
        lib.registerContext({
            id = appType .. '_applications_list',
            title = string.upper(string.sub(status, 1, 1)) .. string.sub(status, 2) .. ' ' .. appConfig.name .. ' Applications',
            menu = appType .. '_applications_main',
            options = options
        })
        
        lib.showContext(appType .. '_applications_list')
    end, status, appType)
end

function openApplicationDetail(application, status, appType)
    local appConfig = Config.Applications[appType]
    local responses = {}
    
    if application.responses and type(application.responses) == "string" then
        local success, decoded = pcall(json.decode, application.responses)
        if success and decoded then
            responses = decoded
        end
    end
    
    local options = {}
    
    for i, question in ipairs(appConfig.questions) do
        local response = responses[i] or "No response"
        
        if question.type == 'select' and question.options then
            for _, option in ipairs(question.options) do
                if option.value == response then
                    response = option.label
                    break
                end
            end
        end
        
        table.insert(options, {
            title = question.label,
            description = tostring(response),
            icon = getIconForQuestionType(question.type),
            disabled = true
        })
    end
    
    table.insert(options, {
        title = 'Applied Date',
        description = application.created_at,
        icon = 'calendar',
        disabled = true
    })
    
    if application.processed_at then
        table.insert(options, {
            title = 'Processed Date',
            description = application.processed_at,
            icon = 'clock',
            disabled = true
        })
    end
    
    if application.processor_name then
        table.insert(options, {
            title = 'Processed By',
            description = application.processor_name,
            icon = 'user-tie',
            disabled = true
        })
    end
    
    if application.denial_reason then
        table.insert(options, {
            title = 'Denial Reason',
            description = application.denial_reason,
            icon = 'exclamation-triangle',
            iconColor = 'red',
            disabled = true
        })
    end
    
    if status == 'pending' then
        table.insert(options, {
            title = '✅ Approve Application',
            description = 'Approve this application',
            icon = 'check',
            iconColor = 'green',
            onSelect = function()
                local applicantName = responses[1] or "Unknown"
                local alert = lib.alertDialog({
                    header = 'Approve Application',
                    content = 'Are you sure you want to approve ' .. applicantName .. '\'s ' .. appConfig.name .. ' application?',
                    centered = true,
                    cancel = true
                })
                
                if alert == 'confirm' then
                    TriggerServerEvent('js-businessapps:server:processApplication', application.id, 'approved', nil, appType)
                end
            end
        })
        
        table.insert(options, {
            title = '❌ Deny Application',
            description = 'Deny this application with reason',
            icon = 'times',
            iconColor = 'red',
            onSelect = function()
                local input = lib.inputDialog('Deny Application', {
                    {type = 'textarea', label = 'Reason for denial', description = 'Provide a reason for denial', required = true, min = 10, max = 200, autosize = true}
                })
                
                if input and input[1] then
                    TriggerServerEvent('js-businessapps:server:processApplication', application.id, 'denied', input[1], appType)
                end
            end
        })
    end
    
    lib.registerContext({
        id = 'application_detail',
        title = appConfig.name .. ' Application - ' .. string.upper(status),
        menu = appType .. '_applications_list',
        options = options
    })
    
    lib.showContext('application_detail')
end

function getIconForQuestionType(questionType)
    local icons = {
        input = 'edit',
        textarea = 'comment',
        select = 'list',
        number = 'hashtag'
    }
    return icons[questionType] or 'question'
end

RegisterNetEvent('js-businessapps:client:applicationResult', function(success, message)
    lib.notify({
        title = 'Application System',
        description = message,
        type = success and 'success' or 'error'
    })
end)

RegisterNetEvent('js-businessapps:client:refreshApplications', function(appType)
    lib.hideContext()
    Wait(100)
    TriggerEvent('js-businessapps:client:openManagement', {appType = appType})
end)

RegisterNetEvent('js-businessapps:client:sendEmail', function(emailData)
    TriggerServerEvent('qs-smartphone:server:sendNewMail', emailData)
end)

RegisterNetEvent('js-businessapps:client:libNotify', function(data)
    lib.notify(data)
end)