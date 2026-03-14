/**
 * NL2Bot — Hull Node Firmware
 *
 * ESP32-CAM running as WiFi AP.
 * - Front camera MJPEG streaming
 * - L9110 dual motor control (differential drive)
 * - MPU6050 gyroscope for heading
 * - UART relay to turret node via slip ring
 * - WebSocket command interface
 */

#include <Arduino.h>
#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <esp_camera.h>
#include <MPU6050_light.h>
#include <Wire.h>

#include "config.h"
#include "protocol.h"

// Camera pin definitions for AI-Thinker ESP32-CAM
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

AsyncWebServer server(HTTP_PORT);
AsyncWebServer streamServer(STREAM_PORT);
AsyncWebSocket ws("/ws");

MPU6050 mpu(Wire);

// Motor state
int8_t currentLeftSpeed = 0;
int8_t currentRightSpeed = 0;

// IMU state
float heading = 0;
float pitch = 0;
float rollAngle = 0;

void setupCamera() {
    camera_config_t config;
    config.ledc_channel = LEDC_CHANNEL_0;
    config.ledc_timer = LEDC_TIMER_0;
    config.pin_d0 = Y2_GPIO_NUM;
    config.pin_d1 = Y3_GPIO_NUM;
    config.pin_d2 = Y4_GPIO_NUM;
    config.pin_d3 = Y5_GPIO_NUM;
    config.pin_d4 = Y6_GPIO_NUM;
    config.pin_d5 = Y7_GPIO_NUM;
    config.pin_d6 = Y8_GPIO_NUM;
    config.pin_d7 = Y9_GPIO_NUM;
    config.pin_xclk = XCLK_GPIO_NUM;
    config.pin_pclk = PCLK_GPIO_NUM;
    config.pin_vsync = VSYNC_GPIO_NUM;
    config.pin_href = HREF_GPIO_NUM;
    config.pin_sccb_sda = SIOD_GPIO_NUM;
    config.pin_sccb_scl = SIOC_GPIO_NUM;
    config.pin_pwdn = PWDN_GPIO_NUM;
    config.pin_reset = RESET_GPIO_NUM;
    config.xclk_freq_hz = 20000000;
    config.pixel_format = PIXFORMAT_JPEG;

    if (psramFound()) {
        config.frame_size = FRAME_SIZE;
        config.jpeg_quality = JPEG_QUALITY;
        config.fb_count = 2;
    } else {
        config.frame_size = FRAMESIZE_SVGA;
        config.jpeg_quality = 16;
        config.fb_count = 1;
    }

    esp_err_t err = esp_camera_init(&config);
    if (err != ESP_OK) {
        Serial.printf("Camera init failed: 0x%x\n", err);
    }
}

void setupMotors() {
    ledcAttach(MOTOR_L_IA, PWM_FREQ, PWM_RES);
    ledcAttach(MOTOR_L_IB, PWM_FREQ, PWM_RES);
    ledcAttach(MOTOR_R_IA, PWM_FREQ, PWM_RES);
    ledcAttach(MOTOR_R_IB, PWM_FREQ, PWM_RES);
}

void setMotor(uint8_t pinIA, uint8_t pinIB, int8_t speed) {
    int pwm = map(abs(speed), 0, 100, 0, 255);
    if (speed > 0) {
        ledcWrite(pinIA, pwm);
        ledcWrite(pinIB, 0);
    } else if (speed < 0) {
        ledcWrite(pinIA, 0);
        ledcWrite(pinIB, pwm);
    } else {
        ledcWrite(pinIA, 0);
        ledcWrite(pinIB, 0);
    }
}

void driveMotors(int8_t left, int8_t right) {
    currentLeftSpeed = constrain(left, -100, 100);
    currentRightSpeed = constrain(right, -100, 100);
    setMotor(MOTOR_L_IA, MOTOR_L_IB, currentLeftSpeed);
    setMotor(MOTOR_R_IA, MOTOR_R_IB, currentRightSpeed);
}

void handleCommand(const TankCommand& cmd) {
    switch (cmd.type) {
        case CMD_MOVE:
            driveMotors(cmd.left_speed, cmd.right_speed);
            break;
        case CMD_TURRET:
        case CMD_FIRE:
        case CMD_CAMERA:
            // Forward to turret node via UART
            Serial2.write((const uint8_t*)&cmd, sizeof(TankCommand));
            break;
    }
}

void onWebSocketEvent(AsyncWebSocket *server, AsyncWebSocketClient *client,
                      AwsEventType type, void *arg, uint8_t *data, size_t len) {
    if (type == WS_EVT_DATA) {
        if (len == sizeof(TankCommand)) {
            TankCommand cmd;
            memcpy(&cmd, data, sizeof(TankCommand));
            if (validate_command(cmd)) {
                handleCommand(cmd);
            }
        }
    }
}

void setupStreaming() {
    streamServer.on("/stream", HTTP_GET, [](AsyncWebServerRequest *request) {
        // MJPEG streaming handled by dedicated task
        request->send(200, "text/plain", "Use /mjpeg endpoint");
    });
}

void setup() {
    Serial.begin(115200);
    Serial2.begin(115200, SERIAL_8N1, TURRET_UART_RX, TURRET_UART_TX);

    // Setup WiFi AP
    WiFi.softAP(WIFI_SSID, WIFI_PASSWORD, WIFI_CHANNEL);
    Serial.printf("AP started: %s\n", WIFI_SSID);
    Serial.printf("IP: %s\n", WiFi.softAPIP().toString().c_str());

    // Setup camera
    setupCamera();

    // Setup motors
    setupMotors();

    // Setup IMU
    Wire.begin(I2C_SDA, I2C_SCL);
    byte status = mpu.begin();
    Serial.printf("MPU6050 status: %d\n", status);
    if (status == 0) {
        Serial.println("Calibrating MPU6050...");
        mpu.calcOffsets();
    }

    // WebSocket
    ws.onEvent(onWebSocketEvent);
    server.addHandler(&ws);

    // Health endpoint
    server.on("/health", HTTP_GET, [](AsyncWebServerRequest *request) {
        request->send(200, "application/json", "{\"node\":\"hull\",\"status\":\"ok\"}");
    });

    // Status endpoint
    server.on("/status", HTTP_GET, [](AsyncWebServerRequest *request) {
        char buf[256];
        snprintf(buf, sizeof(buf),
            "{\"heading\":%.1f,\"pitch\":%.1f,\"roll\":%.1f,\"left_speed\":%d,\"right_speed\":%d}",
            heading, pitch, rollAngle, currentLeftSpeed, currentRightSpeed);
        request->send(200, "application/json", buf);
    });

    server.begin();
    streamServer.begin();
    Serial.println("Hull node ready.");
}

void loop() {
    // Update IMU
    mpu.update();
    heading = mpu.getAngleZ();
    pitch = mpu.getAngleX();
    rollAngle = mpu.getAngleY();

    // Check for turret status via UART
    if (Serial2.available() >= (int)sizeof(TankStatus)) {
        TankStatus status;
        Serial2.readBytes((uint8_t*)&status, sizeof(TankStatus));
        // Could relay to tablet via WebSocket
    }

    // WebSocket cleanup
    ws.cleanupClients();

    delay(10);
}
