Config = {}

Config.ApplicationsEnabled = true
Config.EnableDebug = false
Config.TableName = 'js_applications'
Config.Discord = {
    enabled = true,
    defaultChannelId = "1411401270815752295", 
    resourceName = "zdiscord"
}

Config.Applications = {
    ['leo'] = {
        name = "Law Enforcement",
        description = "Apply to join the SAST",
        enabled = true,
        applicationDesk = {
            coords = vector3(621.03, 8.32, 83.64),
            heading = 270.0,
            distance = 2
        },
        managementDesk = {
            coords = vector3(634.08, -8.03, 87.75),
            heading = 35.0,
            distance = 1.0
        },
        requiredJob = 'sast',
        requiredGrade = 5,
        applicationCooldown = 2,
        smsSettings = {
            sender = "SAST HR",
            senderNumber = "911-SAST",
            approvedMessage = "Congratulations! Your LEO application has been approved. Someone from our training team will contact you within 24-48 hours for the next steps.",
            deniedMessage = "Unfortunately, your LEO application has been denied. Reason: %s. You may reapply in 2 days.",
            useEmail = true,
            useSMS = false,
        },
        managementNotifications = {
            sender = "SAST HR System",
            senderNumber = "911-HR",
            newApplicationMessage = "A new LEO application has been submitted by %s (Application ID: %d). Please review it in the management system.",           
            useEmail = true,
            useSMS = false,
        },
        discordSettings = {
            enabled = true,
            channelId = "1411401270815752292",
            newApplicationMessage = "%s has submitted a new LEO Application, please review at your convenience."
        },
        questions = {
            {type = 'input', label = 'Discordia ID', description = 'Enter your Discordia ID', required = true, min = 2, max = 50},
            {type = 'input', label = 'Your Name', description = 'Enter your full name', required = true, min = 7, max = 30},
            {type = 'input', label = 'Phone Number', description = 'Enter your phone number', required = true, min = 10, max = 10},
            {type = 'select', label = 'Previous Law Enforcement Experience?', options = {
                {value = 'yes', label = 'Yes'},
                {value = 'no', label = 'No'}
            }, required = true},
            {type = 'select', label = 'Have you ever been convicted of a felony in the state?', options = {
                {value = 'yes', label = 'Yes'},
                {value = 'no', label = 'No'}
            }, required = true},
            {type = 'textarea', label = 'If yes explain why', description = 'Describe what crimes you were charged for', required = false, min = 0, max = 500, autosize = true},
            {type = 'select', label = 'If Accepted, How can we contact you?', options = {
                {value = 'yes', label = 'Phone'},
                {value = 'no', label = 'Discordia'}
            }, required = true}
        }
    },
    
    ['ems'] = {
        name = "Emergency Medical Services",
        description = "Apply to join the EMS",
        enabled = true,
        applicationDesk = {
            coords = vector3(-1013.21, -414.18, 39.54),
            heading = 26.0,
            distance = 0.8
        },
        managementDesk = {
            coords = vector3(-1004.75, -417.8, 39.54),
            heading = 26.0,
            distance = 0.6
        },
        requiredJob = 'ambulance',
        requiredGrade = 5,
        applicationCooldown = 2,
        smsSettings = {
            sender = "EMS HR",
            senderNumber = "911-EMS",
            approvedMessage = "Congratulations! Your EMS application has been approved. Someone from the EMS Team will contact you shortly.",
            deniedMessage = "Unfortunately, your EMS application has been denied. Reason: %s. You may reapply in 2 days.",
            useEmail = true,
            useSMS = false,
        },
        managementNotifications = {
            sender = "EMS HR System", 
            senderNumber = "911-EMS-HR",
            newApplicationMessage = "New EMS application received from %s (ID: %d). Medical experience assessment needed.",
            useEmail = true,
            useSMS = true,
        },
        discordSettings = {
            enabled = false,
            channelId = "1411401270815752293",
            newApplicationMessage = "%s has submitted a new EMS Application, please review at your convenience."
        },
        questions = {
            {type = 'input', label = 'Discordia ID', description = 'Enter your Discordia ID', required = true, min = 2, max = 50},
            {type = 'input', label = 'Your Name', description = 'Enter your full name', required = true, min = 7, max = 30},
            {type = 'input', label = 'Phone Number', description = 'Enter your phone number', required = true, min = 7, max = 15},
            {type = 'select', label = 'Which Field do you wish to work in?', options = {
                {value = 'fire', label = 'SanAndreas Fire'},
                {value = 'ems', label = 'SanAndreas EMS'},
                {value = 'both', label = 'Both SAFD & SAEMS'}
            }, required = true},
            {type = 'select', label = 'Do you have previous Medical Experience?', options = {
                {value = 'yes', label = 'Yes'},
                {value = 'no', label = 'No'}
            }, required = true},
            {type = 'select', label = 'Have you ever been convicted of a felony in the state?', options = {
                {value = 'yes', label = 'Yes'},
                {value = 'no', label = 'No'}
            }, required = true},
            {type = 'textarea', label = 'If yes explain why', description = 'Describe what crimes you were charged for', required = false, min = 0, max = 500, autosize = true}
        }
    },

    ['business'] = {
        name = "Business",
        description = "Apply to own a business",
        enabled = false,
        applicationDesk = {
            coords = vector3(-543.64, -198.14, 38.13),
            heading = 89.99,
            distance = 1.0
        },
        managementDesk = {
            coords = vector3(-528.28, -189.46, 43.25),
            heading = 144.99,
            distance = 1.0
        },
        requiredJob = 'city',
        requiredGrade = 4,
        applicationCooldown = 2,
        smsSettings = {
            sender = "City Of Los Santos",
            senderNumber = "411-LS",
            approvedMessage = "Congratulations! Your business application has been approved. Someone from the Mayors Office will contact you shortly.",
            deniedMessage = "Unfortunately, your business application has been denied. Reason: %s. You may reapply in 2 days.",
            useEmail = true,
            useSMS = false,
        },
        managementNotifications = {
            sender = "City Of Los Santos", 
            senderNumber = "411-LS",
            newApplicationMessage = "New business application received from %s (ID: %d).",
            useEmail = true,
            useSMS = true,
        },
        discordSettings = {
            enabled = true,
            channelId = "1411401270815752294",
            newApplicationMessage = "%s has submitted a new Business Application, please review at your convenience."
        },
        questions = {
            {type = 'input', label = 'Discordia ID', description = 'Enter your Discordia ID', required = true, min = 2, max = 50},
            {type = 'input', label = 'Your Name', description = 'Enter your full name', required = true, min = 7, max = 30},
            {type = 'input', label = 'Phone Number', description = 'Enter your phone number', required = true, min = 7, max = 15},
            {type = 'select', label = 'Which Field will this business apply?', options = {
                {value = 'food', label = 'Food Services'},
                {value = 'auto', label = 'Auto Services'},
                {value = 'tow', label = 'Towing Services'},
                {value = 'security', label = 'Security Services'},
                {value = 'other', label = 'Other Service'}
            }, required = true},
            {type = 'input', label = 'If other enter it here', description = 'Enter business field', required = false, min = 0, max = 30},
            {type = 'input', label = 'Where will you be located?', description = 'Enter Postal Code', required = true, min = 3, max = 5},
            {type = 'select', label = 'Will this building need a custom interior?', options = {
                {value = 'yes', label = 'Yes'},
                {value = 'no', label = 'No'}
            }, required = true},
            {type = 'select', label = 'If yes do you have an interior or have one in mind?', options = {
                {value = 'yes', label = 'Yes'},
                {value = 'no', label = 'No'}
            }, required = false},
            {type = 'textarea', label = 'Explain your business', description = 'Describe what your business will do', required = true, min = 10, max = 1000, autosize = true}
        }
    },
}