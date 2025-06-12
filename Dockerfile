FROM ubuntu:latest

# Install apache2, git, gnupg, PHP, Composer, and necessary dependencies
RUN apt-get update && \
    apt-get install -y curl apache2 git gnupg \
    php php-cli php-fpm \
    php-gnupg php-intl php-mbstring php-xml \
    php-gd php-imagick \
    php-mysql php-pdo \
    php-xsl php-curl \
    php-ldap php-memcached \
    libapache2-mod-php unzip rsync && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    chmod +x /usr/local/bin/composer && \
    ln -sf /usr/local/bin/composer /usr/bin/composer

# Create the www-data user if it doesn't exist and set proper permissions
RUN echo "/bin/bash" >> /etc/shells && \
    useradd -m -d /var/www -s /bin/bash www-data || usermod -d /var/www -s /bin/bash www-data

# Set proper permissions for apache
RUN mkdir -p /var/www /var/log/apache2 /var/run && \
    chown -R www-data:www-data /var/www /var/log/apache2 /var/run

# Enable Apache modules (mod_rewrite)
RUN a2enmod rewrite

# Create passbolt-tmp folder in the home directory of www-data user
RUN mkdir -p /passbolt-tmp && chown www-data:www-data /passbolt-tmp

# Clone the Passbolt repository and rename it
RUN cd /var/www && \
    git clone https://github.com/passbolt/passbolt_api.git && \
    mv passbolt_api passbolt && \
    chown -R www-data:www-data /var/www/passbolt

# Install Passbolt dependencies with Composer before switching users
RUN cd /var/www/passbolt && composer install --no-dev && \
    chown -R www-data:www-data /var/www/passbolt

# Define build arguments before using them
ARG NAME_REAL
ARG NAME_EMAIL

# Switch to www-data user to generate the GPG key using build arguments
USER www-data
RUN gpg --batch --no-tty --gen-key <<EOF
Key-Type: rsa
Key-Length: 4096
Key-Usage: sign,cert
Subkey-Type: rsa
Subkey-Length: 4096
Subkey-Usage: encrypt
Name-Real: ${NAME_REAL}
Name-Email: ${NAME_EMAIL}
Expire-Date: 0
%no-protection
%commit
EOF

# Create folder for keys and export GPG fingerprint and keys
RUN mkdir -p /var/www/passbolt/config/gpg && \
    KEY_FPR=$(gpg --list-keys --with-colons ${NAME_EMAIL} \
             | awk -F: '/^fpr:/ {print $10; exit}') && \
    echo "$KEY_FPR:6:" | gpg --import-ownertrust && \
    gpg --armor --export-secret-keys $KEY_FPR \
         > /var/www/passbolt/config/gpg/serverkey_private.asc && \
    gpg --armor --export $KEY_FPR \
         > /var/www/passbolt/config/gpg/serverkey.asc && \
    gpg --list-keys --fingerprint | grep -i -B 2 "${NAME_EMAIL}" > /passbolt-tmp/fingerprint.txt

USER root
RUN /var/www/passbolt/bin/cake passbolt create_jwt_keys && \
    chmod 600 /var/www/passbolt/config/jwt/jwt.key && \
    chmod 640 /var/www/passbolt/config/jwt/jwt.pem && \
    chmod 750 /var/www/passbolt/config/jwt

# Copy the custom Passbolt configuration file
USER root
COPY passbolt.php /var/www/passbolt/config/passbolt.php

# Extract the fingerprint from the second line of the file and replace the placeholder
RUN FINGERPRINT=$(sed -n '2p' /passbolt-tmp/fingerprint.txt | tr -d ' ') && \
    sed -i "s/GPG_FINGERPRINT_PLACEHOLDER_TO_BE_REPLACED/$FINGERPRINT/g" /var/www/passbolt/config/passbolt.php && \
    chown www-data:www-data /var/www/passbolt/config/passbolt.php

# Rename Passbolt to html replacing the original html
RUN if [ -d /var/www/html ]; then mv /var/www/html /var/www/html_old; fi && \
    mv /var/www/passbolt /var/www/html

# Allow Apache to read Passbolt's .htaccess
RUN printf '<Directory "/var/www/html">\n\
    Options +FollowSymLinks -MultiViews\n\
    AllowOverride All\n\
    Require all granted\n\
</Directory>\n' > /etc/apache2/conf-available/passbolt.conf \
 && a2enconf passbolt

# Set permissions for Passbolt
RUN chmod ugo+w -R /var/www/html/tmp/ && \
    chmod ugo-w -R /var/www/html/config/jwt/ && \
    chown -R www-data:www-data /var/www/html/config/jwt

# Create output directories for manual copy by user
RUN mkdir -p /output
RUN mkdir -p /gnupg

# Expose port 80
EXPOSE 80

# Default command to start Apache in the foreground
USER root
CMD ["apache2ctl", "-D", "FOREGROUND"]
