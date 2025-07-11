# Passbolt Update Guide

This guide provides step-by-step instructions for updating your Passbolt instance using the Docker setup for shared hosting deployment.

## Prerequisites

Before starting the update process, ensure you have:
- A backup of your current Passbolt installation
- A backup of your database
- Access to your production hosting environment

## Update Steps

### 1. Put Site in Maintenance Mode

Temporarily take down your production site or put it in maintenance mode to prevent users from accessing the application during the update process.

### 2. Download and Prepare Files

1. Download the files from your current Passbolt installation in production
2. Place these files in the `html` folder of this project
3. Ensure the saved installation files from the `/gnupg/` folder are present in this project's `gnupg` directory
4. Verify that the GnuPG files have the correct permissions for the host machine

### 3. Adjust Local Configuration

Edit the local configuration file `config/passbolt.php` and set the following values for local execution:

```php
'App' => [
    'fullBaseUrl' => 'http://localhost',
],
```

and also:

```php
'passbolt' => [
    'ssl' => [
        'force' => false,
    ],
],
```

### 4. Start Docker Container

Execute the Docker service for updates:
```bash
docker compose run --build --rm --service-ports passbolt_update bash
```

### 5. Start Apache

Start the Apache server inside the container:
```bash
/etc/init.d/apache2 start
```

### 6. Run Migration Script

Switch to the `www-data` user and navigate to the `/var/www/html` directory:
```bash
su - www-data
```
```bash
cd /var/www/html
```

Then execute the migration script:
```bash
bin/cake passbolt migrate
```

### 7. Validate Health Check

Run the health check to ensure everything is working correctly:
```bash
bin/cake passbolt healthcheck
```

**Note**: During the health check, you might encounter the following warnings:
- `[FAIL] Passbolt is not configured to force SSL use.`
- `[FAIL] App.fullBaseUrl is not set to HTTPS.`
- `[WARN] System clock and NTP service information cannot be found.`

These warnings occur because the application is running locally without SSL and because the Docker container does not have NTP configured for time synchronization.

**Important**: You must correct all other FAIL or WARN messages that appear during the health check before proceeding.

### 8. Copy Updated Files

Exit the `www-data` user session to switch back to the root user:
```bash
exit
```

Copy the updated Passbolt installation files to the output directory for later upload, excluding `.github`, `.gitlab-ci`, and `.git` directories. Ensure the destination matches the source by removing files that are not present in the source:
```bash
rsync -av --delete --exclude='.github' --exclude='.gitlab-ci' --exclude='.git' /var/www/html/ /output/
```

### 9. Exit Container

After copying the files, exit the container:
```bash
exit
```

### 10. Configure Permissions for Updated Files

Ensure the copied files have the correct ownership and permissions. Replace `$USER` with your current user:

```bash
sudo chown -R $USER html
sudo chmod u+w -R html
```

### 11. (Optional) Create Zip Archive

To simplify uploading, you can create a zip file of the `html` folder, including all files (hidden files as well). Remove any existing zip file first to avoid conflicts:
```bash
rm -f html.zip
```
```bash
zip -r html.zip html
```

### 12. Upload and restore Production Configuration

1. Upload the complete updated folder to a clean directory in your shared hosting environment

2. **Configuration File**: You can either:
   - Manually edit the `config/passbolt.php` file and restore the production values:
     ```php
     'App' => [
         'fullBaseUrl' => 'https://your-hosting-url.com',
     ],
     ```
     and:
     ```php
     'passbolt' => [
         'ssl' => [
             'force' => true,
         ],
     ],
     ```
   - Or simply restore the `config/passbolt.php` file from your production backup

3. **Cron Script**: You can maintain or restore the `cron_hostinger.sh` script (or equivalent) that was previously configured in production

4. Configure the cron job to execute `bin/cron` within the Passbolt directory if it has not been configured according to the installation guide for the first time (you can refer to the [README.md](README.md) for the installation guide)

### 13. File Permissions Configuration

After uploading the files to your shared hosting environment, ensure the following file permissions are correctly set for security and functionality:

1. **JWT Keys and Configuration Directory**:
   - Set the private key to be readable only by the owner:
     ```bash
     chmod 600 /path/to/passbolt/config/jwt/jwt.key
     ```
   - Set the public key to be readable by the owner and group:
     ```bash
     chmod 640 /path/to/passbolt/config/jwt/jwt.pem
     ```
   - Ensure the `config/jwt` directory is accessible only by the owner and remove write permissions:
     ```bash
     chmod 750 /path/to/passbolt/config/jwt
     chmod ugo-w -R /path/to/passbolt/config/jwt/
     ```

2. **Temporary Files**:
   - Allow write permissions for the temporary directory:
     ```bash
     chmod ugo+w -R /path/to/passbolt/tmp/
     ```

3. **Executable Files**:
   - If you used the `cron_hostinger.sh` script, ensure it has execution permissions by running:
     ```bash
     chmod +x /path/to/passbolt/cron_hostinger.sh
     ```

### 14. (Optional) Address Hosting Time Offset Issues

If you had previously configured time offset corrections, you can maintain or restore these configurations from your production version:

1. **Cron Script**: The `cron_time_offset_hostinger.sh` script (or equivalent, as this file is specific for Hostinger) can be maintained or recovered from the production version

2. **AppController.php Modifications**: The modifications to the `src/Controller/AppController.php` file can be maintained or recovered from the production version. However, it's important to validate that the new version works and accepts the same changes in the same file and function without requiring additional modifications to that file.

   You need to make the following specific changes:
   - Navigate to the `src/Controller/AppController.php` file in the Passbolt directory (in Passbolt v5.2 or find the equivalent in other versions)
   - Locate the `success` function (in Passbolt v5.2 or find the equivalent in other versions)
   - Add the following code at the beginning of the function:
     ```php
     $offsetFile = ROOT . DS . 'time-offset.txt';
     $offset = 0;
     if (is_readable($offsetFile)) {
         $raw = trim(file_get_contents($offsetFile));
         if (is_numeric($raw) && abs((int)$raw) <= 120) {
             $offset = (int)$raw;
         }
     }
     ```
   - Adjust the line of code that defines the `servertime` to include the offset generated by the script:
     ```php
     'servertime' => time() + $offset,
     ```

3. **Cron Job Configuration**: Ensure the time offset cron job is properly configured if it was previously set up

## Post-Update Verification

After completing the update:

1. Take the site out of maintenance mode
2. Verify that all functionality works correctly
3. Check that users can log in and access their passwords
4. Monitor the application logs for any errors

## Troubleshooting

If you encounter issues during the update:

1. Check the application logs for error messages
2. Verify file permissions are correctly set
3. Ensure the database migration completed successfully
4. Confirm that the GnuPG keys are properly accessible
5. Validate that the production configuration is correctly restored
