# Passbolt Local Installation with Docker for Shared hosting

This project provides a setup to install Passbolt locally in a container, with the intention of later uploading the generated files to a shared hosting environment. The setup is based on the official Passbolt documentation for installing the API from source: [Install Passbolt API from Source](https://www.passbolt.com/docs/hosting/install/ce/from-source/).

## ⚠️ Warning

This deployment method for Passbolt is not recommended by the official Passbolt team or much of the community due to security risks. Some of these risks include:

- **Key leakage**: Misconfiguration by the maintainer or hosting provider can expose private keys.
- **Insecure backups**: Backups may contain sensitive keys if not handled properly.
- **Insufficient isolation**: Critical keys and data may not be adequately isolated in a shared hosting environment.
- **Complicated updates**: This method can make securely updating Passbolt more difficult.

However, this alternative can be viable as long as the hosting provider meets all requirements and the maintainer is fully aware of the associated risks and limitations.

## Prerequisites

Ensure your hosting environment meets the following requirements:

- **PHP**: >= 8.2.0 (Passbolt v5 requires PHP 8.2.0 or higher)
- **GnuPG**
- **PHP Extensions**:
  - PHP-GNUPG: for key verification and authentication.
  - CakePHP default requirements: Intl, mbstring, simplexml.
  - FastCGI Process Manager (FPM).
  - Image manipulation: gd or imagick.
  - Database: Mysqlnd, pdo, pdo_mysql.
  - General defaults: xsl, phar, posix, xml, zlib, ctype, curl, json.
  - Ldap.
  - Additional extensions depending on your configuration (e.g., memcache for sessions).

Additionally, the hosting must support **cron jobs**.

## Installation Steps

Follow these steps to set up Passbolt locally:

### 1. Prepare Environment Variables

1. Copy the `example.env` file to `.env`:
   ```bash
   cp example.env .env
   ```
2. Edit the `.env` file and set the appropriate values for your environment.

### 2. Configure Passbolt

1. Copy the `passbolt.default.php` file to `passbolt.php`:
   ```bash
   cp passbolt.default.php passbolt.php
   ```
2. Edit the `passbolt.php` file to configure your Passbolt instance. Ensure all configurations are set as if the application is ready for deployment, except for the `App.fullBaseUrl` setting, which should be set to `http://localhost` for local execution.

### 3. Start the Docker Container

Run the container using Docker Compose:
```bash
docker compose run --build --rm --service-ports passbolt_setup bash
```

### 4. Install Passbolt Inside the Container

1. Start the Apache server:
   ```bash
   /etc/init.d/apache2 start
   ```

2. Switch to the `www-data` user inside the container:
   ```bash
   su - www-data
   ```

3. Run the Passbolt installation command:
   ```bash
   /var/www/html/bin/cake passbolt install
   ```

4. Perform a health check to ensure everything is set up correctly:
   ```bash
   /var/www/html/bin/cake passbolt healthcheck
   ```
   Note: During the health check, you might encounter the following warnings:
   - `[FAIL] Passbolt is not configured to force SSL use.`
   - `[FAIL] App.fullBaseUrl is not set to HTTPS.`
   - `[WARN] System clock and NTP service information cannot be found.`
   These warnings occur because the application is running locally without SSL and because the Docker container does not have NTP configured for time synchronization.

5. Exit the `www-data` user session to switch back to the root user:
   ```bash
   exit
   ```

### 5. Copy Installation Files

Copy the Passbolt installation files to the output directory for later upload, excluding `.github`, `.gitlab-ci`, and `.git` directories:
```bash
rsync -av --exclude='.github' --exclude='.gitlab-ci' --exclude='.git' /var/www/html/ /output/
```

### 6. Backup GnuPG Keys

Before proceeding, create a backup of the GnuPG keys generated during the installation. These keys are critical for the security of your Passbolt instance.

Copy all contents, including hidden files, from `/var/www/.gnupg/` to the newly created `gnupg` folder:
```bash
rsync -av --include='.*' /var/www/.gnupg/ /gnupg/
```

**Important**: Store the `gnupg` folder and its contents securely. These files contain the private and public keys required for Passbolt to function correctly. Unauthorized access to these keys can compromise the security of your Passbolt instance.

### 7. Exit the Container

After copying the files, exit the container:
```bash
exit
```

### 8. Configure Permissions for Copied Files

Ensure the copied files have the correct ownership and permissions. Replace `$USER` with your current user:

1. For the `html` folder:
   ```bash
   sudo chown -R $USER html
   sudo chmod u+w -R html
   ```

2. For the `gnupg` folder:
   ```bash
   sudo chown -R $USER gnupg
   sudo chmod u+w -R gnupg
   ```

### 9. (Optional) Create a Zip Archive of the `html` Folder

To simplify uploading, you can create a zip file of the `html` folder, including all files (hidden files as well):
```bash
zip -r html.zip html
```

### 10. Upload Files to Shared Hosting

1. The files are now available in the `./html/` directory on your local machine, thanks to the Docker Compose volume configuration.
2. Before uploading, edit the `config/passbolt.php` file and replace the `App.fullBaseUrl` value with the HTTPS URL where the application will be deployed. For example:
   ```php
   'App' => [
       'fullBaseUrl' => 'https://your-hosting-url.com',
   ],
   ```
3. In the same `config/passbolt.php` file, ensure that SSL is enforced by setting:
   ```php
   'passbolt' => [
       'ssl' => [
           'force' => true,
       ],
   ],
   ```
4. Upload these files to your shared hosting environment.
5. Configure a cron job to execute `bin/cron` within the Passbolt directory. This is necessary for tasks like sending emails. As an example, the `cron_hostinger.sh` script demonstrates how to set up a cron job for a specific hosting provider. The cron job command for this script might look like this:
   ```bash
   * * * * * /bin/bash /path/to/passbolt/cron_hostinger.sh
   ```

### 11. File Permissions Configuration

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

### 12. (Optional) Address Hosting Time Offset Issues

In some cases, the hosting server's clock may be offset by several seconds or even minutes from the correct time. This can cause synchronization issues between the client and server, particularly in the mobile application, preventing successful login attempts.

To resolve this issue, follow these steps:

1. **Upload the `cron_time_offset.php` File**:
   - Place the `cron_time_offset.php` file in the Passbolt directory.

2. **Set Execution Permissions**:
   - Ensure the script has execution permissions by running:
     ```bash
     chmod +x /path/to/passbolt/cron_time_offset_hostinger.sh
     ```

3. **Configure a Cron Job**:
   - Set up a cron job to execute the PHP script frequently (recommended every hour or every minute). For example, on Hostinger, you can upload and configure the `cron_time_offset_hostinger.sh` script as follows:
     ```bash
     * * * * * /bin/bash /path/to/passbolt/cron_time_offset_hostinger.sh
     ```

4. **Adjust the `AppController.php` File**:
   - Navigate to the `src/Controller/AppController.php` file in the Passbolt directory (in Passbolt v5.2 or find the equivalent in other versions).
   - Locate the `success` function (in Passbolt v5.2 or find the equivalent in other versions).
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

By implementing these steps, you can mitigate time synchronization issues and ensure proper functionality of the Passbolt instance.

## Updates

For detailed instructions on how to update your Passbolt instance, please refer to the [Update Guide](UPDATE.md).

---

## Additional Resources

- [Passbolt Documentation](https://www.passbolt.com/docs)
- [Passbolt Community Forum](https://community.passbolt.com/)

## License

This repository is dual-licensed:

- **MIT License** – all original files (Dockerfile, compose, scripts, README, etc.).
- **GNU AGPL v3** – `passbolt.default.php` (copied from Passbolt CE). See the header inside that file for details.
