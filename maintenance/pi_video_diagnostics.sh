#!/usr/bin/env bash
# CandyBarV2 Pi Video Diagnostics
# Run on Raspberry Pi to diagnose video playback performance
# Writes consolidated timestamped log to ~/candybar_video_diagnostics_<timestamp>.log

set -e

LOG_DIR="$HOME"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/candybar_video_diagnostics_$TIMESTAMP.log"

echo "=== CandyBarV2 Video Diagnostics ===" | tee -a "$LOG_FILE"
echo "Timestamp: $(date)" | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# System info
echo "--- System Information ---" | tee -a "$LOG_FILE"
echo "Hostname: $(hostname)" | tee -a "$LOG_FILE"
echo "Kernel: $(uname -r)" | tee -a "$LOG_FILE"
echo "Architecture: $(uname -m)" | tee -a "$LOG_FILE"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Hardware info
echo "--- Hardware Information ---" | tee -a "$LOG_FILE"
if [ -f /proc/cpuinfo ]; then
    echo "CPU Model: $(grep 'Model' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)" | tee -a "$LOG_FILE"
    echo "CPU Cores: $(nproc)" | tee -a "$LOG_FILE"
fi
if command -v vcgencmd &> /dev/null; then
    echo "Raspberry Pi Firmware: $(vcgencmd version)" | tee -a "$LOG_FILE"
    echo "Raspberry Pi Clock Speeds:" | tee -a "$LOG_FILE"
    vcgencmd measure_clock arm | tee -a "$LOG_FILE"
    vcgencmd measure_clock core | tee -a "$LOG_FILE"
    vcgencmd measure_clock v3d | tee -a "$LOG_FILE" || echo "  (V3D not available)" | tee -a "$LOG_FILE"
    echo "Raspberry Pi Temperatures:" | tee -a "$LOG_FILE"
    vcgencmd measure_temp | tee -a "$LOG_FILE"
    echo "Raspberry Pi Memory Split:" | tee -a "$LOG_FILE"
    vcgencmd get_mem gpu | tee -a "$LOG_FILE"
    vcgencmd get_mem arm | tee -a "$LOG_FILE"
fi
echo "" | tee -a "$LOG_FILE"

# Memory info
echo "--- Memory Information ---" | tee -a "$LOG_FILE"
free -h | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# GPU decode capability check
echo "--- GPU Decode Capability ---" | tee -a "$LOG_FILE"
if command -v ffmpeg &> /dev/null; then
    echo "FFmpeg version: $(ffmpeg -version | head -1)" | tee -a "$LOG_FILE"
    echo "Available decoders:" | tee -a "$LOG_FILE"
    ffmpeg -decoders 2>/dev/null | grep -i "h264\|hevc" | tee -a "$LOG_FILE" || echo "  (No hardware decoders found)" | tee -a "$LOG_FILE"
else
    echo "FFmpeg not installed" | tee -a "$LOG_FILE"
fi
echo "" | tee -a "$LOG_FILE"

# GStreamer check
echo "--- GStreamer Information ---" | tee -a "$LOG_FILE"
if command -v gst-launch-1.0 &> /dev/null; then
    echo "GStreamer version: $(gst-launch-1.0 --version)" | tee -a "$LOG_FILE"
    echo "Available plugins:" | tee -a "$LOG_FILE"
    gst-inspect-1.0 2>/dev/null | grep -i "omx\|v4l2\|mmal" | tee -a "$LOG_FILE" || echo "  (No hardware plugins found)" | tee -a "$LOG_FILE"
else
    echo "GStreamer not installed" | tee -a "$LOG_FILE"
fi
echo "" | tee -a "$LOG_FILE"

# Qt Multimedia backend check
echo "--- Qt Multimedia Backend ---" | tee -a "$LOG_FILE"
if command -v qmake6 &> /dev/null; then
    echo "Qt version: $(qmake6 --version | tail -1)" | tee -a "$LOG_FILE"
else
    echo "Qt qmake not found" | tee -a "$LOG_FILE"
fi
echo "QT_QUICK_BACKEND: ${QT_QUICK_BACKEND:-<unset>}" | tee -a "$LOG_FILE"
echo "QT_QPA_PLATFORM: ${QT_QPA_PLATFORM:-<unset>}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Video file test
echo "--- Video File Test ---" | tee -a "$LOG_FILE"
TEST_VIDEO="/home/rayen/Desktop/CandyBarV2/app/web/videos/food_1_animated.mp4"
if [ -f "$TEST_VIDEO" ]; then
    echo "Test video: $TEST_VIDEO" | tee -a "$LOG_FILE"
    echo "File size: $(du -h "$TEST_VIDEO" | cut -f1)" | tee -a "$LOG_FILE"
    if command -v ffprobe &> /dev/null; then
        echo "Video info:" | tee -a "$LOG_FILE"
        ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate,profile -show_entries format=duration -of default=noprint_wrappers=1 "$TEST_VIDEO" | tee -a "$LOG_FILE"
    fi
