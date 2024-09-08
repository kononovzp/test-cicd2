# AWS IAM Setup
- Login to AWS Console and go to IAM Management Console
- On left sidebar go to Users and create a new user (name it as you wish, for example: GitHubActions)
- Set the access type to Programmatic access
- Click on Next: Permissions
- Click on Attach existing policies directly
- Search for AmazonEC2FullAccess, ElasticContainerRegistryFullAccess,  and select them
- Click on Next: Tags
- Click on Next: Review
- Click on Create user
- Download the CSV file with the credentials

# AWS ECR Setup
- Login to AWS Console and go to ECR Management Console
- On left sidebar go to Repositories and create a new private repository (name it as you wish, for example: development)
- On left sidebar go to Repositories and select the repository we created in previous step and click on View push commands

# AWS EC2 Setup

- Login to AWS Console and go to EC2 Management Console
- On left sidebar go to Key Pairs and create a new key pair (name it as you wish, for example: dev_root.pem) and download the key pair file to your local machine.
- On left sidebar go to Security Groups and create a new security group (name it as you wish, for example: WebServices) and add the following rules:
  - SSH (port 22) from your IP address
  - HTTP (port 80) from anywhere
  - HTTPS (port 443) from anywhere
- On left sidebar go to Instances and click on Launch Instance (top-right)
  - Set the name of the instance (for example: Development)
  - Select the AMI (for example: Debian 11 (HVM), SSD Volume Type)
  - Select the instance type (for example: t2.micro)
  - Select the key pair
  - Select the security group
  - Set the storage (for example: 8GB, in most cases is recommended to use more that 64GB)
  - Click on Launch instance

# AWS RDS Setup
- Login to AWS Console and go to RDS Management Console
- On left sidebar go to Databases and click on Create database
  - Select the Easy Create option
  - Select the engine type (for example: PostgreSQL)
  - Select the instance type (for example: Free tier, Dev/Test or Production)
  - Set the name of the database (for example: development)
  - Set the master username and password (for example: postgres and postgres)
  - Click on Create database
- On left sidebar go to Databases and select the database we created in previous step
  - Click on Modify
  - Set the public access to Yes
  - Click on Continue
  - Click on Modify DB instance

# AWS EC2 Post-Setup

### Connect to the instance

On left sidebar go to recent created instace

- Copy the Public DNS (IPv4) address
- Open a terminal and connect to the instance:

```bash
chmod 400 /path/to/keypair.pem
ssh -i /path/to/keypair.pem admin@<public_dns>
```

- When prompted, type "yes" and press enter

### Update system packages

- Update the system:
  ```bash
  sudo apt update -y
  sudo apt upgrade -y
  ```

### Configure AWS CLI
- Install the AWS CLI package:
  ```bash
  sudo apt install awscli -y
  ```

- Configure the AWS CLI (use the credentials downloaded from AWS IAM (step: AWS IAM Setup)):
  ```bash
  aws configure
  ```
  - Enter the AWS Access Key ID
  - Enter the AWS Secret Access Key
  - Enter the AWS Default region name (for example: us-east-1)
  - Enter the AWS Default output format (for example: json)

### Connect to the ECR
- Login to AWS Console and go to ECR Management Console
- On left sidebar go to Repositories and select the repository we created in previous step and click on View push commands
- Copy the docker login command and execute it in the instance terminal

### Connect to the RDS to EC2
- Login to AWS Console and go to RDS Management Console
- On left sidebar go to Databases and select the database we created in previous step
- On right dropdown menu click on Actions
- Select Set up EC2 Connectivity
- Select the EC2 instance we created in previous step

### Install Docker and Docker Compose

- Install the Docker Engine and Docker Compose packages:
  ```bash
  sudo apt install docker.io docker-compose
  ```
- Enable the Docker service:
  ```bash
    sudo systemctl enable docker
  ```
- Verify that the Docker service is running:
  ```bash
    sudo systemctl status docker
  ```
- Add the current user to the docker group:
  ```bash
    sudo usermod -aG docker $USER
  ```
- Logout and login again to the instance

### Install Nginx

- Install the Nginx package:
  ```bash
  sudo apt install nginx -y
  ```
- Enable the Nginx service:
  ```bash
    sudo systemctl enable nginx
  ```
- Verify that the Nginx service is running:
  ```bash
    sudo systemctl status nginx
  ```
- Go to the instance public IP address or DNS in your browser and you should see the Nginx welcome page (make sure that you access over HTTP not HTTPS)

### Nginx Configuration

- Replace the default Nginx configuration file with the following content:
  ```bash
  sudo nano /etc/nginx/sites-available/default
  ```
  ```nginx
  server {
    listen 80;
    server_name _;
    
    gzip on;
    gzip_comp_level 5;
    gzip_disable "msie6";
    gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
    
    # Proxy to backend application
    location ^~ /api/ {
      proxy_pass http://127.0.0.1:3000/;
      http2_push_preload on;
      proxy_http_version 1.1;
      proxy_read_timeout 60s;
      proxy_buffer_size 4096;
      proxy_buffering on;
      proxy_buffers 8 4096;
      proxy_busy_buffers_size 8192;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection $http_connection;
      proxy_set_header Host $http_host;
      proxy_set_header X-Forwarded-For $remote_addr;
      proxy_set_header X-Forwarded-Port $server_port;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_set_header X-Request-Start $msec;
    }

    # Serve frontend static files
    location / {
      root /var/www/html;
      index index.html;
      try_files $uri /$1/index.html?$args /$1/index.html?$args;
    }
  }
  ```

