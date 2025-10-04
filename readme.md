- **Multiple Application Types**: Support for unlimited different application types (LEO, EMS, Mechanic, Delivery, etc.)
- **Dynamic Questions**: Each application type can have completely different questions and validation
- **Individual Cooldowns**: Each application type can have its own cooldown period
- **Separate Management**: Each organization can manage only their own applications
- **Enhanced Commands**: Check specific application types or view all applications
- **Admin Commands**: Server administrators can manage any application
- **Flexible SMS/Email**: Each application type has its own messaging configuration

## Installation

1. **Database Creation**: The script will automatically create the table structure.

```sql
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
```

2. **Dependencies**: Ensure you have the following resources:
   - `qb-core`
   - `qb-target` or `ox_target`
   - `ox_lib`
   - `qs-smartphone` (optional, for SMS/Email features)

## Configuration

### Adding New Application Types

To add a new application type, simply add a new entry to `Config.Applications` in the config file:

```lua
['your_job_name'] = {
    name = "Display Name",
    description = "Brief description",
    enabled = true,
    applicationDesk = {
        coords = vector3(x, y, z),
        heading = 0.0,
        distance = 1.0
    },
    managementDesk = {
        coords = vector3(x, y, z), 
        heading = 0.0,
        distance = 2.0
    },
    requiredJob = 'job_name',
    requiredGrade = 5,
    applicationCooldown = 168, -- hours
    smsSettings = {
        sender = "Organization Name",
        senderNumber = "555-0123",
        approvedMessage = "Congratulations! Your application has been approved.",
        deniedMessage = "Unfortunately, your application was denied. Reason: %s",
        useEmail = true,
        useSMS = false,
    },
    questions = {
        -- Define your custom questions here
    }
}
```

#### Input Field
```lua
{
    type = 'input', 
    label = 'Question Label', 
    description = 'Helper text', 
    required = true, 
    min = 2, 
    max = 50
}
```

#### Textarea
```lua
{
    type = 'textarea', 
    label = 'Long Answer Question', 
    description = 'Describe something in detail', 
    required = true, 
    min = 50, 
    max = 500, 
    autosize = true
}
```

#### Dropdown Selection
```lua
{
    type = 'select', 
    label = 'Choose One', 
    options = {
        {value = 'option1', label = 'Option 1'},
        {value = 'option2', label = 'Option 2'},
        {value = 'option3', label = 'Option 3'}
    }, 
    required = true
}
```

#### Number Input
```lua
{
    type = 'number', 
    label = 'Enter Age', 
    description = 'Must be 18 or older', 
    required = true, 
    min = 18, 
    max = 99
}
```

## Commands

### Player Commands

- `/checkapp` - View all your applications
- `/checkapp [type]` - View specific application type (e.g., `/checkapp leo`)
- `/apptypes` - List all available application types

### Admin Commands

- `/manageapp approve [id]` - Approve an application by ID
- `/manageapp deny [id] [reason]` - Deny an application with reason
- `/manageapp delete [id]` - Delete an application (permanent)

## Usage

### For Players
1. Go to the application desk for the job you want to apply for
2. Use qb-target or ox_target to interact with the desk
3. Fill out the application form
4. Wait for management to review your application
5. Receive notification via SMS/Email when processed

### For Management
1. Go to the management desk for your organization
2. Use qb-target or ox_target to access the management system
3. Review pending, approved, or denied applications
4. Approve or deny applications with reasons

### For Administrators
- Use the `/manageapp` command to override any application decision
- Use `/checkapp [player_citizenid]` to check any player's applications (requires modification for admin use) 

## Customization Examples

### Police Department
```lua
['police'] = {
    name = "LSPD Officer",
    requiredJob = 'police',
    requiredGrade = 4,
    questions = {
        {type = 'input', label = 'Full Name', required = true, min = 2, max = 50},
        {type = 'input', label = 'Phone Number', required = true, min = 10, max = 15},
        {type = 'select', label = 'Previous Experience', options = {
            {value = 'none', label = 'No Experience'},
            {value = 'security', label = 'Security Guard'},
            {value = 'military', label = 'Military/Law Enforcement'}
        }, required = true},
        {type = 'textarea', label = 'Why do you want to be a police officer?', required = true, min = 100, max = 500}
    }
}
```

### Medical Services
```lua
['ems'] = {
    name = "Paramedic",
    requiredJob = 'ambulance',
    requiredGrade = 3,
    questions = {
        {type = 'input', label = 'Full Name', required = true, min = 2, max = 50},
        {type = 'number', label = 'Age', required = true, min = 21, max = 65},
        {type = 'select', label = 'Medical Certification', options = {
            {value = 'basic', label = 'Basic First Aid'},
            {value = 'emt', label = 'EMT Certified'},
            {value = 'paramedic', label = 'Paramedic Licensed'}
        }, required = true}
    }
}
```

## Troubleshooting Common Issues

1. **Applications not appearing**: Check that the application type is enabled in config
2. **Permission errors**: Verify job names and grade requirements match your server
3. **Target zones not working**: Ensure qb-target or ox_target is properly installed
4. **SMS/Email not working**: Check qs-smartphone installation and config settings

### Debug Mode

Enable debug prints by adding this to your config:
```lua
Config.Debug = true
```