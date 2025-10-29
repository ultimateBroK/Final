#!/bin/bash
# install_spark.sh - Script cài đặt Apache Spark

echo "=== CÀI ĐẶT APACHE SPARK ==="

# Kiểm tra xem có đang chạy trên Arch-based distro không
if ! command -v pacman &> /dev/null; then
    echo "❌ Script này dành cho các distro Arch-based (CachyOS)"
    exit 1
fi

# Cài đặt Java (bắt buộc cho Spark)
echo "Đang cài đặt Java..."
sudo pacman -S --noconfirm jre-openjdk jdk-openjdk

# Thiết lập phiên bản Spark
SPARK_VERSION="3.5.0"
HADOOP_VERSION="3"
SPARK_DIR="/opt/spark"

# Tải về Spark
echo "Đang tải Apache Spark $SPARK_VERSION..."
cd /tmp
wget "https://dlcdn.apache.org/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-hadoop$HADOOP_VERSION.tgz"

# Giải nén
echo "Đang giải nén Spark..."
sudo tar -xzf "spark-$SPARK_VERSION-bin-hadoop$HADOOP_VERSION.tgz" -C /opt/
sudo mv "/opt/spark-$SPARK_VERSION-bin-hadoop$HADOOP_VERSION" "$SPARK_DIR"

# Thiết lập quyền truy cập
sudo chmod -R 755 "$SPARK_DIR"

# Thêm vào PATH (zsh)
echo "" >> ~/.zshrc
echo "# Apache Spark" >> ~/.zshrc
echo "export SPARK_HOME=$SPARK_DIR" >> ~/.zshrc
echo "export PATH=\$SPARK_HOME/bin:\$PATH" >> ~/.zshrc
echo "export PYSPARK_PYTHON=python3" >> ~/.zshrc

# Cài đặt PySpark qua pip
echo "Đang cài đặt PySpark..."
pip install pyspark==$SPARK_VERSION

echo ""
echo "✅ Đã cài đặt Apache Spark thành công!"
echo ""
echo "Vui lòng chạy: source ~/.zshrc"
echo "Sau đó kiểm tra bằng: spark-submit --version"