# GitHub Actions Setup

- Login to GitHub and go to your repository
- Go to Settings > Secrets and create the following secrets:
  - AWS_ACCESS_KEY_ID (from AWS IAM)
  - AWS_SECRET_ACCESS_KEY (from AWS IAM)
  - AWS_REGION (from AWS IAM)
  - AWS_EC2_HOST (from AWS EC2 Instance)
  - AWS_EC2_KEY (from AWS EC2 Instance)
  - AWS_EC2_USERNAME (from AWS EC2 Instance)
  - AWS_ECR_REPOSITORY (from AWS ECR)
  - ... (more secrets required for your project)
- Create .github/workflows/development.yaml file and past next code
```yaml
name: CI/CD Development
on:
  push:
    # Change this list of branches if need
    branches: [develop]
  workflow_dispatch:

jobs:
  buildAndPublishToECR:
    name: Build and Publish to AWS ECR
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout
        uses: actions/checkout@v2

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.DEV_AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.DEV_AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.DEV_AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Build, tag, and push image to Amazon ECR
        id: build-image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: ${{ secrets.DEV_AWS_ECR_REPOSITORY }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -f devops/Dockerfile -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
    
  deployToEC2:
    name: Deploy to AWS EC2
    needs: buildAndPublishToECR
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout
        uses: actions/checkout@v2

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.DEV_AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.DEV_AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.DEV_AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Deploy to EC2
        uses: appleboy/ssh-action@master
        env:
          AWS_REGION: ${{ secrets.DEV_AWS_REGION }}
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: ${{ secrets.DEV_AWS_ECR_REPOSITORY }}
          IMAGE_TAG: ${{ github.sha }}
          EXPIRES_IN: ${{ secrets.DEV_EXPIRES_IN }}
          JWT_SECRET: ${{ secrets.DEV_JWT_SECRET }}
          SALT_VALUE: ${{ secrets.DEV_SALT_VALUE }}
          POSTGRES_PORT: ${{ secrets.DEV_POSTGRES_PORT }}
          DB_TYPE: ${{ secrets.DEV_DB_TYPE }}
          POSTGRES_DATABASE: ${{ secrets.DEV_POSTGRES_DATABASE }}
          POSTGRES_USER: ${{ secrets.DEV_POSTGRES_USER }}
          POSTGRES_PASSWORD: ${{ secrets.DEV_POSTGRES_PASSWORD }}
          POSTGRES_HOST: ${{ secrets.DEV_POSTGRES_HOST }}
          TYPEORM_SYNC: ${{ secrets.DEV_TYPEORM_SYNC }}
          SENDER_MAIL: ${{ secrets.DEV_SENDER_MAIL }}
          SENDER_PASSWORD: ${{ secrets.DEV_SENDER_PASSWORD }}
          MAIL_HOST: ${{ secrets.DEV_MAIL_HOST }}
          MAIL_PORT: ${{ secrets.DEV_MAIL_PORT }}
          AWS_ACCESS_KEY_ID: ${{ secrets.DEV_AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.DEV_AWS_SECRET_ACCESS_KEY }}
          AWS_PUBLIC_BUCKET_NAME: ${{ secrets.DEV_AWS_PUBLIC_BUCKET_NAME }}
        with:
          host: ${{ secrets.DEV_AWS_EC2_HOST }}
          username: ${{ secrets.DEV_AWS_EC2_USERNAME }}
          key: ${{ secrets.DEV_AWS_EC2_KEY }}
          envs: AWS_REGION,ECR_REGISTRY,ECR_REPOSITORY,IMAGE_TAG,BASIC_URL,FRONTEND_URL,ADMIN_PANEL_URL,EXPIRES_IN,JWT_SECRET,DANGEROUSLY_DISABLE_AUTH_GUARD,SALT_VALUE,POSTGRES_PORT,DB_TYPE,POSTGRES_DATABASE,POSTGRES_USER,POSTGRES_PASSWORD,POSTGRES_HOST,TYPEORM_SYNC,SENDER_MAIL,SENDER_PASSWORD,MAIL_HOST,MAIL_PORT,AWS_ACCESS_KEY_ID,AWS_SECRET_ACCESS_KEY,AWS_PUBLIC_BUCKET_NAME
          script: |
            aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
            docker pull $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
            docker network create backend_dev || true
            docker stop backend_dev || true
            docker rm backend_dev || true
            docker run -d \
              --name backend_dev \
              --network backend_dev \
              --restart unless-stopped \
              -e PORT=3000 \
              -e EXPIRES_IN=$EXPIRES_IN \
              -e JWT_SECRET=$JWT_SECRET \
              -e SALT_VALUE=$SALT_VALUE \
              -e POSTGRES_PORT=$POSTGRES_PORT \
              -e DB_TYPE=$DB_TYPE \
              -e POSTGRES_DATABASE=$POSTGRES_DATABASE \
              -e POSTGRES_USER=$POSTGRES_USER \
              -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
              -e POSTGRES_HOST=$POSTGRES_HOST \
              -e TYPEORM_SYNC=$TYPEORM_SYNC \
              -e SENDER_MAIL=$SENDER_MAIL \
              -e SENDER_PASSWORD=$SENDER_PASSWORD \
              -e MAIL_HOST=$MAIL_HOST \
              -e MAIL_PORT=$MAIL_PORT \
              -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
              -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
              -e AWS_PUBLIC_BUCKET_NAME=$AWS_PUBLIC_BUCKET_NAME \
              -p 3000:3000 \
            $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
