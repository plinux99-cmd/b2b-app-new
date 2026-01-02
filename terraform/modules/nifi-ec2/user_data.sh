#!/bin/bash
set -e

# NiFi Setup Script for Amazon Linux 2
# Installs and configures Apache NiFi

NIFI_VERSION="${NIFI_VERSION}"
DEVICE_NAME="${DEVICE_NAME}"
PROJECT_NAME="${PROJECT_NAME}"

# Update system
yum update -y
yum install -y java-11-openjdk java-11-openjdk-devel wget tar gzip

# Set JAVA_HOME
echo 'export JAVA_HOME=/usr/lib/jvm/java-11-openjdk' >> /etc/profile.d/java.sh
source /etc/profile.d/java.sh

# Format and mount EBS volume
if [ -b "$DEVICE_NAME" ]; then
  # Wait for volume to be available
  sleep 5
  
  # Check if volume is already formatted
  if ! sudo blkid "$DEVICE_NAME"; then
    echo "Formatting $DEVICE_NAME..."
    sudo mkfs -t ext4 "$DEVICE_NAME"
  fi
  
  # Create mount point
  sudo mkdir -p /nifi_data
  
  # Mount the volume
  sudo mount "$DEVICE_NAME" /nifi_data
  
  # Add to fstab for persistent mounting
  DEVICE_UUID=$(sudo blkid -s UUID -o value "$DEVICE_NAME")
  echo "UUID=$DEVICE_UUID /nifi_data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
  
  # Set permissions
  sudo chown -R 1000:1000 /nifi_data
  sudo chmod 755 /nifi_data
fi

# Create nifi user
useradd -m -u 1000 nifi || true

# Create installation directory
sudo mkdir -p /opt/nifi
sudo chown nifi:nifi /opt/nifi

# Download and install NiFi
cd /tmp
wget https://archive.apache.org/dist/nifi/"$NIFI_VERSION"/nifi-"$NIFI_VERSION"-bin.tar.gz
tar -xzf nifi-"$NIFI_VERSION"-bin.tar.gz
sudo mv nifi-"$NIFI_VERSION" /opt/nifi/nifi-"$NIFI_VERSION"
sudo chown -R nifi:nifi /opt/nifi/nifi-"$NIFI_VERSION"

# Create symlink for easier management
sudo ln -sf /opt/nifi/nifi-"$NIFI_VERSION" /opt/nifi/current
sudo chown -R nifi:nifi /opt/nifi/current

# Configure NiFi properties
NIFI_HOME="/opt/nifi/current"
NIFI_CONF="$NIFI_HOME/conf/nifi.properties"

# Set data directories to use the mounted volume
sudo sed -i "s|nifi.flow.configuration.file=.*|nifi.flow.configuration.file=/nifi_data/flow.xml.gz|g" "$NIFI_CONF"
sudo sed -i "s|nifi.flow.configuration.archive.dir=.*|nifi.flow.configuration.archive.dir=/nifi_data/archive|g" "$NIFI_CONF"
sudo sed -i "s|nifi.database.repository.directory=.*|nifi.database.repository.directory=/nifi_data/database_repository|g" "$NIFI_CONF"
sudo sed -i "s|nifi.flowfile.repository.directory=.*|nifi.flowfile.repository.directory=/nifi_data/flowfile_repository|g" "$NIFI_CONF"
sudo sed -i "s|nifi.content.repository.directory.default=.*|nifi.content.repository.directory.default=/nifi_data/content_repository|g" "$NIFI_CONF"
sudo sed -i "s|nifi.provenance.repository.directory.default=.*|nifi.provenance.repository.directory.default=/nifi_data/provenance_repository|g" "$NIFI_CONF"
sudo sed -i "s|nifi.state.management.configuration.file=.*|nifi.state.management.configuration.file=$NIFI_HOME/conf/state-management.xml|g" "$NIFI_CONF"

# Disable HTTPS by default (can be configured later)
sudo sed -i "s|nifi.web.https.port=.*|# nifi.web.https.port=8443|g" "$NIFI_CONF"

# Create required directories with proper permissions
sudo mkdir -p /nifi_data/{archive,database_repository,flowfile_repository,content_repository,provenance_repository}
sudo chown -R nifi:nifi /nifi_data

# Create systemd service file
sudo tee /etc/systemd/system/nifi.service > /dev/null << 'EOF'
[Unit]
Description=Apache NiFi
After=network.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=simple
User=nifi
Group=nifi
ExecStart=/opt/nifi/current/bin/nifi.sh run
ExecStop=/opt/nifi/current/bin/nifi.sh stop
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start NiFi service
sudo systemctl daemon-reload
sudo systemctl enable nifi
sudo systemctl start nifi

# CloudWatch Agent Configuration for monitoring
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << EOF
{
  "metrics": {
    "namespace": "NiFi/${PROJECT_NAME}",
    "metrics_collected": {
      "disk": {
        "measurement": [
          {
            "name": "used_percent",
            "rename": "disk_used_percent"
          }
        ],
        "metrics_collection_interval": 300,
        "resources": ["/nifi_data"]
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 300
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/opt/nifi/current/logs/nifi-app.log",
            "log_group_name": "/aws/nifi/${PROJECT_NAME}",
            "log_stream_name": "app-logs"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
cd /opt/aws/amazon-cloudwatch-agent/bin/
./amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json || true

# Log completion
echo "NiFi setup completed successfully" > /var/log/nifi-setup.log
echo "NiFi version: $NIFI_VERSION" >> /var/log/nifi-setup.log
echo "Installation directory: /opt/nifi/current" >> /var/log/nifi-setup.log
echo "Data directory: /nifi_data" >> /var/log/nifi-setup.log
date >> /var/log/nifi-setup.log
