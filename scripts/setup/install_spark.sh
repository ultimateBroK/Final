#!/bin/bash
# install_spark.sh - Script cài đặt Apache Spark

echo "=== Installing Apache Spark ==="

# Check if running on Arch-based distro
if ! command -v pacman &> /dev/null; then
    echo "❌ This script is for Arch-based distros (CachyOS)"
    exit 1
fi

# Install Java (required for Spark)
echo "Installing Java..."
sudo pacman -S --noconfirm jre-openjdk jdk-openjdk

# Set Spark version
SPARK_VERSION="3.5.0"
HADOOP_VERSION="3"
SPARK_DIR="/opt/spark"

# Download Spark
echo "Downloading Apache Spark $SPARK_VERSION..."
cd /tmp
wget "https://dlcdn.apache.org/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-hadoop$HADOOP_VERSION.tgz"

# Extract
echo "Extracting Spark..."
sudo tar -xzf "spark-$SPARK_VERSION-bin-hadoop$HADOOP_VERSION.tgz" -C /opt/
sudo mv "/opt/spark-$SPARK_VERSION-bin-hadoop$HADOOP_VERSION" "$SPARK_DIR"

# Set permissions
sudo chmod -R 755 "$SPARK_DIR"

# Add to PATH (zsh)
echo "" >> ~/.zshrc
echo "# Apache Spark" >> ~/.zshrc
echo "export SPARK_HOME=$SPARK_DIR" >> ~/.zshrc
echo "export PATH=\$SPARK_HOME/bin:\$PATH" >> ~/.zshrc
echo "export PYSPARK_PYTHON=python3" >> ~/.zshrc

# Install PySpark via pip
echo "Installing PySpark..."
pip install pyspark==$SPARK_VERSION

echo ""
echo "✅ Apache Spark installed successfully!"
echo ""
echo "Please run: source ~/.zshrc"
echo "Then verify with: spark-submit --version"
