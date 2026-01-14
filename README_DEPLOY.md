# Arun Finance - Deployment Guide 🚀

This document outlines how to deploy the **Arun Finance** system to a live server and build the mobile/web applications.

## 1. Backend Deployment (Ubuntu Server)
The backend is a Flask API. We recommend using **Ubuntu 22.04**.

1.  **Prepare the Server**: Point your domain (e.g., `api.arunfinance.com`) to your server's IP.
2.  **Configure the Deployment Script**: Open [deploy.sh](file:///e:/Arun_Finance/deploy.sh) and update the variables at the top:
    -   `APP_DIR`: Path where the code will live.
    -   `DOMAIN`: Your actual domain name.
    -   `DB_PASS`: A secure password for the database.
3.  **Run the Script**:
    ```bash
    chmod +x deploy.sh
    ./deploy.sh
    ```
    This will install MySQL, Nginx, Gunicorn, and set up an SSL certificate automatically.

## 2. Frontend Web Application
The web application is built using Flutter.

-   **Build Command**: `flutter build web`
-   **Output**: The files will be in `frontend/build/web`.
-   **Hosting**: Upload these files to any static host (like Firebase Hosting, Netlify, or your Nginx server's `/var/www/html`).

## 3. Android Application (APK)
To create the mobile app for your workers:

-   **Build Command**: `flutter build apk --release`
-   **Output**: The APK will be in `frontend/build/app/outputs/flutter-apk/app-release.apk`.
-   **Distribution**: You can send this file to your workers via WhatsApp/Telegram or upload it to the Google Play Store.

## 4. Production API Configuration
Before building the apps, ensure the `baseUrl` in `frontend/lib/services/api_service.dart` is updated to your live production domain.

```dart
// Change this to your live domain in api_service.dart
static const String _productionUrl = 'https://api.yourdomain.com/api/auth';
```

## 5. Security & Maintenance
-   **Backups**: Regularly back up your MySQL database.
-   **Updates**: To update the code, run `git pull` on the server and restart the service:
    ```bash
    sudo systemctl restart gunicorn
    ```