else
    echo "Test video not found at $TEST_VIDEO" | tee -a "$LOG_FILE"
fi
echo "" | tee -a "$LOG_FILE"

# CPU decode test (software)
echo "--- CPU Decode Performance Test (Software) ---" | tee -a "$LOG_FILE"
if [ -f "$TEST_VIDEO" ] && command -v ffmpeg &> /dev/null; then
    echo "Decoding test video with CPU (software)..." | tee -a "$LOG_FILE"
    START_CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d% -f1)
    START_MEM=$(free | grep Mem | awk '{print $3}')
    START_TIME=$(date +%s.%N)
    
    # Decode 5 seconds of video to /dev/null
    timeout 5 ffmpeg -i "$TEST_VIDEO" -t 5 -f null - 2>&1 | grep -i "time=" | tail -1 | tee -a "$LOG_FILE" || true
    
    END_TIME=$(date +%s.%N)
    END_CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d% -f1)
    END_MEM=$(free | grep Mem | awk '{print $3}')
    
    ELAPSED=$(echo "$END_TIME - $START_TIME" | bc)
    CPU_DELTA=$(echo "$END_CPU - $START_CPU" | bc)
    MEM_DELTA=$(echo "$END_MEM - $START_MEM" | bc)
    
    echo "Elapsed time: ${ELAPSED}s" | tee -a "$LOG_FILE"
    echo "CPU usage delta: ${CPU_DELTA}%" | tee -a "$LOG_FILE"
    echo "Memory usage delta: ${MEM_DELTA} KB" | tee -a "$LOG_FILE"
else
    echo "Skipping CPU decode test (video or ffmpeg not available)" | tee -a "$LOG_FILE"
fi
echo "" | tee -a "$LOG_FILE"

# GPU decode test (if available)
echo "--- GPU Decode Performance Test (Hardware) ---" | tee -a "$LOG_FILE"
if [ -f "$TEST_VIDEO" ] && command -v ffmpeg &> /dev/null; then
    echo "Attempting hardware decode with h264_mmal..." | tee -a "$LOG_FILE"
    START_CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d% -f1)
    START_MEM=$(free | grep Mem | awk '{print $3}')
    START_TIME=$(date +%s.%N)
    
    timeout 5 ffmpeg -hwaccel mmal -i "$TEST_VIDEO" -t 5 -f null - 2>&1 | grep -i "time=" | tail -1 | tee -a "$LOG_FILE" || echo "  (Hardware decode failed or not supported)" | tee -a "$LOG_FILE"
    
    END_TIME=$(date +%s.%N)
    END_CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d% -f1)
    END_MEM=$(free | grep Mem | awk '{print $3}')
    
    ELAPSED=$(echo "$END_TIME - $START_TIME" | bc)
    CPU_DELTA=$(echo "$END_CPU - $START_CPU" | bc)
    MEM_DELTA=$(echo "$END_MEM - $START_MEM" | bc)
    
    echo "Elapsed time: ${ELAPSED}s" | tee -a "$LOG_FILE"
    echo "CPU usage delta: ${CPU_DELTA}%" | tee -a "$LOG_FILE"
    echo "Memory usage delta: ${MEM_DELTA} KB" | tee -a "$LOG_FILE"
else
    echo "Skipping GPU decode test (video or ffmpeg not available)" | tee -a "$LOG_FILE"
fi
echo "" | tee -a "$LOG_FILE"

# GStreamer pipeline test
echo "--- GStreamer Pipeline Test ---" | tee -a "$LOG_FILE"
if [ -f "$TEST_VIDEO" ] && command -v gst-launch-1.0 &> /dev/null; then
    echo "Testing GStreamer pipeline with filesrc..." | tee -a "$LOG_FILE"
    timeout 5 gst-launch-1.0 filesrc location="$TEST_VIDEO" ! decodebin ! videoconvert ! fakesink 2>&1 | tail -5 | tee -a "$LOG_FILE" || echo "  (GStreamer pipeline test failed)" | tee -a "$LOG_FILE"
else
    echo "Skipping GStreamer test (video or gst-launch not available)" | tee -a "$LOG_FILE"
fi
echo "" | tee -a "$LOG_FILE"

# Summary
echo "--- Summary ---" | tee -a "$LOG_FILE"
echo "Diagnostics complete. Log saved to: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "To share this log, attach: $LOG_FILE" | tee -a "$LOG_FILE"
