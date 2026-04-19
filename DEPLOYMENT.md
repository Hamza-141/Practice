# Deploying the Carbon Calculator on AWS EC2

This guide walks you through deploying this Django project on an AWS EC2 server from scratch — no prior AWS experience needed.

---

## Table of Contents

1. [Create an AWS Account](#1-create-an-aws-account)
2. [Launch an EC2 Instance](#2-launch-an-ec2-instance)
3. [Connect to Your Server](#3-connect-to-your-server)
4. [Set Up the Server Environment](#4-set-up-the-server-environment)
5. [Deploy the Application](#5-deploy-the-application)
6. [Configure Gunicorn](#6-configure-gunicorn)
7. [Configure Nginx](#7-configure-nginx)
8. [Allow HTTP Traffic Through the Firewall](#8-allow-http-traffic-through-the-firewall)
9. [Test Your Deployment](#9-test-your-deployment)
10. [Keep the App Running After Reboot](#10-keep-the-app-running-after-reboot)
11. [(Optional) Add a Custom Domain and HTTPS](#11-optional-add-a-custom-domain-and-https)
12. [Environment Variables Reference](#12-environment-variables-reference)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. Create an AWS Account

1. Go to [https://aws.amazon.com/](https://aws.amazon.com/) and click **Create an AWS Account**.
2. Enter your email address, create a password, and choose an account name (e.g., `my-carbon-app`).
3. Fill in your contact information and choose **Personal** account type.
4. Enter a valid credit card. AWS requires one even for the Free Tier. You will **not** be charged if you stay within Free Tier limits (the EC2 `t2.micro` instance is free for 12 months).
5. Complete phone verification and select the **Basic Support (Free)** plan.
6. Sign in to the **AWS Management Console** at [https://console.aws.amazon.com/](https://console.aws.amazon.com/).

---

## 2. Launch an EC2 Instance

EC2 (Elastic Compute Cloud) is a virtual server in the cloud.

1. In the AWS Console, search for **EC2** in the top search bar and click it.
2. Click **Launch instance**.
3. Fill in the following settings:

   | Setting | Value |
   |---|---|
   | **Name** | `carbon-calculator-server` |
   | **Application and OS Images** | Ubuntu Server 22.04 LTS (Free tier eligible) |
   | **Instance type** | `t2.micro` (Free tier eligible) |
   | **Key pair (login)** | Click **Create new key pair** → name it `carbon-key` → select **RSA** and **.pem** format → click **Create key pair**. Your browser will download a `carbon-key.pem` file. **Save this file safely — you cannot re-download it.** |
   | **Network settings** | Keep defaults. Check **Allow SSH traffic from** → select **My IP** |
   | **Configure storage** | Keep the default 8 GiB |

4. Click **Launch instance** and wait about 1–2 minutes.
5. Click **View all instances**, then click your new instance to see its **Public IPv4 address** (e.g., `54.210.100.123`). Copy it — you'll use it throughout this guide.

---

## 3. Connect to Your Server

### On macOS / Linux

Open your terminal and run:

```bash
# Move to the folder where carbon-key.pem was downloaded
cd ~/Downloads

# Restrict permissions on the key file (required by SSH)
chmod 400 carbon-key.pem

# Connect (replace YOUR_IP with your EC2 public IP)
ssh -i carbon-key.pem ubuntu@YOUR_IP
```

### On Windows

1. Download and install [PuTTY](https://www.putty.org/).
2. Use **PuTTYgen** to convert `carbon-key.pem` to a `.ppk` file:
   - Open PuTTYgen → **Load** → select `carbon-key.pem` → **Save private key** → save as `carbon-key.ppk`.
3. Open PuTTY:
   - **Host Name**: `ubuntu@YOUR_IP`
   - Go to **Connection → SSH → Auth → Credentials** → browse to `carbon-key.ppk`
   - Click **Open**.

You should now see a terminal prompt like `ubuntu@ip-...:~$`.

---

## 4. Set Up the Server Environment

Run these commands one at a time inside your server terminal:

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Python 3, pip, venv, git, and Nginx
sudo apt install -y python3 python3-pip python3-venv git nginx

# Confirm Python is installed
python3 --version
```

---

## 5. Deploy the Application

```bash
# Clone your GitHub repository (replace URL if your fork differs)
git clone https://github.com/Gi-v/Practice.git

# Enter the project directory
cd Practice

# Create and activate a Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install project dependencies
pip install -r requirements.txt

# Set required environment variables for production
export DJANGO_SECRET_KEY='replace-this-with-a-long-random-secret-key'
export DJANGO_ALLOWED_HOSTS='YOUR_IP'
export DJANGO_DEBUG='False'

# Collect static files (CSS, JS, images) into one folder
python manage.py collectstatic --noinput

# Apply database migrations
python manage.py migrate
```

> **Tip — generating a secret key:** Run this in the terminal to generate a secure key:
> ```bash
> python3 -c "import secrets; print(secrets.token_urlsafe(50))"
> ```
> Copy the output and use it as your `DJANGO_SECRET_KEY` value.

---

## 6. Configure Gunicorn

Gunicorn is the production-grade web server that runs the Django application.

Test that Gunicorn works first:

```bash
# Still inside ~/Practice with the venv activated
gunicorn --bind 0.0.0.0:8000 carbon_calculator.wsgi:application
```

You should see output like `[INFO] Listening at: http://0.0.0.0:8000`. Press `Ctrl+C` to stop it.

Now create a **systemd service** so Gunicorn starts automatically:

```bash
sudo nano /etc/systemd/system/gunicorn.service
```

Paste the following content (replace `YOUR_SECRET_KEY` and `YOUR_IP`):

```ini
[Unit]
Description=Gunicorn daemon for Carbon Calculator
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=/home/ubuntu/Practice
Environment="DJANGO_SECRET_KEY=YOUR_SECRET_KEY"
Environment="DJANGO_ALLOWED_HOSTS=YOUR_IP"
Environment="DJANGO_DEBUG=False"
ExecStart=/home/ubuntu/Practice/venv/bin/gunicorn \
          --access-logfile - \
          --workers 3 \
          --bind unix:/run/gunicorn.sock \
          carbon_calculator.wsgi:application

[Install]
WantedBy=multi-user.target
```

Save the file: press `Ctrl+X`, then `Y`, then `Enter`.

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable gunicorn
sudo systemctl start gunicorn

# Check it's running — you should see "active (running)"
sudo systemctl status gunicorn
```

---

## 7. Configure Nginx

Nginx acts as a reverse proxy: it receives requests from the internet and forwards them to Gunicorn.

```bash
sudo nano /etc/nginx/sites-available/carbon_calculator
```

Paste the following (replace `YOUR_IP`):

```nginx
server {
    listen 80;
    server_name YOUR_IP;

    location = /favicon.ico { access_log off; log_not_found off; }

    location /static/ {
        root /home/ubuntu/Practice;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:/run/gunicorn.sock;
    }
}
```

Save with `Ctrl+X`, `Y`, `Enter`.

Enable the site and restart Nginx:

```bash
# Link the config to the enabled sites
sudo ln -s /etc/nginx/sites-available/carbon_calculator /etc/nginx/sites-enabled/

# Test for configuration errors
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

---

## 8. Allow HTTP Traffic Through the Firewall

Back in the **AWS Console**:

1. Click your EC2 instance → scroll down to the **Security** tab.
2. Click the **Security group** link (e.g., `sg-0abc123...`).
3. Click **Edit inbound rules** → **Add rule**:

   | Type | Protocol | Port range | Source |
   |---|---|---|---|
   | HTTP | TCP | 80 | Anywhere-IPv4 (`0.0.0.0/0`) |

4. Click **Save rules**.

---

## 9. Test Your Deployment

Open a web browser and navigate to:

```
http://YOUR_IP
```

You should see the Carbon Calculator application running. 🎉

---

## 10. Keep the App Running After Reboot

The `systemctl enable gunicorn` command from Step 6 already ensures Gunicorn restarts on reboot. Nginx also starts automatically. To verify both services start at boot:

```bash
sudo systemctl is-enabled gunicorn   # should print: enabled
sudo systemctl is-enabled nginx      # should print: enabled
```

---

## 11. (Optional) Add a Custom Domain and HTTPS

### Add a Domain Name

1. Buy a domain from any registrar (e.g., [Namecheap](https://www.namecheap.com/), [GoDaddy](https://www.godaddy.com/)).
2. In your registrar's DNS settings, create an **A record** pointing your domain to `YOUR_IP`.
3. Update your Nginx config: replace `server_name YOUR_IP;` with `server_name yourdomain.com www.yourdomain.com;`.
4. Update your `DJANGO_ALLOWED_HOSTS` environment variable in `/etc/systemd/system/gunicorn.service` to include your domain.
5. Reload: `sudo systemctl daemon-reload && sudo systemctl restart gunicorn nginx`

### Enable HTTPS with a Free SSL Certificate (Certbot)

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain and install a certificate (replace with your actual domain)
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Certbot will automatically update your Nginx config and set up auto-renewal
```

---

## 12. Environment Variables Reference

| Variable | Description | Example |
|---|---|---|
| `DJANGO_SECRET_KEY` | Long random string used for cryptographic signing | `s3cr3t-abc123...` |
| `DJANGO_ALLOWED_HOSTS` | Comma-separated list of allowed hostnames/IPs | `54.210.100.123` or `yourdomain.com` |
| `DJANGO_DEBUG` | Set to `False` in production | `False` |

---

## 13. Troubleshooting

### "502 Bad Gateway" from Nginx

Gunicorn is not running or crashed. Check its logs:

```bash
sudo systemctl status gunicorn
sudo journalctl -u gunicorn --no-pager -n 50
```

### Application shows debug errors in the browser

Make sure `DJANGO_DEBUG=False` is set in `/etc/systemd/system/gunicorn.service`, then reload:

```bash
sudo systemctl daemon-reload && sudo systemctl restart gunicorn
```

### Static files (CSS/images) not loading

Run `collectstatic` again and ensure the Nginx `location /static/` block points to the correct path:

```bash
cd ~/Practice && source venv/bin/activate
python manage.py collectstatic --noinput
sudo systemctl restart nginx
```

### SSH connection refused

- Make sure port 22 is open in your EC2 security group inbound rules.
- Check you are using the correct `.pem` key and username (`ubuntu` for Ubuntu AMIs).

### Forgot the server's public IP

Find it in the AWS Console under **EC2 → Instances → your instance → Public IPv4 address**.

---

*Guide written for Ubuntu 22.04 LTS on AWS EC2 t2.micro (Free Tier). Tested with Django 4.2, Gunicorn 21.2, and Nginx.*
